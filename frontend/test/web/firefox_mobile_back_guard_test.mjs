import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(
  new URL("../../web/firefox_mobile_back_guard.js", import.meta.url),
  "utf8",
);

function loadGuard(userAgent) {
  const listeners = new Map();
  const calls = { push: [], replace: [] };
  const location = { href: "https://web.scoutbox.app/?invite=abc" };
  const history = {
    state: { flutter: true },
    pushState(state, title, url) {
      calls.push.push({ state, title, url });
      this.state = state;
    },
    replaceState(state, title, url) {
      calls.replace.push({ state, title, url });
      this.state = state;
    },
  };
  const window = {
    addEventListener(type, listener) {
      const current = listeners.get(type) ?? [];
      current.push(listener);
      listeners.set(type, current);
    },
    removeEventListener(type, listener) {
      listeners.set(
        type,
        (listeners.get(type) ?? []).filter((current) => current !== listener),
      );
    },
    dispatchEvent(event) {
      emit(event.type, event);
    },
  };

  function emit(type, event = {}) {
    event.type ??= type;
    for (const listener of [...(listeners.get(type) ?? [])]) listener(event);
  }

  class Event {
    constructor(type) {
      this.type = type;
    }
  }

  vm.runInNewContext(source, {
    Event,
    history,
    location,
    navigator: { userAgent },
    window,
  });

  return { calls, emit, history, location, window };
}

test("does not install history handling outside Firefox Android", () => {
  const guard = loadGuard(
    "Mozilla/5.0 (Linux; Android 15) AppleWebKit Chrome/140 Mobile Safari",
  );

  guard.emit("flutter-first-frame");
  guard.emit("pointerdown", { isTrusted: true });

  assert.equal(guard.calls.replace.length, 0);
  assert.equal(guard.calls.push.length, 0);
});

test("arms after Flutter is ready and the user interacts", () => {
  const guard = loadGuard(
    "Mozilla/5.0 (Android 15; Mobile; rv:142.0) Gecko/142.0 Firefox/142.0",
  );

  guard.emit("flutter-first-frame");
  assert.equal(guard.calls.push.length, 0);

  guard.emit("pointerdown", { isTrusted: true });

  assert.equal(guard.calls.replace.length, 1);
  assert.equal(guard.calls.replace[0].state.__scoutboxFirefoxBackBase, true);
  assert.equal(guard.calls.push.length, 1);
  assert.equal(guard.calls.push[0].state.__scoutboxFirefoxBackGuard, true);
  assert.equal(guard.calls.push[0].url, guard.location.href);
});

test("restores the sentinel and dispatches one app back event", () => {
  const guard = loadGuard(
    "Mozilla/5.0 (Android 15; Mobile; rv:142.0) Gecko/142.0 Firefox/142.0",
  );
  guard.emit("flutter-first-frame");
  guard.emit("pointerdown", { isTrusted: true });

  let backEvents = 0;
  guard.window.addEventListener("scoutbox-firefox-back", () => backEvents++);
  let propagationStopped = false;
  const baseState = guard.calls.replace[0].state;

  guard.emit("popstate", {
    state: baseState,
    stopImmediatePropagation() {
      propagationStopped = true;
    },
  });

  assert.equal(propagationStopped, true);
  assert.equal(backEvents, 1);
  assert.equal(guard.calls.push.length, 2);
  assert.equal(guard.history.state.__scoutboxFirefoxBackGuard, true);
});
