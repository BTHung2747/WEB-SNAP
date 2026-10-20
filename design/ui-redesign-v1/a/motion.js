// Progressive reveal only. CSS handles entry/result feedback without touching
// demo state, aria-live, focus or actions. Native APIs, no animation engine.
(function () {
  if (!document.body.classList.contains('theme-a')) return;
  if (typeof matchMedia !== 'function' || typeof IntersectionObserver !== 'function') return;

  const preference = matchMedia('(prefers-reduced-motion: reduce)');
  const groups = [...document.querySelectorAll('.guide-list li, .help-strip, .admin-stats, .admin-panel')];
  const revealed = new WeakSet();
  let observer;

  function stop() {
    observer?.disconnect();
    observer = undefined;
  }

  function start() {
    stop();
    if (preference.matches) return;
    observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting || revealed.has(entry.target)) return;
        revealed.add(entry.target);
        entry.target.classList.add('a-reveal-once');
        observer?.unobserve(entry.target);
      });
    }, { threshold: .12 });
    groups.forEach((group) => { if (!revealed.has(group)) observer.observe(group); });
  }

  function change() {
    if (preference.matches) stop();
    else start();
  }

  function suspend() {
    stop();
    preference.removeEventListener('change', change);
  }

  // Resume correctly after a history-cache restore; revealed groups stay seen.
  function resume(event) {
    if (!event.persisted) return;
    preference.addEventListener('change', change);
    start();
  }

  preference.addEventListener('change', change);
  window.addEventListener('pagehide', suspend);
  window.addEventListener('pageshow', resume);
  start();
})();
