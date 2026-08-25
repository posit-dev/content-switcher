// content-switcher.js
document.addEventListener("DOMContentLoaded", function() {
  const selector = document.getElementById("content-switcher-select");
  if (!selector) return;

  const validOptions = Array.from(selector.options).map(opt => opt.value);

  function switchVersion(version) {
    if (!version || !validOptions.includes(version)) {
      console.warn(`Content switcher: Invalid version "${version}"`);
      return;
    }

    const blocks = document.querySelectorAll(".content-switcher");

    blocks.forEach(block => {
      if (block.dataset.version === version) {
        block.classList.remove("content-switcher-hidden");
      } else {
        block.classList.add("content-switcher-hidden");
      }
    });

    localStorage.setItem("content-switcher-selected-version", version);

    // Dispatch custom event for extensibility
    window.dispatchEvent(new CustomEvent('content-switcher:changed', {
      detail: { version }
    }));

    // Keep backward compatibility with scroll hack
    window.dispatchEvent(new Event('scroll'));
  }

  // Find the element that a URL hash points to (e.g. "#set-up-user-provisioning").
  function getHashTarget() {
    const raw = window.location.hash.slice(1);
    if (!raw) return null;
    return document.getElementById(decodeURIComponent(raw));
  }

  // If the target sits inside a content-switcher block, return that block's
  // version. This lets a plain anchor link select the correct version on its
  // own, without needing a "?version=" parameter.
  function versionForTarget(target) {
    if (!target) return null;
    const block = target.closest(".content-switcher[data-version]");
    if (!block) return null;
    const version = block.dataset.version;
    return validOptions.includes(version) ? version : null;
  }

  // Scroll to the target after the layout settles. Switching a version hides
  // the other blocks, which shifts positions, so the browser's own jump to the
  // anchor is no longer correct. Two frames lets the reflow complete first.
  function scrollToTarget(target) {
    if (!target) return;
    requestAnimationFrame(function() {
      requestAnimationFrame(function() {
        target.scrollIntoView();
      });
    });
  }

  selector.addEventListener("change", function(e) {
    switchVersion(e.target.value);
    // Reflect the selection in the URL so the address bar is a shareable link.
    const url = new URL(window.location);
    url.searchParams.set("version", e.target.value);
    history.replaceState(null, "", url);
  });

  // If the user clicks an in-page anchor that points into a different version,
  // switch to that version and scroll to it.
  window.addEventListener("hashchange", function() {
    const target = getHashTarget();
    const version = versionForTarget(target);
    if (version && version !== selector.value) {
      selector.value = version;
      switchVersion(version);
    }
    scrollToTarget(target);
  });

  // Decide the initial version. Precedence, highest first:
  //   1. The version that owns the anchor in the URL hash
  //   2. The "?version=" URL parameter
  //   3. The last selection saved in localStorage
  //   4. The selector's default value
  const urlParams = new URLSearchParams(window.location.search);
  const urlVersion = urlParams.get('version');
  const savedVersion = localStorage.getItem("content-switcher-selected-version");
  const hashTarget = getHashTarget();
  const hashVersion = versionForTarget(hashTarget);

  let initialVersion = selector.value; // Use selector's default value

  if (hashVersion) {
    initialVersion = hashVersion;
    selector.value = hashVersion;
  } else if (urlVersion && validOptions.includes(urlVersion)) {
    initialVersion = urlVersion;
    selector.value = urlVersion;
  } else if (savedVersion && validOptions.includes(savedVersion)) {
    initialVersion = savedVersion;
    selector.value = savedVersion;
  }

  // Initialize: hide all non-active versions on page load
  switchVersion(initialVersion);

  // With a version now selected and the other blocks hidden, jump to the
  // anchor so deep links land in the right place.
  if (hashTarget) {
    scrollToTarget(hashTarget);
  }
});