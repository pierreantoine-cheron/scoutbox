(function () {
  "use strict";

  const isFirefoxAndroid =
    /Android/i.test(navigator.userAgent) && /Firefox\//i.test(navigator.userAgent);
  if (!isFirefoxAndroid) return;

  const baseMarker = "__scoutboxFirefoxBackBase";
  const guardMarker = "__scoutboxFirefoxBackGuard";
  const backEventName = "scoutbox-firefox-back";
  let flutterReady = false;
  let userInteracted = false;
  let armed = history.state?.[guardMarker] === true;

  function guardStateFrom(state) {
    const guardState = { ...state, [guardMarker]: true };
    delete guardState[baseMarker];
    return guardState;
  }

  function removeInteractionListeners() {
    window.removeEventListener("pointerdown", onUserInteraction, true);
    window.removeEventListener("touchstart", onUserInteraction, true);
    window.removeEventListener("keydown", onUserInteraction, true);
  }

  function tryArm() {
    if (armed || !flutterReady || !userInteracted) return;

    const flutterState = history.state;
    if (!flutterState || flutterState.flutter !== true) return;

    history.replaceState(
      { ...flutterState, [baseMarker]: true },
      "",
      location.href,
    );
    history.pushState(guardStateFrom(flutterState), "", location.href);
    armed = true;
    removeInteractionListeners();
  }

  function onUserInteraction(event) {
    if (!event.isTrusted) return;
    userInteracted = true;
    tryArm();
  }

  window.addEventListener(
    "flutter-first-frame",
    function () {
      flutterReady = true;
      tryArm();
    },
    { once: true },
  );

  if (!armed) {
    window.addEventListener("pointerdown", onUserInteraction, true);
    window.addEventListener("touchstart", onUserInteraction, true);
    window.addEventListener("keydown", onUserInteraction, true);
  }

  window.addEventListener(
    "popstate",
    function (event) {
      if (!armed || event.state?.[baseMarker] !== true) return;

      // Flutter would interpret this extra same-document entry as a pushed
      // route. Keep it private and forward one back request to the app instead.
      event.stopImmediatePropagation();
      history.pushState(guardStateFrom(event.state), "", location.href);
      window.dispatchEvent(new Event(backEventName));
    },
    true,
  );
})();
