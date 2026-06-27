// Language switcher — disclosure pattern (button + list of navigation links).
// Inlined into every page via the /*LANGMENU*/ marker by scripts/build-site.js.
(function () {
  var lang = document.querySelector('.lang');
  if (!lang) return;
  var btn = lang.querySelector('.lang__btn');
  var menu = lang.querySelector('.lang__menu');
  if (!btn || !menu) return;

  var cur = document.documentElement.lang;
  menu.querySelectorAll('a').forEach(function (a) {
    if (a.dataset.lang === cur) a.setAttribute('aria-current', 'page');
  });

  function open() { menu.hidden = false; btn.setAttribute('aria-expanded', 'true'); }
  function close(restoreFocus) {
    menu.hidden = true;
    btn.setAttribute('aria-expanded', 'false');
    if (restoreFocus) btn.focus();
  }

  btn.addEventListener('click', function (e) {
    e.stopPropagation();
    menu.hidden ? open() : close(false);
  });
  // dismiss on outside click
  document.addEventListener('click', function (e) {
    if (!lang.contains(e.target)) close(false);
  });
  // Escape returns focus to the trigger
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') close(true);
  });
  // dismiss when focus leaves the widget (Tab past the last link)
  lang.addEventListener('focusout', function (e) {
    if (!lang.contains(e.relatedTarget)) close(false);
  });
})();
