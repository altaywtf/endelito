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
  let lastPostedSource = "";

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

  const playbackButtonRect = (action) => {
    const isPlaying = currentPlaybackState()?.isPlaying ?? null;
    if (action === "play" && isPlaying === true) return { ok: true, skipped: "already-playing" };
    if (action === "pause" && isPlaying === false) return { ok: true, skipped: "already-paused" };

    const button = document.querySelector('button[data-analytics="btn_player_playback_control"]');
    if (!button) return { ok: false, reason: "no-playback-button" };

    const rect = button.getBoundingClientRect();
    return {
      ok: true,
      x: rect.x + rect.width / 2,
      y: rect.y + rect.height / 2,
      width: rect.width,
      height: rect.height
    };
  };

  const summarizeElement = (element, selector = null) => {
    const rect = element.getBoundingClientRect();
    return {
      ...(selector ? { selector } : {}),
      tag: element.tagName,
      text: (element.innerText || element.textContent || "").trim().slice(0, 80),
      aria: element.getAttribute("aria-label"),
      className: String(element.className || "").slice(0, 160),
      title: element.getAttribute("title"),
      testid: element.getAttribute("data-testid"),
      role: element.getAttribute("role"),
      rect: {
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        width: Math.round(rect.width),
        height: Math.round(rect.height)
      },
      html: element.outerHTML.slice(0, 300),
      paused: typeof element.paused === "boolean" ? element.paused : null,
      muted: typeof element.muted === "boolean" ? element.muted : null
    };
  };

  const debugPage = () => {
    const selectors = [
      "button",
      '[role="button"]',
      "[aria-label]",
      "[data-testid]",
      'a[href*="/soundscape/"]',
      '[class*="soundscape" i]',
      '[class*="source" i]',
      "svg",
      "canvas",
      "audio",
      "video"
    ];
    const items = selectors.flatMap((selector) =>
      Array.from(document.querySelectorAll(selector)).slice(0, 120).map((element) => summarizeElement(element, selector))
    );
    const visible = Array.from(document.querySelectorAll("body *"))
      .flatMap((element) => {
        const rect = element.getBoundingClientRect();
        if (rect.width < 24 || rect.height < 24 || rect.y > 260) return [];
        const style = getComputedStyle(element);
        if (style.visibility === "hidden" || style.display === "none" || Number(style.opacity) === 0) return [];
        return [summarizeElement(element)];
      })
      .slice(0, 160);

    return {
      href: location.href,
      title: document.title,
      readyState: document.readyState,
      hasElectron: Boolean(window.electron),
      hasEndelito: Boolean(window.__endelito),
      items,
      visible
    };
  };

  const currentSource = () => {
    const parts = window.location.pathname.split("/").filter(Boolean);
    const index = parts.indexOf("soundscape");
    if (index === -1 || index + 1 >= parts.length) return null;
    return parts[index + 1];
  };

  const postSource = () => {
    const source = currentSource();
    if (!source || source === lastPostedSource) return;
    lastPostedSource = source;
    post({
      type: "source",
      source,
      wasPlaying: currentPlaybackState()?.isPlaying === true
    });
  };

  const installLocationObserver = () => {
    const notify = () => setTimeout(postSource, 0);
    for (const name of ["pushState", "replaceState"]) {
      const original = history[name];
      if (typeof original !== "function") continue;

      history[name] = function (...args) {
        const result = original.apply(this, args);
        notify();
        return result;
      };
    }

    window.addEventListener("popstate", notify, { passive: true });
    window.addEventListener("hashchange", notify, { passive: true });
  };

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
  installLocationObserver();

  new MutationObserver(scheduleMediaObservation).observe(document.documentElement || document, {
    childList: true,
    subtree: true
  });
  document.addEventListener("DOMContentLoaded", observeMedia, { once: true });
  window.addEventListener("load", observeMedia, { once: true });
  setInterval(observeMedia, 1000);
  setInterval(postPlaybackState, 1000);
  setInterval(postSource, 1000);
  scheduleMediaObservation();
  postSource();

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
    nativePlaybackClick: playbackButtonRect,
    debugPage,
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
    app: { getVersion: async () => "endelito/__ENDELITO_VERSION__" },
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
