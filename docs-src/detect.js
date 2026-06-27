(function () {
  try {
    var KEY = 'rp_lang';
    if (localStorage.getItem(KEY)) return;           // already detected/chosen — skip (anti-loop)
    if (navigator.webdriver) return;                 // automation
    var ua = navigator.userAgent || '';
    if (/bot|crawl|spider|slurp|headless|wget|curl|lighthouse|pingdom/i.test(ua)) return;
    var supported = {{{supported_list}}};
    var base = '{{base}}';
    var cur = document.documentElement.lang;
    var picks = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
    var match = null;
    for (var i = 0; i < picks.length; i++) {
      var short = String(picks[i] || '').toLowerCase().split('-')[0];
      if (supported.indexOf(short) >= 0) { match = short; break; }
    }
    if (match && match !== cur) {
      var langRe = new RegExp('^\\/(' + supported.join('|') + ')(\\/|$)');
      var rel = location.pathname.replace(base, '').replace(/\/index\.html$/, '/');
      rel = rel.replace(langRe, '/');
      rel = rel.replace(/\/+$/, '/');
      // English is served from the root, not under /en/
      var target = match === 'en' ? (base + rel) : (base + '/' + match + rel);
      target = target.replace(/\/{2,}/g, '/');
      try { localStorage.setItem(KEY, match); } catch (e) {}  // best-effort; don't gate the redirect on storage
      location.replace(target);
    } else {
      try { localStorage.setItem(KEY, cur); } catch (e) {}
    }
  } catch (e) {}
})();
