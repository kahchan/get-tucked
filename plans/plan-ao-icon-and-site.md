# Plan AO: app icon, site and store refinement

Direction set 2026-10-17. Studio = **Imprecisely Accurate Instruments** (design system "Approximately Scientific", `plans/design-ref/`). Visual: Get Tucked keeps acid-on-black and borrows the studio's voice and drafting devices; the icon also explores one studio-palette lane. Caliper stand-in killed. Validation = shelf + blur tests (no rider panel).

## Voice rule

**Measured = ±, modelled = ≈** (≈ deferred: keep `~` for now, see Decisions 3). Area wears ±. Never ≈ on cm² or mm. FIG/TABLE captions on real figures only, never on step screenshots. Borrow the studio's honesty, not its shrug: no "approximately right", "no peer review" or "not particularly rigorous" on Get Tucked. Studio credit stays in the footer and the store's last line. Em-dash-free copy (see launch_marketing memory).

## Part 1: icon

**One idea: smaller to the wind.** A rider tucking, seen head-on: the method (head-on) and the result (less area). Side-on runs as the control lane. 64 px legibility decides.

**Studio tell: the error band.** One hairline tolerance outline offset from the main shape. Visible at 1024, harmless at 64. No ≈ / ± glyph in the icon.

**Source rules** (Kah is unsure about a real person's silhouette becoming the mark, 2026-10-17)
- **Construct, don't trace.** Build figures from primitives (circles, straight segments, few curves). Take proportions and pose from Kah's masks: `tools/matte-lab/output/IMG_067{4,5,6}.JPG/2-subject-mask.png` (0676 head-on upright, 0674 head-on tucked, 0675 side-on tuck). The result must not be a likeness of anyone.
- `1.jpg` / `2.jpg` / `3.jpg` and Declan's site path: pose reference only.
- Lane d carries no figure at all, so a non-figurative mark is on the table if Kah decides against a rider.

**Kill criteria.** Hard fails: K1 cliché (upright side profile, skeleton as main read, swooshes/speed lines, ruler/caliper, lone wheel, arrows, two solid disc wheels as main mass) · K2 any type or glyph · K3 baked corners/gradients/shadows · K4 lost or not brightest in luminance-only render · K5 implies airflow/CdA/watts/speed · K6 traced from a banned source.
Scored 0–2, ≥10 of 14 to reach 1024: S1 rider read at 64 (head-on: not "person standing") · S2 tuck read · S3 survives σ=2 blur at 64, distinct from generic person/bike glyph · S4 found <1 s on home-screen mock, default + tinted · S5 error band visible at 1024, harmless at 64 · S6 mass in central 80% (bottom bleed allowed) · S7 one idea in ≤4 words.

**Lanes** (one worker each; output in `tools/appicon/artifact/project/lanes/<id>/`: ≥10 SVGs at 1024 viewBox + `index.json` per the header of `tools/appicon/canvas.html`, best 3 as `final-{1,2,3}.svg` with scores in the item `note`)

| Lane | Palette | Premise | Seeds |
|---|---|---|---|
| **a · Head-on** (recommended) | `#080808` field, acid `#D9F020`, amber `#E8A020`, band `#8A8A8A`/`#333333`, shadow `#161616` | Wind's-eye view; tuck as a shrink | 1 A/B tuck: 0676 outline (amber or fg3) behind solid acid 0674, aligned on the wheel contact · 2 solid acid 0676 + one error band, wheel bleeding off the bottom · 3 dark 0676 + acid bar-end tap squares and dashed dimension line · 4 frozen scan: 0674 acid above a hairline at ~60%, dark below |
| **b · Side-on** (control) | as a | Say the name: the flat-back tuck | 1 rider + bike to the hubs, wheels bleed off the bottom · 2 A/B back angle (only if Kah has a side-on upright IMG_067x; else skip) · 3 back + head as one acid stroke over a dark bike · 4 wheels as hairline rings, solid rider |
| **c · Plate** (studio) | blueprint `#173359`/`#1E4478`, paper `#FFFDF8`/`#F7F4EC`, signal `#C85416` (paper) / `#F07C2B` (blueprint), hairline `#CBDDF3`/`#2F5687` | Cyanotype photogram: a sun-print is projected frontal area | 1 blueprint field, paper 0674 shadow, orange error band · 2 A/B: 0676 in `#5C86BC`, 0674 in paper on top · 3 paper + faint graph grid, blueprint silhouette, orange tick at bar ends · 4 side-on 0675 photogram (comparison only) |
| **d · Area** (no figure) | as a | The measurement itself: a projected area getting smaller, with its error band | 1 two nested areas, outer hairline (before), inner solid (after) · 2 the matte as counted pixels: a coarse acid pixel block with one hairline band · 3 a scan band across a field: acid above, dark below · 4 a shape that is half its own error band. K1 still applies (no ruler, caliper, arrows). S1/S2 read as "area, smaller" instead of "rider". |

A lane c win is a brand call for Kah (answer 2026-10-17: studio palette on the icon only).

**Canvas.** Design artifact https://claude.ai/artifact/DibS5jHc7fbjGviSKniYDJ (one artboard per lane, orchestrator publishes). Shelf tests stay local: serve `repo` (`.claude/launch.json`), open `/tools/appicon/canvas.html`; competitor icons in gitignored `tools/appicon/shelf/`.

**Finalist proof.** 1 Icon Composer `.icon` master, layered SVG, replaces `tools/appicon/AppIcon.icon`; retire `make.sh` + `appicon.svg` · 2 sizes 1024/180/120/87/80/58/40 (S1 at 40) · 3 default, dark, clear, tinted (light + dark) in Icon Composer, then on device · 4 home-screen mock, light + dark wallpaper, default + tinted · 5 store search row vs Bike Fast Fit, RoadFitter, FramIQ, Bike Biomechanics, LeGizmo, Notio · 6 blur σ=2 @64, σ=5 @180, 50% grey, **head-on and side-on finalists side by side** · 7 separate pixel-snapped 16/32 favicon + `favicon.svg` + 180 touch icon · 8 OG card 1200×630, iMessage + Reddit preview · 9 three days on Kah's home screen before lock.

## Part 2: motion

The mark almost never moves. Studio idiom (`cubic-bezier(.2,.6,.2,1)`, 120/200/420/900 ms, `steps(6,end)`) for scripted studio-voice surfaces only. In-app motion stays `Theme.Motion`; its damping-1.0 `interactive` spring stays.

| Surface | Spec |
|---|---|
| Icon (Icon Composer) | Static. Fill `#080808` (lane c `#173359`). Back group: band/outline, glass off, 60%. Front group: solid shape, glass + specular on, translucency off, neutral shadow 0.3. Tune by eye in every look. |
| Launch screen | No change. HIG: not a splash. |
| First run, `WelcomeView` | Optional: mark 64 pt above wordmark, one `.scanReveal` at `Theme.Motion.sweep` (0.55 s) +0.15 s, wordmark `cascadeIn(0)`. Reduce Motion: progress 1, `entrance(base)`. Returning launch: no motion. |
| Store preview, first 3 s | App capture only (Guideline 2.3.4). 886×1920. 0–0.5 camera at shutter · 0.5–1.05 ScanReveal · 1.05–1.85 count-up · 1.85–3.0 hold with ± visible. No text. Poster = finished reveal. Highest-leverage motion item. |
| Site hero | Keep (0.9 s wipe already = `--dur-plot`). |
| FIG captions (new) | 1 px rule `scaleX(0→1)` from left, 420 ms, ease-plot, on existing `.in`. Reduce Motion: static. |
| Topbar mark, favicon, OG | Static. Mark 20 px before topbar wordmark. Studio seal/caliper stay footer-only. |

## Part 3: site and store copy

Blocked on Q1 (floor) for every ± sentence. Line refs as of 2026-10-17.

**docs/index.html**
- **Blockers:** `og-hero.png` (:12) missing: build 1200×630 (hero frame, matte revealed, "See what the wind sees.", "Frontal area from one photo.", the mark, no cm²). No favicon/touch icon: add.
- Rewrite: hero caption (:106) → "FIG. 01 · Declan head-on, fully loaded. The app cut out rider, bike and bags." · side-on captions (:189, :249) → "FIG. 02 · Upright." / "FIG. 03 · Tucked." · floor body (:338–340) and FAQ accuracy (:382) → the Q1 wording · floor table (:343–350): replace the invented 1.8% with Paul's bike, Dec tall → tucked, 5821 vs 5746 cm², 1.3% apart; floor value read off the device verdict; row "combined floor (two readings)"; caption "TABLE 1 · Paul's bike, tall vs tucked."; % only.
- Cut: floor-cap (:351), duplicate "No Android" sentence (:372–373).
- Fix: "Press kit →" (:425) link or cut · "© 2026 Get Tucked" (:426) → "© 2026 Kah Chan" · topbar gains the mark.
- Keep: meta/og text, eyebrow "measured, not guessed", tagline, proof strip numbering, so-what fine print, other FAQs, footer studio block. "$20" stays until the store tier is set.

**docs/methodology.html**: ±3% claims (:206, :222) → Q1 wording · "The maths behind the shrug" → "The maths behind the floor" · FIG/TABLE captions on formula and scale-chain figures · cut the 🙂 emoji (:293, :305, :316), keep the text · optional cite: Tailfin vendor drag test (~17.5 min / 200 km, full loadout) as an outside sanity check, not a claim.

**Store** (`marketing/app-store-listing.md`, `marketing/store-shots/`): TOLERANCE (:53) → "Each reading shows its error bar: at least ±3%, wider when a live shot's three frames disagree. If two setups differ by less than their combined error, the app says indistinguishable, not "1.8% better". Frontal area is not drag, and the time estimate is a range, not a promise." · shot 01 sub (shots.html:26) → "5569 ± N CM²", N from device · shot 05 spec (:30) and creative header (creative.html:36) → "ERROR BAR ON EVERY READING · WIND TUNNEL: NONE" · creative search spec (:60) → "SHOOT · TAP THE BARS · COMPARE · ± ON EVERY NUMBER" · shot 06 moves to slot 3 · keep name, subtitle, promo text, keywords, studio credit, shot 03 "Probably.".

## Decisions (Kah, 2026-10-17)

1. **Noise floor: yes.** Clamp live bursts to `max(spread, AnalysisMath.uncertaintyFraction)` (`AnalysisEngine.swift:336`). All copy says "at least ±3%", incl. in-app `HowItWorksView.swift:216`.
2. **Seller: individual enrolment, "Kah Chan".** Store © and site footer © use "Kah Chan"; studio credit line stays as is.
3. **≈ deferred.** Keep `~` on the site, app and screenshots for now; the ±/≈ split is a later pass. Drop the `≈ 3–17 min` rewrite.
4. **Silhouette as mark: undecided.** Hence construct-don't-trace and lane d.
5. **Lane c win:** studio palette on the icon only.
6. Head-on vs side-on if both pass: still the shelf test; recommend head-on A/B if S1 = 2 at 64 px.

## Follow-up (own item)

App compare cards show cm² with no ± (screenshot 06). Under the voice rule a measured number wears its error bar.

## Round 1 (closed 2026-10-17)

54 candidates, 4 lanes. Root cause of weak reads: a full-length head-on rider is ~1:3, fills <20% of the square, reads as keyhole/up-arrow at 40 px. Crop problem, not drawing.

| Lead | Fill | Verdict |
|---|---|---|
| F1 `a/08` head-on | 25% | Base for round 2 as a **bust crop** |
| F2 `d/01` area plot | 26% | No-figure contender |
| F3 `c/final-1` | 18% | Palette + bar stub only; re-skins F1/F2 |
| `b/final-1` side-on | 28% | Frozen control: sits among 4 side-on cyclist glyphs on the shelf |

**Rule edits**
- No hairline bands in the icon. Tolerance device = band ≥40 u with ≥24 u gap, or a solid registration-offset plate 24–32 u down-right (`--shadow-print`). Hairlines stay on site/OG.
- S5 scores only the tolerance device; a before-shape scores under S2. S5 is a tie-breaker: gate on S1–S4, S6, S7 (max 12, pass ≥9).
- Head-on anti-arrow: neck gap ≥40 u, shoulder slope ≤20°, round/flat helmet top, arms as an A-frame to the bar ends. Full-length head-on also needs knees flanking the wheel with ≥32 u gap.
- K4 is judged on the layered build: foreground layers alone, white on black, must read. Icon Composer tinted preview is the authority.
- Side-on S3 is capped at 1.
- Tuck/upright ratio is a design parameter, never described as measured. Head drop ≥72 u at 1024.

## Round 2 spec (Kah's picks override the cull, 2026-10-17)

Kah: **A `final-3` "outline before, tuck after"**, silhouette to be refined · **B is out** (no side-on control) · **C's drafting grid** (`c/04`, `c/08`) and **D's counted cells** (`d/08`) are interesting. The CD's F1 bust and F2 pentagon are parked.

The three picks share one idea: **area by counting squares.** The app measures area by counting matte pixels; the studio draws on graph paper. A tuck filled cell by cell on a drafting grid, inside the outline of the upright, is the method drawn honestly.

- **R2a · Silhouette (stage 1, one worker):** refine `a/final-3`. Constructed head-on upright + tuck, same baseline, with the anti-arrow rules, a constructed bar with square tap-hands, and the upright as an amber **outline ≥40 u** (no hairline). Two crops: full-length, and bust (helmet top y≈110, bar centre y≈600, figure bleeds off the bottom, only a 64 u fork/wheel stub below the bar; fill 38–45%, box width 80–88%). Bar 56 u, ≥15% wider than the shoulders each side, 96×96 u square hands. Head drop ≥72 u. Ship the two master shapes as standalone layers (`upright.svg`, `tuck.svg`, transparent, same 1024 space) for stage 2.
- **R2b · Grid (stage 2):** R2a's pair on a drafting grid. House palette (grid `#161616`/`#262626` on `#080808`) and plate palette (`#2F5687` on `#173359`). Grid pitch tested at 64 px for moiré.
- **R2c · Counted cells (stage 2):** the tuck rendered as filled grid cells, the upright as its stepped cell outline or the R2a outline. Cell pitch chosen so cells merge to a solid at 64 px and read as counted at 1024. One no-figure variant (refined `d/08`) kept as the abstract fallback.
- Shelf test as before, without the side-on control.


