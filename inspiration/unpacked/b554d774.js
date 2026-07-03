/* Get Tucked — prototype logic */

/* ─────────────────────────────────────────────────────────────
   SCREENS
   ───────────────────────────────────────────────────────────── */
const SCREENS = [
  { id: 's0',  name: 'Welcome',            phase: 'Onboarding' },
  { id: 's_intro', name: 'How It Works',   phase: 'Onboarding' },
  { id: 's1',  name: 'Bike Setup',         phase: 'Onboarding' },
  { id: 's2',  name: 'Set the Scene',      phase: 'Onboarding' },
  { id: 's3',  name: 'Practice Capture',   phase: 'Onboarding' },
  { id: 's4',  name: 'Capture · Front+Side', phase: 'Onboarding' },
  { id: 's5',  name: 'Processing',         phase: 'Onboarding' },
  { id: 's6',  name: 'Reveal',             phase: 'Onboarding' },
  { id: 's7',  name: 'Name Position',      phase: 'Onboarding' },
  { id: 's8',  name: 'Noise Floor',        phase: 'Onboarding' },
  { id: 's9',  name: 'Comparison Prompt',  phase: 'Onboarding' },
  { id: 's10', name: 'Library · Empty',    phase: 'Main App' },
  { id: 's11', name: 'Library · Full',     phase: 'Main App' },
  { id: 's12', name: '2-Up Comparison',    phase: 'Main App' },
  { id: 's13', name: 'Leaderboard',        phase: 'Main App' },
  { id: 's14', name: 'Methodology',        phase: 'Reference' },
];

/* ─────────────────────────────────────────────────────────────
   ANIMATION SPEED — multiplier via tweaks
   ───────────────────────────────────────────────────────────── */
let SPEED = 1.0;  // 1 = normal, 0.25 = fast, 2 = slow
window.GTApply = {
  figure(on) { document.documentElement.classList.toggle('no-figure', !on); },
  animSpeed(v) { SPEED = v; },
};
const ms = (base) => base * SPEED;

/* ─────────────────────────────────────────────────────────────
   SKELETON BUILDER — head-on tucked cyclist, viewBox 0 0 200 300
   ───────────────────────────────────────────────────────────── */
const SK_BLOB = 'M100,44 C124,44 140,64 138,96 C150,120 150,150 140,156 C128,168 122,176 120,190 L118,200 C116,230 120,250 120,276 L80,276 C80,250 84,230 82,200 L80,190 C78,176 72,168 60,156 C50,150 50,120 62,96 C60,64 76,44 100,44 Z';
const SK_BONES = [
  [100,72,100,86],[100,86,74,96],[100,86,126,96],[100,86,100,200],
  [74,96,60,150],[60,150,80,188],[126,96,140,150],[140,150,120,188],
  [86,200,114,200],[86,200,82,270],[114,200,118,270],
];
const SK_JOINTS = [[100,58],[74,96],[126,96],[60,150],[140,150],[80,188],[120,188],[86,200],[114,200],[82,270],[118,270]];

function buildSkeleton(opts) {
  const o = Object.assign({ animated: false, blob: true, annotations: false, jointR: 4, headR: 14, strokeW: 1.4 }, opts || {});
  const acc = 'var(--acc)';
  const a = o.animated;
  let s = `<svg viewBox="0 0 200 300" preserveAspectRatio="xMidYMid meet" style="position:absolute;inset:0;width:100%;height:100%">`;
  if (o.blob) {
    s += `<path class="sk-el sk-blob-fill" d="${SK_BLOB}" fill="var(--blob)" fill-opacity="${a ? 0 : 1}" />`;
    if (a) s += `<path class="sk-el sk-blob-trace" d="${SK_BLOB}" fill="none" stroke="${acc}" stroke-width="1" stroke-opacity="0" />`;
  }
  SK_BONES.forEach(([x1,y1,x2,y2]) => {
    s += `<line class="sk-el sk-bone" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${acc}" stroke-width="${o.strokeW}" stroke-opacity="${a ? 0 : 0.32}" stroke-linecap="round" />`;
  });
  s += `<circle class="sk-el sk-bone" cx="100" cy="58" r="${o.headR}" fill="none" stroke="${acc}" stroke-width="${o.strokeW}" stroke-opacity="${a ? 0 : 0.32}" />`;
  SK_JOINTS.forEach(([cx,cy]) => {
    s += `<circle class="sk-el sk-joint" cx="${cx}" cy="${cy}" r="${o.jointR}" fill="${acc}" fill-opacity="${a ? 0 : 0.9}" />`;
  });
  if (o.annotations) {
    s += `<line class="sk-el sk-ann" x1="48" y1="288" x2="152" y2="288" stroke="${acc}" stroke-width="0.6" stroke-opacity="${a ? 0 : 0.45}" />`;
    s += `<line class="sk-el sk-ann" x1="48" y1="282" x2="48" y2="294" stroke="${acc}" stroke-width="0.6" stroke-opacity="${a ? 0 : 0.45}" />`;
    s += `<line class="sk-el sk-ann" x1="152" y1="282" x2="152" y2="294" stroke="${acc}" stroke-width="0.6" stroke-opacity="${a ? 0 : 0.45}" />`;
    s += `<text class="sk-el sk-ann" x="100" y="284" text-anchor="middle" font-family="Space Mono" font-size="8" fill="${acc}" fill-opacity="${a ? 0 : 0.75}">FRONTAL · 52cm</text>`;
  }
  s += `</svg>`;
  return s;
}

/* ─────────────────────────────────────────────────────────────
   CAPTURE BUILDER — single-step variant (practice)
   ───────────────────────────────────────────────────────────── */
function buildCapture(host, cfg) {
  const badge = cfg.practice
    ? `<div class="badge"><div class="badge-dot"></div><div class="badge-lbl">PRACTICE</div></div>`
    : '';
  host.innerHTML = `
    ${badge}
    <div class="cap-stephead">
      <div class="cap-steplbl" id="${host.id}-steplbl">${cfg.practice ? '' : cfg.step}</div>
      <div style="display:flex;gap:6px">
        ${cfg.practice ? '' : `<div style="width:20px;height:2px;background:var(--acc)" id="${host.id}-dot1"></div>
        <div style="width:20px;height:2px;background:var(--line)" id="${host.id}-dot2"></div>`}
      </div>
    </div>
    <div class="cam">
      <div style="position:absolute;left:0;right:0;top:50%;transform:translateY(-50%)">
        <div style="height:1px;background:var(--acc)"></div>
        <div class="mono" style="position:absolute;right:14px;bottom:6px;font-size:10px;color:var(--acc);letter-spacing:0.1em">LEVEL ✓</div>
      </div>
      <div style="position:absolute;left:50%;top:47%;transform:translate(-50%,-50%);width:150px;height:210px;border:1px solid rgba(255,255,255,0.14)">
        <div class="mono cap-guide" style="position:absolute;top:-16px;left:0;font-size:9px;color:rgba(255,255,255,0.4);letter-spacing:0.08em">${cfg.guide}</div>
      </div>
      <div class="cam-corner" style="top:14px;left:14px;border-top:1px solid rgba(255,255,255,0.2);border-left:1px solid rgba(255,255,255,0.2)"></div>
      <div class="cam-corner" style="top:14px;right:14px;border-top:1px solid rgba(255,255,255,0.2);border-right:1px solid rgba(255,255,255,0.2)"></div>
      <div class="cam-corner" style="bottom:14px;left:14px;border-bottom:1px solid rgba(255,255,255,0.2);border-left:1px solid rgba(255,255,255,0.2)"></div>
      <div class="cam-corner" style="bottom:14px;right:14px;border-bottom:1px solid rgba(255,255,255,0.2);border-right:1px solid rgba(255,255,255,0.2)"></div>
    </div>
    <div style="background:var(--bg0);border-top:1px solid var(--line);padding:14px 20px 40px;flex-shrink:0">
      <div style="display:flex;gap:8px;margin-bottom:14px">
        <div class="pill" data-pill="level"><div class="pill-dot"></div><div class="pill-lbl">LEVEL</div></div>
        <div class="pill" data-pill="perp"><div class="pill-dot"></div><div class="pill-lbl">PERP</div></div>
        <div class="pill" data-pill="bg"><div class="pill-dot"></div><div class="pill-lbl">BG</div></div>
      </div>
      <div class="btn-capture"><div class="cap-lbl">ALIGN TO CAPTURE</div></div>
    </div>`;

  wireCapture(host, { readyLabel: cfg.readyLabel, onCapture: cfg.onCapture });
}

/* ─────────────────────────────────────────────────────────────
   TWO-STEP CAPTURE — Frontal → Side-on (for s4)
   ───────────────────────────────────────────────────────────── */
function buildTwoStepCapture(host) {
  host.innerHTML = `
    <div class="bike-chip" onclick="openBikePicker()">
      <div style="text-align:left">
        <div class="bike-chip-key">SHOOTING ON</div>
        <div class="bike-chip-name">Summer Road Rig</div>
      </div>
      <div class="bike-chip-caret">▾</div>
    </div>
    <div class="cap-stephead">
      <div class="cap-steplbl" id="ts-steplbl">FRONTAL · 1 OF 2</div>
      <div style="display:flex;gap:6px">
        <div id="ts-dot1" style="width:20px;height:2px;background:var(--acc)"></div>
        <div id="ts-dot2" style="width:20px;height:2px;background:var(--line)"></div>
      </div>
    </div>
    <div class="cam">
      <div style="position:absolute;left:0;right:0;top:50%;transform:translateY(-50%)">
        <div style="height:1px;background:var(--acc)"></div>
        <div class="mono" style="position:absolute;right:14px;bottom:6px;font-size:10px;color:var(--acc);letter-spacing:0.1em">LEVEL ✓</div>
      </div>
      <div style="position:absolute;left:50%;top:47%;transform:translate(-50%,-50%);width:150px;height:210px;border:1px solid rgba(255,255,255,0.14)">
        <div class="mono cap-guide" id="ts-guide" style="position:absolute;top:-16px;left:0;font-size:9px;color:rgba(255,255,255,0.4);letter-spacing:0.08em">FRAME RIDER FRONT-ON</div>
      </div>
      <div class="cam-corner" style="top:14px;left:14px;border-top:1px solid rgba(255,255,255,0.2);border-left:1px solid rgba(255,255,255,0.2)"></div>
      <div class="cam-corner" style="top:14px;right:14px;border-top:1px solid rgba(255,255,255,0.2);border-right:1px solid rgba(255,255,255,0.2)"></div>
      <div class="cam-corner" style="bottom:14px;left:14px;border-bottom:1px solid rgba(255,255,255,0.2);border-left:1px solid rgba(255,255,255,0.2)"></div>
      <div class="cam-corner" style="bottom:14px;right:14px;border-bottom:1px solid rgba(255,255,255,0.2);border-right:1px solid rgba(255,255,255,0.2)"></div>
    </div>
    <div style="background:var(--bg0);border-top:1px solid var(--line);padding:14px 20px 40px;flex-shrink:0">
      <div style="display:flex;gap:8px;margin-bottom:14px">
        <div class="pill" data-pill="level"><div class="pill-dot"></div><div class="pill-lbl">LEVEL</div></div>
        <div class="pill" data-pill="perp"><div class="pill-dot"></div><div class="pill-lbl">PERP</div></div>
        <div class="pill" data-pill="bg"><div class="pill-dot"></div><div class="pill-lbl">BG</div></div>
      </div>
      <div class="btn-capture"><div class="cap-lbl">ALIGN TO CAPTURE</div></div>
    </div>`;

  let step = 1;
  const steplbl = host.querySelector('#ts-steplbl');
  const guide   = host.querySelector('#ts-guide');
  const dot1    = host.querySelector('#ts-dot1');
  const dot2    = host.querySelector('#ts-dot2');
  const capBtn  = host.querySelector('.btn-capture');
  const capLbl  = host.querySelector('.cap-lbl');
  const state   = { level: false, perp: false, bg: false };

  function refreshPills() {
    const ok = state.level && state.perp && state.bg;
    capBtn.classList.toggle('ready', ok);
    capLbl.textContent = ok
      ? (step === 1 ? 'CAPTURE FRONTAL' : 'CAPTURE SIDE-ON')
      : 'ALIGN TO CAPTURE';
  }

  function setStep(n) {
    step = n;
    state.level = state.perp = state.bg = false;
    host.querySelectorAll('.pill').forEach(p => p.classList.remove('ok'));
    if (n === 1) {
      steplbl.textContent = 'FRONTAL · 1 OF 2';
      steplbl.style.color = '';
      guide.textContent = 'FRAME RIDER FRONT-ON';
      dot1.style.background = 'var(--acc)';
      dot2.style.background = 'var(--line)';
    } else {
      steplbl.textContent = 'SIDE-ON · 2 OF 2';
      steplbl.style.color = '';
      guide.textContent = 'FRAME RIDER IN PROFILE';
      dot1.style.background = 'var(--fg3)';
      dot2.style.background = 'var(--acc)';
    }
    refreshPills();
  }

  host.querySelectorAll('.pill').forEach(p => {
    p.addEventListener('click', () => {
      state[p.dataset.pill] = !state[p.dataset.pill];
      p.classList.toggle('ok', state[p.dataset.pill]);
      refreshPills();
    });
  });

  capBtn.addEventListener('click', () => {
    if (!(state.level && state.perp && state.bg)) return;
    doFlash(() => {
      if (step === 1) {
        steplbl.textContent = '✓ FRONTAL CAPTURED';
        steplbl.style.color = 'var(--acc)';
        setTimeout(() => setStep(2), ms(700));
      } else {
        go(6);
      }
    });
  });

  host._reset = () => setStep(1);
}

/* ─────────────────────────────────────────────────────────────
   PILL WIRING (shared)
   ───────────────────────────────────────────────────────────── */
function wireCapture(host, cfg) {
  const state = { level: false, perp: false, bg: false };
  const capBtn = host.querySelector('.btn-capture');
  const capLbl = host.querySelector('.cap-lbl');
  function refresh() {
    const ok = state.level && state.perp && state.bg;
    capBtn.classList.toggle('ready', ok);
    capLbl.textContent = ok ? cfg.readyLabel : 'ALIGN TO CAPTURE';
  }
  host.querySelectorAll('.pill').forEach(p => {
    p.addEventListener('click', () => {
      state[p.dataset.pill] = !state[p.dataset.pill];
      p.classList.toggle('ok', state[p.dataset.pill]);
      refresh();
    });
  });
  capBtn.addEventListener('click', () => {
    if (!(state.level && state.perp && state.bg)) return;
    doFlash(cfg.onCapture);
  });
  host._reset = () => {
    state.level = state.perp = state.bg = false;
    host.querySelectorAll('.pill').forEach(p => p.classList.remove('ok'));
    refresh();
  };
}

function doFlash(done) {
  const fl = document.getElementById('flash');
  let f = 0;
  (function flash() {
    fl.style.opacity = '0.9';
    setTimeout(() => {
      fl.style.opacity = '0';
      f++;
      if (f < 3) setTimeout(flash, 150);
      else setTimeout(done, 140);
    }, 80);
  })();
}

/* ─────────────────────────────────────────────────────────────
   NAVIGATION
   ───────────────────────────────────────────────────────────── */
let cur = 0;
function go(n) {
  const from = cur;
  cur = n;
  if ((n === 14 || n === 15) && from !== 14 && from !== 15) go._returnTo = from;
  SCREENS.forEach((sc, i) => {
    const el = document.getElementById(sc.id);
    if (!el) return;
    el.classList.toggle('active', i === n);
    el.style.display = i === n ? 'flex' : 'none';
    el.style.pointerEvents = i === n ? 'all' : 'none';
  });
  const counter = document.getElementById('idx-counter');
  if (counter) counter.textContent = `${String(n + 1).padStart(2, '0')} / ${SCREENS.length} · ${SCREENS[n].name.toUpperCase()}`;
  document.querySelectorAll('.idx-item').forEach((el, i) => el.classList.toggle('cur', i === n));
  location.replace('#' + n);

  if (n === 4) { const h = document.getElementById('s3'); h._reset && h._reset(); }
  if (n === 5) { const h = document.getElementById('s4'); h._reset && h._reset(); }
  if (n === 6) runProcessing();
  if (n === 7) animateReveal();
  if (n === 12) resetLibrarySelection();
  if (n === 13) animateCompare();
  if (n === 14) setLbBike(window.__lbBike || 'all');
}
window.go = go;

function goBack() { go(go._returnTo != null ? go._returnTo : 12); }
window.goBack = goBack;

function toggleIndex(open) { document.getElementById('idx-overlay').classList.toggle('open', open); }
window.toggleIndex = toggleIndex;

/* ─────────────────────────────────────────────────────────────
   PROCESSING
   ───────────────────────────────────────────────────────────── */
const PROC_MSGS = ['SEGMENTING RIDER','ESTIMATING POSE','COMPUTING AREA','VALIDATING RESULT'];
function runProcessing() {
  const bar = document.getElementById('proc-bar');
  const msg = document.getElementById('proc-msg');
  bar.style.transition = 'none';
  bar.style.width = '0%';
  void bar.offsetWidth;
  bar.style.transition = `width ${ms(1.7)}s linear`;
  bar.style.width = '100%';
  msg.textContent = PROC_MSGS[0];
  let i = 0;
  const iv = setInterval(() => {
    i++;
    if (i < PROC_MSGS.length) msg.textContent = PROC_MSGS[i];
    else clearInterval(iv);
  }, ms(420));
  clearTimeout(runProcessing._t);
  runProcessing._t = setTimeout(() => { if (cur === 6) go(7); }, ms(1950));
}

/* ─────────────────────────────────────────────────────────────
   REVEAL ANIMATION
   desaturate-ish → blob trace → blob fill → bones → joints → annotations + countup
   ───────────────────────────────────────────────────────────── */
const delay = (ms_) => new Promise(r => setTimeout(r, ms_));

function setOp(el, fillOp, strokeOp) {
  if (!el) return;
  if (fillOp   != null) el.setAttribute('fill-opacity', fillOp);
  if (strokeOp != null) el.setAttribute('stroke-opacity', strokeOp);
}

async function animateReveal() {
  const wrap = document.getElementById('reveal-skel');
  wrap.querySelectorAll('.sk-blob-fill').forEach(e => setOp(e, 0, null));
  wrap.querySelectorAll('.sk-blob-trace').forEach(e => setOp(e, null, 0));
  wrap.querySelectorAll('.sk-bone').forEach(e => setOp(e, null, 0));
  wrap.querySelectorAll('.sk-joint').forEach(e => setOp(e, 0, null));
  wrap.querySelectorAll('.sk-ann').forEach(e => { setOp(e, 0, 0); });
  document.getElementById('reveal-num').textContent = '—';

  const token = ++animateReveal._token;
  await delay(ms(300));
  if (token !== animateReveal._token) return;
  // 1 — trace
  wrap.querySelectorAll('.sk-blob-trace').forEach(e => setOp(e, null, 0.65));
  await delay(ms(440));
  if (token !== animateReveal._token) return;
  // 2 — figure fills
  wrap.querySelectorAll('.sk-blob-fill').forEach(e => setOp(e, 1, null));
  wrap.querySelectorAll('.sk-blob-trace').forEach(e => setOp(e, null, 0.12));
  await delay(ms(380));
  if (token !== animateReveal._token) return;
  // 3 — bones
  for (const b of [...wrap.querySelectorAll('.sk-bone')]) {
    setOp(b, null, 0.34);
    await delay(ms(38));
    if (token !== animateReveal._token) return;
  }
  // 4 — joints
  for (const j of [...wrap.querySelectorAll('.sk-joint')]) {
    setOp(j, 0.9, null);
    await delay(ms(44));
    if (token !== animateReveal._token) return;
  }
  await delay(ms(130));
  if (token !== animateReveal._token) return;
  // 5 — annotations + numbers
  wrap.querySelectorAll('.sk-ann').forEach(e => setOp(e, 0.75, 0.45));
  countUp(document.getElementById('reveal-num'), 0, 124.7, ms(900));
}
animateReveal._token = 0;

function countUp(el, from, to, dur) {
  const start = performance.now();
  (function frame(now) {
    const t = Math.min((now - start) / dur, 1);
    const ease = 1 - Math.pow(1 - t, 3);
    el.textContent = (from + (to - from) * ease).toFixed(1);
    if (t < 1) requestAnimationFrame(frame);
  })(start);
}

/* ─────────────────────────────────────────────────────────────
   SETUP — enable Continue when both fields filled
   ───────────────────────────────────────────────────────────── */
function initSetup() {
  const nick  = document.getElementById('setup-nick');
  const width = document.getElementById('setup-width');
  const btn   = document.getElementById('setup-continue');
  const help  = document.getElementById('width-help');
  const tip   = document.getElementById('width-tip');
  function check() {
    btn.classList.toggle('disabled', !(nick.value.trim() && width.value.trim()));
  }
  nick.addEventListener('input', check);
  width.addEventListener('input', check);
  help.addEventListener('click', () => tip.classList.toggle('open'));
  btn.addEventListener('click', () => {
    // Onboarding creates bike #1 — feed its facts into the active bike.
    if (nick.value.trim())  BIKES[0].name = nick.value.trim();
    const w = parseInt(width.value.trim(), 10);
    if (w) BIKES[0].bar = w;
    applyActiveBike();
  });
  check();
}

/* ─────────────────────────────────────────────────────────────
   NAME POSITION
   ───────────────────────────────────────────────────────────── */
function initName() {
  const input = document.getElementById('name-input');
  const btn   = document.getElementById('name-save');
  function check() { btn.classList.toggle('disabled', !input.value.trim()); }
  input.addEventListener('input', () => {
    check();
    const label = input.value.trim().toUpperCase() || 'HOODS, FULLY LOADED';
    const rl = document.getElementById('reveal-poslbl');
    if (rl) rl.textContent = `FRONTAL AREA · ${label}`;
    const ln = document.getElementById('lib-new-name');
    if (ln) ln.textContent = label;
  });
  btn.classList.add('disabled');
}

/* ─────────────────────────────────────────────────────────────
   LIBRARY
   ───────────────────────────────────────────────────────────── */
function resetLibrarySelection() {
  document.querySelectorAll('#s11 .lib-row').forEach(r => r.classList.remove('sel'));
  updateCompareBar();
}
function updateCompareBar() {
  const n = document.querySelectorAll('#s11 .lib-row.sel').length;
  document.getElementById('cmp-bar').classList.toggle('show', n >= 2);
  document.getElementById('cmp-bar-count').textContent = `COMPARE (${n})`;
}
function initLibrary() {
  document.querySelectorAll('#s11 .lib-row').forEach(row => {
    row.addEventListener('click', () => {
      const sel = document.querySelectorAll('#s11 .lib-row.sel');
      if (!row.classList.contains('sel') && sel.length >= 2) sel[0].classList.remove('sel');
      row.classList.toggle('sel');
      updateCompareBar();
    });
  });
  document.querySelectorAll('#s11 .fchip').forEach(c => {
    c.addEventListener('click', () => {
      document.querySelectorAll('#s11 .fchip').forEach(x => x.classList.remove('on'));
      c.classList.add('on');
    });
  });
}

/* ─────────────────────────────────────────────────────────────
   2-UP COMPARISON
   ───────────────────────────────────────────────────────────── */
function animateCompare() {
  countPct(document.getElementById('cmp-delta'), 0, -4.8, ms(850));
}
function countPct(el, from, to, dur) {
  const start = performance.now();
  (function frame(now) {
    const t  = Math.min((now - start) / dur, 1);
    const v  = from + (to - from) * (1 - Math.pow(1 - t, 3));
    el.textContent = (v > 0 ? '+' : '−') + Math.abs(v).toFixed(1) + '%';
    if (t < 1) requestAnimationFrame(frame);
  })(start);
}
function initCompare() {
  document.querySelectorAll('#s12 .tgl').forEach(t => {
    t.addEventListener('click', () => t.classList.toggle('on'));
  });
}

/* ─────────────────────────────────────────────────────────────
   BIKES — the bike is the measurement ruler. A position belongs to
   exactly one bike and inherits its handlebar-width scale.
   Editing a bar width only affects NEW captures; past numbers are
   locked (they were measured with the ruler as it was then).
   Full bike management lives in Settings; this is the capture-time picker.
   ───────────────────────────────────────────────────────────── */
const BIKES = [
  { id: 'b1', name: 'Summer Road Rig', type: 'ROAD',   bar: 420 },
  { id: 'b2', name: 'Gravel Bike',     type: 'GRAVEL', bar: 460 },
];
let activeBikeId = 'b1';
let newBikeType = 'ROAD';

function activeBike() { return BIKES.find(b => b.id === activeBikeId) || BIKES[0]; }

function renderBikeList() {
  const list = document.getElementById('bike-list');
  if (!list) return;
  list.innerHTML = BIKES.map(b => `
    <div class="bike-row ${b.id === activeBikeId ? 'on' : ''}" onclick="selectBike('${b.id}')">
      <div class="bike-radio"><span class="bike-radio-tick">✓</span></div>
      <div class="bike-row-body">
        <div class="bike-row-name">${b.name}</div>
        <div class="bike-row-meta">
          <span class="chip ${b.type === 'ROAD' ? 'acc' : ''}">${b.type}</span>
          <span class="bike-ruler">RULER · ${b.bar} mm BAR</span>
        </div>
      </div>
    </div>`).join('');
}

function applyActiveBike() {
  const b = activeBike();
  document.querySelectorAll('.bike-chip-name').forEach(el => { el.textContent = b.name; });
  const t = document.getElementById('lib-new-type');
  const r = document.getElementById('lib-new-rig');
  if (t) { t.textContent = b.type; t.classList.toggle('acc', b.type === 'ROAD'); }
  if (r) r.textContent = b.name.toUpperCase();
}

function openBikePicker() {
  renderBikeList();
  document.getElementById('bike-sheet').classList.add('open');
}
window.openBikePicker = openBikePicker;
function closeBikePicker() {
  document.getElementById('bike-sheet').classList.remove('open');
  collapseAddBike();
}
window.closeBikePicker = closeBikePicker;

function selectBike(id) {
  activeBikeId = id;
  applyActiveBike();
  renderBikeList();
  setTimeout(closeBikePicker, ms(180));
}
window.selectBike = selectBike;

function toggleAddBike() {
  const form = document.getElementById('bike-add-form');
  const open = form.classList.toggle('open');
  document.getElementById('bike-add-plus').textContent = open ? '×' : '+';
  document.getElementById('bike-add-lbl').textContent = open ? 'CANCEL' : 'ADD A BIKE';
  if (open) document.getElementById('newbike-nick').focus();
  else collapseAddBike();
}
window.toggleAddBike = toggleAddBike;

function collapseAddBike() {
  const form = document.getElementById('bike-add-form');
  form.classList.remove('open');
  document.getElementById('bike-add-plus').textContent = '+';
  document.getElementById('bike-add-lbl').textContent = 'ADD A BIKE';
  document.getElementById('newbike-nick').value = '';
  document.getElementById('newbike-width').value = '';
  pickType('ROAD');
  checkNewBike();
}

function pickType(t) {
  newBikeType = t;
  document.querySelectorAll('#newbike-seg .seg-opt').forEach(o => o.classList.toggle('on', o.dataset.type === t));
}
window.pickType = pickType;

function checkNewBike() {
  const nick = document.getElementById('newbike-nick').value.trim();
  const width = document.getElementById('newbike-width').value.trim();
  document.getElementById('newbike-save').classList.toggle('disabled', !(nick && width));
}

function saveBike() {
  const nick = document.getElementById('newbike-nick').value.trim();
  const width = parseInt(document.getElementById('newbike-width').value.trim(), 10);
  if (!nick || !width) return;
  const id = 'b' + (BIKES.length + 1) + '_' + Date.now();
  BIKES.push({ id, name: nick, type: newBikeType, bar: width });
  activeBikeId = id;
  applyActiveBike();
  collapseAddBike();
  renderBikeList();
  setTimeout(closeBikePicker, ms(220));
}
window.saveBike = saveBike;

/* ─────────────────────────────────────────────────────────────
   LEADERBOARD — ranks YOUR OWN saved positions by frontal area.
   Smallest area = most aero = rank 1. "% vs upright" is measured
   against your most-upright saved position (HOODS, RELAXED).
   Toggle filters by bike class (ALL / ROAD / TT).
   ───────────────────────────────────────────────────────────── */
const LB_DATA = [
  { name: 'BAR TOPS, LOW',      bike: 'GRAVEL', area: 109.6, date: 'MAY 14' },
  { name: 'AERO TUCK',          bike: 'GRAVEL', area: 118.2, date: 'JUN 03' },
  { name: 'DROPS, SPRINT',      bike: 'ROAD', area: 121.0, date: 'MAY 28' },
  { name: 'HOODS, FULLY LOADED', bike: 'ROAD', area: 124.7, date: 'JUN 03', latest: true },
  { name: 'HOODS, RELAXED',     bike: 'ROAD', area: 131.4, date: 'MAY 28', upright: true },
];
const LB_BASELINE = Math.max(...LB_DATA.map(r => r.area));  // most-upright = baseline

function renderLeaderboard(bike) {
  const list = document.getElementById('lb-list');
  if (!list) return;
  const rows = LB_DATA
    .filter(r => bike === 'all' || r.bike === bike)
    .sort((a, b) => a.area - b.area);
  const min = Math.min(...rows.map(r => r.area));
  const max = Math.max(...rows.map(r => r.area));
  list.innerHTML = rows.map((r, i) => {
    const rank = i + 1;
    const bar = (1 - (r.area - min) / (max - min || 1)) * 78 + 22;  // smaller area → longer bar
    const pct = ((r.area - LB_BASELINE) / LB_BASELINE) * 100;
    const sub = r.upright ? 'YOUR UPRIGHT BASELINE' : '−' + Math.abs(pct).toFixed(1) + '% vs upright';
    return `<div class="lb-row ${r.latest ? 'you' : ''}">
        <div class="lb-rank ${rank <= 3 ? 'top' : ''}">${rank}</div>
        <div class="lb-body">
          <div class="lb-name">${r.name}${r.latest ? '<span class="lb-you-tag">LATEST</span>' : ''}<span class="chip ${r.bike === 'ROAD' ? 'acc' : ''}">${r.bike}</span></div>
          <div class="lb-bar"><div class="lb-bar-fill" style="width:${bar}%"></div></div>
        </div>
        <div class="lb-valwrap"><div class="lb-val">${r.area.toFixed(1)}</div><div class="lb-sub">${sub}</div></div>
      </div>`;
  }).join('');
}

function setLbBike(bike) {
  window.__lbBike = bike;
  document.querySelectorAll('#s13 .lb-tgl').forEach(t => t.classList.toggle('on', t.dataset.bike === bike));
  const note = document.getElementById('lb-sub-note');
  if (note) note.textContent = bike === 'all'
    ? 'Your positions, ranked by frontal area.'
    : `Your ${bike} positions, ranked by frontal area.`;
  renderLeaderboard(bike);
}
window.setLbBike = setLbBike;

/* ─────────────────────────────────────────────────────────────
   STAGE SCALING
   ───────────────────────────────────────────────────────────── */
function scaleStage() {
  const w = window.innerWidth, h = window.innerHeight;
  if (!w || !h) {            // cold-load race: container not sized yet
    requestAnimationFrame(scaleStage);
    return;
  }
  const s = Math.min(w / 413, h / 892, 1) || 1;  // never scale to 0
  document.querySelector('.stage').style.transform = `scale(${s})`;
}

/* ─────────────────────────────────────────────────────────────
   BOOT
   ───────────────────────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  // inject skeletons
  document.getElementById('reveal-skel').innerHTML   = buildSkeleton({ animated: true, annotations: true, jointR: 4, strokeW: 1.5 });
  document.getElementById('name-bg-skel').innerHTML  = buildSkeleton({ animated: false, jointR: 3.5, strokeW: 1.4 });
  document.querySelectorAll('[data-thumb]').forEach(t => {
    t.innerHTML = buildSkeleton({ animated: false, blob: true, jointR: 6, strokeW: 2.4, headR: 16 });
  });
  document.getElementById('cmp-panel-a').innerHTML = buildSkeleton({ animated: false, jointR: 5, strokeW: 1.8 });
  document.getElementById('cmp-panel-b').innerHTML = buildSkeleton({ animated: false, jointR: 5, strokeW: 1.8 });

  // build capture screens
  buildCapture(document.getElementById('s3'), {
    practice: true,
    guide: 'FRAME RIDER FRONT-ON',
    readyLabel: 'CAPTURE (NOT SAVED)',
    onCapture: () => go(5),
  });
  buildTwoStepCapture(document.getElementById('s4'));

  // build index menu
  const list = document.getElementById('idx-list');
  list.innerHTML = SCREENS.map((sc, i) => `
    <div class="idx-item" data-i="${i}">
      <div class="idx-num">${String(i + 1).padStart(2, '0')}</div>
      <div class="idx-name">${sc.name}</div>
      <div class="idx-phase">${sc.phase}</div>
    </div>`).join('');
  list.querySelectorAll('.idx-item').forEach(it => {
    it.addEventListener('click', () => { go(parseInt(it.dataset.i, 10)); toggleIndex(false); });
  });

  initSetup();
  initName();
  initLibrary();
  initCompare();

  // bike picker wiring
  ['newbike-nick', 'newbike-width'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('input', checkNewBike);
  });
  applyActiveBike();
  renderBikeList();

  // deep-link from hash
  const h = parseInt((location.hash || '').replace('#', ''), 10);
  go(Number.isFinite(h) && h >= 0 && h < SCREENS.length ? h : 0);

  scaleStage();
  window.addEventListener('resize', scaleStage);
  window.addEventListener('load', scaleStage);
  requestAnimationFrame(scaleStage);
});
