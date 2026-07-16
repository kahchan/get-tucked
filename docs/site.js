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

  /* ---------- so-what calculator (Plan S3) ----------
     Same physics model as ios/GetTucked/Analysis/EffortModel.swift — keep
     every constant below literally identical to that file (the pairing is
     noted there too; no shared code, different languages/runtimes). Fixed
     baseline (30 km/h, 4500 cm² / 0.45 m², 80 kg, 200 km) stands in for a
     real measurement so a visitor never needs their own number to see the
     shape of the payoff — the slider's % maps straight onto that baseline. */
  var sowhat = document.getElementById('sowhat');
  if (sowhat) {
    var CRR = 0.005, RHO = 1.225, G = 9.81, CD = 0.7;
    var BASE_AREA_CM2 = 4500, SPEED_KMH = 30, MASS_KG = 80, DISTANCE_KM = 200;

    var impliedPowerW = function (speedMS, cdaM2, massKg) {
      return speedMS * (0.5 * RHO * cdaM2 * speedMS * speedMS + CRR * massKg * G);
    };
    // Bisection on [0.5x, 2x] the reference speed, same bracket/tolerance/
    // iteration cap as the Swift original — power is strictly increasing in
    // v, so this always converges to the one positive root.
    var speedAtPowerMS = function (powerW, cdaM2, massKg, referenceSpeedMS) {
      var lo = 0.5 * referenceSpeedMS, hi = 2.0 * referenceSpeedMS, tol = 0.001, i = 0;
      while (hi - lo > tol && i < 100) {
        var mid = (lo + hi) / 2;
        var residual = impliedPowerW(mid, cdaM2, massKg) - powerW;
        if (residual < 0) lo = mid; else hi = mid;
        i++;
      }
      return (lo + hi) / 2;
    };
    var timeDeltaMinutes = function (areaACm2, areaBCm2, speedMS, massKg, distanceM) {
      var cdaA = CD * areaACm2 / 10000, cdaB = CD * areaBCm2 / 10000;
      var power = impliedPowerW(speedMS, cdaA, massKg);
      var speedB = speedAtPowerMS(power, cdaB, massKg, speedMS);
      return (distanceM / speedMS - distanceM / speedB) / 60;
    };
    var timeDeltaBandMinutes = function (areaACm2, areaBCm2, speedMS, massKg, distanceM, noiseFraction) {
      noiseFraction = noiseFraction || 0.03;
      var narrower = timeDeltaMinutes(areaACm2 * (1 - noiseFraction), areaBCm2 * (1 + noiseFraction), speedMS, massKg, distanceM);
      var wider = timeDeltaMinutes(areaACm2 * (1 + noiseFraction), areaBCm2 * (1 - noiseFraction), speedMS, massKg, distanceM);
      return { low: Math.min(narrower, wider), high: Math.max(narrower, wider) };
    };

    var slider = document.getElementById('sowhatPct');
    var rangeEl = document.getElementById('sowhatRange');
    var pctEl = document.getElementById('sowhatPctLabel');

    var render = function () {
      var pct = Number(slider.value);
      pctEl.textContent = pct;
      var areaB = BASE_AREA_CM2 * (1 - pct / 100);
      var band = timeDeltaBandMinutes(BASE_AREA_CM2, areaB, SPEED_KMH / 3.6, MASS_KG, DISTANCE_KM * 1000);
      // Same "don't clamp away zero" honesty rule as the app (S2 §4) — a
      // 1% guess can land inside the noise band, and the low end should
      // show that rather than pretending a confident nonzero floor.
      var lo = Math.max(0, Math.round(band.low));
      var hi = Math.max(lo, Math.round(band.high));
      rangeEl.textContent = '~' + lo + '–' + hi + ' min';
    };

    slider.addEventListener('input', render);
    render();
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
