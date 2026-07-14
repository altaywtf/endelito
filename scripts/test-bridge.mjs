#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const bridgePath = path.join(root, "app/Resources/EndelitoBridge.js");
const source = fs.readFileSync(bridgePath, "utf8");

const createButton = () => ({
  getBoundingClientRect: () => ({ x: 10, y: 20, width: 40, height: 30 })
});

const createMedia = ({ paused = true, ended = false, muted = false, loop = false, autoplay = false, tag = "AUDIO" } = {}) => {
  let currentPaused = paused;
  return {
    tagName: tag,
    get paused() {
      return currentPaused;
    },
    ended,
    muted,
    loop,
    autoplay,
    addEventListener() {},
    play: async () => {
      currentPaused = false;
    },
    pause: () => {
      currentPaused = true;
    }
  };
};

const runBridge = ({ href = "https://play.endel.io/en/soundscape/focus", button = createButton(), media = [createMedia()] } = {}) => {
  const posted = [];
  const listeners = new Map();

  const document = {
    querySelector(selector) {
      if (selector === 'button[data-analytics="btn_player_playback_control"]') {
        return button;
      }
      return null;
    },
    querySelectorAll(selector) {
      if (selector === "audio, video") {
        return media;
      }
      return [];
    },
    documentElement: {},
    readyState: "complete",
    title: "Endelito fixture",
    addEventListener() {}
  };

  const history = {
    pushState() {},
    replaceState() {}
  };

  const window = {
    electron: undefined,
    __endelito: undefined,
    location: { href, pathname: new URL(href).pathname },
    history,
    document,
    webkit: {
      messageHandlers: {
        endelito: {
          postMessage(message) {
            posted.push(message);
          }
        }
      }
    },
    AudioContext: function AudioContext() {},
    webkitAudioContext: undefined,
    MutationObserver: class {
      observe() {}
    },
    addEventListener(name, cb) {
      listeners.set(name, cb);
    },
    dispatchEvent() {},
    setTimeout: (fn) => {
      fn();
      return 0;
    },
    setInterval() {
      return 0;
    },
    CustomEvent: class {
      constructor(name, init) {
        this.name = name;
        this.detail = init?.detail;
      }
    }
  };

  window.window = window;
  const context = vm.createContext({
    window,
    document,
    location: window.location,
    history,
    setTimeout: window.setTimeout,
    setInterval: window.setInterval,
    MutationObserver: window.MutationObserver,
    AudioContext: window.AudioContext,
    CustomEvent: window.CustomEvent
  });
  vm.runInContext(source, context);

  assert.equal(typeof window.__endelito?.nativePlaybackClick, "function");
  return { window, posted };
};

const assertResult = (actual, expected) => {
  assert.equal(actual?.ok, expected.ok);
  for (const key of Object.keys(expected)) {
    assert.equal(actual?.[key], expected[key], `${key} mismatch`);
  }
};

const playing = runBridge({
  media: [createMedia({ paused: false })]
});
assertResult(playing.window.__endelito.nativePlaybackClick("play"), {
  ok: true,
  skipped: "already-playing"
});

const paused = runBridge();
assertResult(paused.window.__endelito.nativePlaybackClick("pause"), {
  ok: true,
  skipped: "already-paused"
});

const coords = runBridge();
assertResult(coords.window.__endelito.nativePlaybackClick("play"), {
  ok: true,
  x: 30,
  y: 35,
  width: 40,
  height: 30
});

const missing = runBridge({ button: null });
assertResult(missing.window.__endelito.nativePlaybackClick("play"), {
  ok: false,
  reason: "no-playback-button"
});

const debug = runBridge({ href: "https://play.endel.io/en/soundscape/relax" });
const page = debug.window.__endelito.debugPage();
assert.equal(page.href, "https://play.endel.io/en/soundscape/relax");
assert.equal(page.hasEndelito, true);

assert.match(source, /btn_player_playback_control/);
assert.match(source, /__ENDELITO_VERSION__/);

console.log("test-bridge: ok");
