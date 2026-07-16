/* Get Tucked — shared behaviour for both pages.
   Hero reveal (landing only), plus scroll entrances and staggered cascades.
   Motion stays inside the app language: hard-edged in form, eased in timing,
   no bounce/spring. Everything degrades to visible-and-static without JS. */
(function () {
  var reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;

  /* ---------- hero reveal (landing only) ---------- */
  var stage = document.getElementById('stage');
  if (stage) {
    var num = document.getElementById('areaNum');
    var replay = document.getElementById('replay');
    var TARGET = 3860; // cm² — plausible loaded-rig frontal area
    var fmt = function (n) { return n.toLocaleString('en-US'); };

    var countUp = function () {
      var dur = 800, start = null;
      var step = function (ts) {
        if (!start) start = ts;
        var t = Math.min((ts - start) / dur, 1);
        var e = 1 - Math.pow(1 - t, 3); // ease-out cubic
        num.textContent = fmt(Math.round(e * TARGET));
        if (t < 1) requestAnimationFrame(step);
        else num.textContent = fmt(TARGET);
      };
      requestAnimationFrame(step);
    };

    var play = function () {
      stage.classList.remove('reveal');
      num.textContent = '0';
      void stage.offsetWidth; // reflow to restart CSS anims
      if (reduce) { num.textContent = fmt(TARGET); stage.classList.add('reveal'); return; }
      stage.classList.add('reveal');
      setTimeout(countUp, 450); // count overlaps the tail of the sweep
    };

    var fired = false;
    new IntersectionObserver(function (es) {
      es.forEach(function (en) { if (en.isIntersecting && !fired) { fired = true; play(); } });
    }, { threshold: 0.4 }).observe(stage);

    if (replay) replay.addEventListener('click', play);
  }

  /* ---------- entrance targets ----------
     Stagger groups whose direct children cascade in. Hidden state lives in
     CSS keyed on these same selectors, so there is no flash before this runs;
     here we only set per-child delays and observe for the .in trigger. */
  var groups = document.querySelectorAll(
    'section.block, .doc > section, .floor, .get-list, ul.plain, .cites'
  );
  groups.forEach(function (g) {
    var kids = g.children;
    for (var i = 0; i < kids.length; i++) {
      kids[i].style.setProperty('--sd', (i * 0.06) + 's');
    }
  });

  var targets = document.querySelectorAll(
    'section.block, .doc > section, .floor, .get-list, ul.plain, .cites, .enter'
  );

  if (reduce) {
    targets.forEach(function (e) { e.classList.add('in'); });
    return;
  }

  var io = new IntersectionObserver(function (es) {
    es.forEach(function (en) {
      if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
    });
  }, { threshold: 0.14, rootMargin: '0px 0px -8% 0px' });
  targets.forEach(function (e) { io.observe(e); });
})();
