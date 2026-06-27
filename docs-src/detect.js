(function () {
  try {
    var KEY = 'rp_lang';
    if (localStorage.getItem(KEY)) return;           // user already chose
    if (navigator.webdriver) return;                 // automation
    var ua = navigator.userAgent || '';
    if (/bot|crawl|spider|slurp|headless|wget|curl|lighthouse|pingdom/i.test(ua)) return;
    var supported = ['en', 'tr', 'zh', 'hi', 'de', 'fr', 'nl'];
    var cur = document.documentElement.lang;
    var picks = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    var match = null;
    for (var i = 0; i < picks.length; i++) {
      var short = String(picks[i] || '').toLowerCase().split('-')[0];
      if (supported.indexOf(short) >= 0) { match = short; break; }
    }
    if (match && match !== cur) {
      var base = '/review-pro';
      var rel = location.pathname.replace(base, '').replace(/\/index\.html$/, '/');
      rel = rel.replace(/^\/(en|tr|zh|hi|de|fr|nl)(\/|$)/, '/');
      rel = rel.replace(/\/+$/, '/');
      var target = base + '/' + match + (rel === '/' ? '/' : rel);
      target = target.replace(/\/{2,}/g, '/');
      localStorage.setItem(KEY, match);
      location.replace(target);
    } else {
      localStorage.setItem(KEY, cur);
    }
  } catch (e) {}
})();
