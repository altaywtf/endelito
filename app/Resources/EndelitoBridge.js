(() => {
  if (window.electron && window.__endelito) return;

  const playbackCallbacks = new Set();
  const menuCallbacks = new Set();
  const deeplinkCallbacks = new Set();
  const post = (message) => {
    try {
      window.webkit?.messageHandlers?.endelito?.postMessage(message);
    } catch (_) {}
  };
  const unsubscribeFrom = (callbacks, cb) => () => callbacks.delete(cb);
  const noop = async () => {};
  const state = { playback: null, menu: [] };
  const observedMedia = new WeakSet();
  const observedAudioContexts = new Set();
  let lastPostedPlaybackState = "";

  const isControllableMedia = (element) => {
    if (element.tagName === "AUDIO") return true;
    return !(element.muted === true && element.loop === true && element.autoplay === true);
  };
  const mediaElements = () => Array.from(document.querySelectorAll("audio, video")).filter(isControllableMedia);

  const currentPlaybackState = () => {
    const elements = mediaElements();
    const active = elements.find((element) => element.paused === false && element.ended !== true) || elements[0];
    if (active) {
      return {
        isPlaying: active.paused === false && active.ended !== true
      };
    }

    const audioContexts = Array.from(observedAudioContexts);
    if (audioContexts.length === 0) return null;

    return {
      isPlaying: audioContexts.some((context) => context.state === "running")
    };
  };

  const postPlaybackState = () => {
    const nextState = currentPlaybackState();
    if (!nextState) return;

    const serialized = JSON.stringify(nextState);
    if (serialized === lastPostedPlaybackState) return;

    lastPostedPlaybackState = serialized;
    state.playback = nextState;
    post({ type: "playback", state: nextState });
  };

  const observeMedia = () => {
    for (const media of mediaElements()) {
      if (observedMedia.has(media)) continue;
      observedMedia.add(media);

      for (const eventName of ["play", "playing", "pause", "ended", "emptied", "abort"]) {
        media.addEventListener(eventName, postPlaybackState, { passive: true });
      }
    }

    postPlaybackState();
  };

  const scheduleMediaObservation = () => setTimeout(observeMedia, 0);

  const observeAudioContext = (context) => {
    if (!context || observedAudioContexts.has(context)) return context;
    observedAudioContexts.add(context);
    context.addEventListener?.("statechange", postPlaybackState, { passive: true });
    postPlaybackState();
    return context;
  };

  const installAudioContextObserver = (name) => {
    const OriginalAudioContext = window[name];
    if (typeof OriginalAudioContext !== "function") return;

    function EndelitoAudioContext(...args) {
      return observeAudioContext(new OriginalAudioContext(...args));
    }

    EndelitoAudioContext.prototype = OriginalAudioContext.prototype;
    Object.setPrototypeOf(EndelitoAudioContext, OriginalAudioContext);

    Object.defineProperty(window, name, {
      configurable: true,
      writable: true,
      value: EndelitoAudioContext
    });
  };

  installAudioContextObserver("AudioContext");
  installAudioContextObserver("webkitAudioContext");

  new MutationObserver(scheduleMediaObservation).observe(document.documentElement || document, {
    childList: true,
    subtree: true
  });
  document.addEventListener("DOMContentLoaded", observeMedia, { once: true });
  window.addEventListener("load", observeMedia, { once: true });
  setInterval(observeMedia, 1000);
  setInterval(postPlaybackState, 1000);
  scheduleMediaObservation();

  window.__endelito = {
    playbackCommand: (action) => {
      for (const cb of playbackCallbacks) cb(action);
      const media = mediaElements()[0];
      if (!media) return;

      if (action === "play") {
        media.play?.().catch?.(() => {});
      } else if (action === "pause") {
        media.pause?.();
      }

      post({
        type: "playback",
        state: {
          isPlaying: typeof media.paused === "boolean" ? !media.paused : false
        }
      });
    },
    menuCommand: (action) => {
      for (const cb of menuCallbacks) cb(action);
    },
    deepLink: (url) => {
      for (const cb of deeplinkCallbacks) cb(url);
      window.dispatchEvent(new CustomEvent("endelito:deeplink", { detail: url }));
    }
  };

  // Endel's web player expects the desktop Electron preload API to exist.
  // Endelito implements only the small subset needed for playback/menu state
  // and leaves unsupported native surfaces as inert no-ops.
  window.electron = {
    app: { getVersion: async () => "endelito/0.1.0" },
    iap: {
      canMakePayments: async () => false,
      getProducts: async () => [],
      buy: noop,
      restore: noop,
      onTransactionsUpdated: () => () => {},
      onPurchaseSuccess: () => () => {},
      onPurchaseFailed: () => () => {}
    },
    review: { requestReview: noop },
    playback: {
      updateState: async (nextState) => {
        state.playback = nextState;
        post({ type: "playback", state: nextState });
      },
      onCommand: (cb) => {
        playbackCallbacks.add(cb);
        return unsubscribeFrom(playbackCallbacks, cb);
      }
    },
    menu: {
      updateMenu: async (nextMenu) => {
        state.menu = nextMenu || [];
        post({ type: "menu", menu: state.menu });
      },
      onMenuCommand: (cb) => {
        menuCallbacks.add(cb);
        return unsubscribeFrom(menuCallbacks, cb);
      }
    },
    push: {
      register: noop,
      requestPermission: noop,
      getAuthorizationStatus: async () => "denied",
      onTokenUpdated: () => () => {},
      onAuthorizationStatusUpdated: () => () => {}
    },
    window: {
      onMinimize: () => () => {},
      onRestore: () => () => {},
      onMaximize: () => () => {},
      onUnmaximize: () => () => {},
      onShow: () => () => {},
      onHide: () => () => {},
      onFocus: () => () => {},
      onBlur: () => () => {},
      onEnterFullScreen: () => () => {},
      onLeaveFullScreen: () => () => {},
      onMove: () => () => {},
      onResize: () => () => {},
      onAlwaysOnTopChanged: () => () => {}
    },
    deeplinks: {
      onOpen: (cb) => {
        deeplinkCallbacks.add(cb);
        return unsubscribeFrom(deeplinkCallbacks, cb);
      }
    },
    oauth: {
      google: noop,
      facebook: noop,
      apple: noop,
      onSuccess: () => () => {}
    }
  };
})();
