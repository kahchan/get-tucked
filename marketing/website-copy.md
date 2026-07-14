# Get Tucked — Website Copy

**Status:** `draft v1` · for review and lock before HTML build
Companion to [`website-spec.md`](website-spec.md). Copy is the actual work; the build is
half a day once this is locked (spec, *Build order*).

**Conventions in this file**

- `[NAME]` — the product name, tokenised pending the domain / name-rejection fallback
  (spec *Open questions*). Reads "Get Tucked" today.
- `[PRICE]` — one-time price, tokenised (reads "USD $20" today).
- `[APP_STORE_URL]`, `[METHODOLOGY_URL]`, `[PRESS_KIT_URL]`, `[CONTACT_EMAIL]` — fill at build.
- **Every figure is grounded in the shipping code** (`ios/GetTucked/Analysis/AnalysisMath.swift`,
  `HowItWorksView.swift`). No claim here exceeds what the app measures. Notably: scale is a
  **known-length ruler only — no camera intrinsics**, and the measurement floor is a **fixed,
  conservative ±3% per reading**, not a per-user repeatability figure. See the *Grounding
  notes* at the end.
- Voice: **we** (two dads with day jobs). No exclamation marks. No gamification. The name is
  the only joke.

---

# Page 1 — Landing (`/`)

### 1. Name + tagline

> # [NAME]
> ## Be informed, don't guess.

### 2. Hero visual

> **🖼 Image — the reveal (the whole product in one frame).** A real app capture: loaded
> gravel bike + rider against a plain wall, acid-yellow silhouette matte laid over the photo,
> pose joints marked, and one large Space-Mono cm² number. This is also the **animated hero**
> — see the hero-reveal spec in `website-spec.md` (scan-wipe + count-up). *Asset dependency:
> needs a clean real capture; if the app can't produce one yet, this gates the page.*

Caption (small, mono):

> One photo. Silhouette isolated. Frontal area, in cm².

### 3. Three-sentence description

*Tightened — three actual sentences, hook first. This is the whole pitch above the fold.*

> [NAME] measures your frontal area — the surface the wind sees — from one photo against a
> plain wall. It measures the whole loaded bike, not just your body, so you can see what your
> bags, bars, and position each cost. It doesn't predict CdA, run CFD, or model airflow — only
> what a photo can honestly measure, and it tells you when a difference is too small to trust.

### 4. Noise floor section

Eyebrow (mono, accent):

> THE MEASUREMENT FLOOR

Body (two sentences):

> Every reading carries a ±3% margin, and every comparison is judged against it. If two setups
> differ by less than that floor, the app says "indistinguishable" — not "1.8% better."

Small visual (mono numerals; the one place the accent, and amber for the verdict, are
allowed to land):

> ```
> fork bags OFF → ON     difference   1.8 %
> measurement floor      ±            4.2 %
> ─────────────────────────────────────────
> verdict                INDISTINGUISHABLE
> ```

Caption under the visual (mono, dim — one line, earns its place):

> A difference smaller than the noise isn't a result. It's noise.

> **🖼 Image — real comparison screen.** A screenshot of the app's actual compare view showing
> the amber "INDISTINGUISHABLE" verdict. Real UI beats the ASCII mock above for the built page;
> keep the mock only as fallback if the screenshot isn't clean yet.

### 5. Price block

Mono numerals throughout.

> ## [PRICE]
> one-time · no subscription
>
> - no account
> - no cloud
> - no analytics — including on this site
> - everything runs on your phone

Small line beneath:

> In this market, that list is the feature list.

### 6. App Store button

> **Download on the App Store** → `[APP_STORE_URL]`

*One CTA. Top-right of the page and here — twice maximum, never more (spec).*

### 7. Methodology link

> **Read exactly how we measure — and what we don't claim.** → `[METHODOLOGY_URL]`

### 8. Footer

> Built by two dads with day jobs, in Wellington, New Zealand.
> [CONTACT_EMAIL] · Press kit → `[PRESS_KIT_URL]`
> © 2026 [NAME]. Everything on-device. No accounts, no analytics.

*Grace-note only — the place adds indie/underdog texture (bootstrapped, far from the aero
industry) without becoming the pitch. Keep it to the footer here; the honesty is still the
positioning. For NZ media + Kiwi riders, the lens goes loud — "two Wellington dads" up front.*

---

# Page 2 — Methodology (`/methodology`)

Dense is correct — and length is fine *here*, because it's opt-in. Layer 1 reads
end-to-end in ~5 minutes; the technical depth hides in styled `<details>` disclosures the
skeptic can open and the casual reader can skip. The `<summary>` labels are written with a
bit of voice (they're the one place the site lets itself grin), but every disclosure pays
off with real substance — rule unchanged: **every number in Layer 1 is defensible in
Layer 2.** A few short "just for fun" disclosures (marked 🙂) sit at the end — honest
answers to the questions people actually ask.

> **🖼 Image — the three-step triptych.** Under section 2, a row of three real captures:
> **Isolate** (photo → silhouette matte), **Scale** (the two handlebar taps + wheel tap
> marked), **Project** (the filled silhouette with its cm² number). One glance = the whole
> method. Reuse frames from the hero shoot.

### 1. Opening statement

> # How the number is made
>
> Here is exactly what we measure, how we measure it, and what we are not claiming. If a
> figure on this page can't be explained in two sentences, it isn't in the app. That rule
> is the reason [NAME] exists.

### 2. What we measure — and how

**Layer 1:**

> We measure the **frontal area** of the whole system — you, your bike, and everything
> strapped to it — in square centimetres. That's the size of the silhouette you present to
> the wind, and it's the single biggest thing you control that affects how hard you push
> through the air. Because we measure the whole rig, "does this bag actually cost me
> anything?" is a question you can answer: shoot with the fork bags, shoot without, compare.
>
> The process is three steps. First we **isolate** the system — you, the bike, the bags —
> from the background, and throw the background away; only the silhouette survives. Then
> we **scale** it, turning pixels into real centimetres using a ruler that's already in
> the photo (next section). Then we **project**: we sum the lit silhouette into one figure
> — frontal area, in cm².

**▸ Show me the pixels** *(disclosure summary)*

> Isolation is a per-pixel segmentation of the rider-plus-bike-plus-bags system against the
> background. We count the foreground pixels directly from the mask, thresholding at the
> mask's mid-value and striding row by row so that buffer row-padding is never miscounted
> as body. Frontal area is then `foreground_pixels ÷ (mask_pixels_per_cm)²` — a direct
> pixel-to-area conversion once the scale is known. No 3D reconstruction, no volume
> estimate: it is the flat projected area the camera sees, and we call it exactly that.

### 3. The scale chain

**Layer 1:**

> A photo is just pixels until something in it has a known real-world size. Your bike is full
> of known sizes. The primary one is your **handlebar width** — a number you enter once. You
> tap the two bar ends in the photo, we measure that span in pixels, and that gives us
> pixels-per-centimetre for the whole frame. No depth sensor. No camera calibration. Just a
> ruler you already own, held up in the same plane as the rest of you.
>
> Then we check our own work against a second ruler. Tap your **wheel** — its diameter is
> another dimension we can compute from your rim and tyre — and we work the scale out a second
> way, independently. If the two rulers agree, you can trust the number. If they disagree by
> more than 10%, something was mis-tapped or mis-entered, and we say so rather than hand you a
> confident wrong answer. (We also record your **wheelbase** as a reference for side-on shots.)

**▸ Show your working** *(disclosure summary)*

> **🖼 Image — the two rulers.** A single photo annotated with both scale references: the
> handlebar-width span (bar end to bar end) and the wheel span (ground contact to tyre top),
> each labelled. Makes "triangulation" concrete in one look.
>
> Taps are recorded in normalised image coordinates, converted to pixels against the source
> dimensions, and the bar span is their Euclidean distance. Scale is
> `bar_pixels ÷ (bar_width_mm ÷ 10)` → source pixels-per-cm, then rescaled into the
> segmentation mask's pixel space by the width ratio (valid because Vision's person mask
> preserves the source aspect ratio — we check that it does, to a 2% tolerance, rather than
> assume it).
>
> **Triangulation, not a single point of failure.** The wheel ruler is a genuinely independent
> scale: front-wheel overall diameter = rim bead-seat diameter + 2 × tyre width, tapped ground
> contact to tyre top. We compare it to the bar ruler as a relative disagreement against the
> bar (the bar stays authoritative — we never silently swap one scale for the other), and flag
> anything over 10%. Wheelbase is recorded as a candidate side-on reference; today it is stored
> metadata, not yet an active cross-check, so we don't claim it triangulates until it does.
>
> **One known bias, stated plainly.** The handlebars sit slightly forward of your torso, so
> the ruler is marginally closer to the camera than the body it's measuring. That makes the
> absolute area read a touch low. It is consistent shot to shot, so it very largely cancels
> when you compare two positions photographed the same way — which is what the app is for.

### 4. What we deliberately don't do

*No Layer 2 here — this section is the brand, and it's plain all the way down.*

> [NAME] does **not**:
>
> - **Predict CdA.** That is a wind-tunnel or a Notio-class sensor's job, at wind-tunnel and
>   sensor prices. We measure area, not a drag coefficient.
> - **Run CFD or model airflow.** No simulation, no streamlines, no pressure field.
> - **Account for yaw or crosswind.** We measure your head-on projection. Real air rarely
>   comes straight on; we don't pretend to know your day's wind.
> - **Promise watts saved.** Area is a proxy for drag, not a wattage. We will never convert
>   a silhouette into a number of watts and hand it to you as fact.
>
> What it **is**: a repeatable proxy for drag, sensitive to your position rather than the
> weather, and comparable shot to shot. That is a smaller claim than most of this category
> makes. It is also one we can defend.

### 5. The measurement floor

**Layer 1:**

> No measurement is exact, and a tool that hides its own error is lying to you. So every
> reading in [NAME] carries a **±3% margin**. When you compare two setups, we combine both
> readings' margins and check whether the difference between them is bigger than that
> combined floor. If it isn't, we tell you the two are **indistinguishable** — not "1.8%
> better." A difference smaller than the noise is not a result; it's noise.
>
> The habit we ask of you: **re-shoot the same position** before you trust a change. If the
> number moves when nothing about your setup did, you've just seen the floor with your own
> eyes.

**▸ The maths behind the shrug** *(disclosure summary)*

> The ±3% is a fixed, deliberately conservative margin applied to every computed area — it
> stands in for the combined jitter of segmentation and scale, the two largest error sources
> in a photo measurement. It is a model, not a per-photo error bar, and we'd rather it erred
> toward caution than toward flattering a difference.
>
> For a comparison of two areas *A* and *B*, the two margins combine in quadrature —
> `√(u_A² + u_B²)`, the standard rule for independent errors, not simple addition. A
> difference `|A − B|` is reported as real only when it exceeds that combined floor; for two
> similar areas the floor works out to roughly ±4% of the reading. Everything below it is
> shown as *indistinguishable*, and the comparison screen states the floor it used, so you're
> never asked to take the verdict on trust.

### 6. Known limitations

**Layer 1:**

> Where the number is weakest, so you know:
>
> - It is a **flat projection.** Two different body shapes can present the same frontal area;
>   area is not the whole aerodynamic story, only the largest controllable part of it.
> - **It can't see airflow.** Two setups with the *same* frontal area can have different real
>   drag — a bag tucked into the low-pressure wake behind you can even make you slightly faster
>   without changing your silhouette at all (this has been measured in the field). Frontal area
>   is the biggest lever a photo can honestly show you; it is not the only one that exists.
> - **Segmentation degrades in poor light** or against a cluttered background. A plain, evenly
>   lit wall is not fussiness — it's the difference between a clean silhouette and a guess.
> - **The scale is only as good as your handlebar width.** Enter it wrong and every centimetre
>   downstream is wrong by the same factor. (This is what the optional wheel cross-check is
>   there to catch.)
> - **Absolute numbers are less trustworthy than comparisons.** The app is built to answer
>   "did this change anything?", not "what is my exact area?" — and it's most honest when used
>   that way.

**▸ Where it gets weird** *(disclosure summary)*

> We run two automatic sanity checks and surface both. If a computed **shoulder width** falls
> outside a plausible human range (30–60 cm), that almost always means the scale was
> mis-tapped or the bar width is wrong, and we say so rather than report a confident wrong
> number. The **wheel cross-check** (section 3) is the second: an independent scale that flags
> a >10% disagreement with the bar ruler. Neither check blocks a measurement; both refuse to
> let a suspicious one pass silently.
>
> Posture angles — torso lean from vertical (0° upright, 90° flat), hip angle, and head drop —
> are computed from detected body landmarks in the same scaled frame, and inherit the same
> scale dependence as the area.

### 6b. Just for fun *(short disclosures — honest answers, lighter register)*

*Styled the same as the technical disclosures, marked 🙂, collapsed by default. They exist
because the site is allowed to breathe here, and because these are the questions people
genuinely ask.*

**🙂 Wait, why is it called Get Tucked?**

> Because "measure your frontal area, informed by a defensible planar projection" doesn't fit
> on an App Store icon, and because we have children and this is the level of humour you get.
> Tucking is what you do to go faster. The name is the only joke the app tells; everything
> after it is straight-faced.

**🙂 Will this make me faster?**

> No. It's a tape measure, not a coach. It tells you what your position and your luggage cost
> in frontal area; making that number smaller is on you. What it will do is stop you from
> believing a change helped when it didn't.

**🙂 Can I measure Fabio's Chest?**

> You can measure anything you can strap to a bike, and yes, we checked. Here's the honest,
> slightly annoying answer: a bag that rides in the shadow your torso already casts adds
> almost nothing to your *frontal* area — it's hiding behind the widest part of you. So a
> big chest-height bar bag can genuinely come back **inside the noise floor**, and the app
> will say "indistinguishable." Read that as scientific permission. (This is a real property
> of projected area, not a bit we invented — which is the only reason it's funny.)

### 7. Citations

*Real links, filled at build. These are the sources behind "frontal area is a defensible proxy
for aerodynamic drag." Layer-2 owner to confirm each URL/DOI before publish.*

> - Defraeye, T. et al. — cyclist aerodynamics, position and frontal area. `[link]`
> - Crouch, T. N. et al. — cyclist aerodynamics review; frontal area and drag. `[link]`
> - García-López, J. et al. — aerodynamic drag and rider position in the field. `[link]`
> - **Torsten Frank — field aero-test of bikepacking bag setups** (accessible, real-world). 28
>   tests / 107 runs measuring CdA, *with error margins reported* — a good example of the same
>   honesty ethos, and the source for "a bag in your wake can add zero (or negative) drag."
>   Note for readers: he measures **CdA** (full drag), which is precisely what we *don't* —
>   useful precisely because it shows the gap between frontal area and true drag.
>   `[link — torstenfrank.wordpress.com]`
> - Plus one accessible overview article for the non-specialist reader. `[link]`

### 8. Footer CTA

> If you've read this far, you already know whether it's for you.
> **[NAME] · [PRICE] · App Store** → `[APP_STORE_URL]`

---

## Asset shot list (one capture session covers the site + press kit)

All from **one loaded-bike shoot against a plain wall**, real app captures — not mockups.
Ordered by where they're used.

| # | Shot | Used on | Notes |
|---|---|---|---|
| A1 | **Hero reveal** — rider + loaded bike, silhouette matte, pose joints, big cm² number | Landing hero, OG image | Also the animated hero (scan-wipe + count-up). The one image that must be perfect. |
| A2 | **Isolate** — same frame, photo → matte | Methodology triptych | |
| A3 | **Scale** — same frame, both handlebar taps + wheel tap marked | Methodology triptych + "two rulers" image | Doubles as the triangulation image. |
| A4 | **Project** — filled silhouette + cm² | Methodology triptych | |
| A5 | **Comparison screen** — real compare view, amber "INDISTINGUISHABLE" verdict | Landing noise-floor section | Shoot two setups (fork bags on/off) so the verdict is genuine. |
| A6 | **Fabio's Chest** (optional but gold) — big bar bag on/off comparison landing on "indistinguishable" | r/xbiking post, maybe a fun methodology inline | Turns the joke into a real, screenshotted result. |
| A7 | **~90-sec demo video** | Press kit (v2 site embed) | Outreach press-kit dependency. |

Palette for any overlay/annotation: acid-yellow `#D9F020` matte/joints, amber `#E8A020`
only for the "indistinguishable" verdict, Space Mono for every number. Hard edges — 0px, no
device-frame theatre.

---

## Grounding notes (for reviewers — not published)

Where each Layer-1 claim is defended in code, and the two places this copy deliberately
**departs from the outreach/spec drafts** because the drafts overstate the app:

| Copy claim | Grounded in |
|---|---|
| Frontal area = foreground px ÷ mask-px-per-cm² | `AnalysisMath.frontalAreaCm2` |
| Padding-safe pixel count, threshold at mid-value | `AnalysisMath.countForegroundPixels` (threshold 128, `bytesPerRow` stride) |
| Scale = bar_px ÷ (bar_mm/10), rescaled to mask by width ratio | `pixelsPerCm`, `maskPixelsPerCm`, `maskMatchesSourceAspect` (2% tol) |
| Two-ruler triangulation: handlebar + wheel, >10% flag, bar stays authoritative | `wheelPixelsPerCm`, `rulerDisagreementFraction`, `wheelCheckDisagreementThreshold = 0.10` — wired end-to-end in `AnalysisEngine` (l.113) + `CaptureView`/`PositionDetailView` |
| Whole-system area: rider + bike + bags (so bag comparisons are first-class) | `HowItWorksView` step 01 ("you, your bike, and your bags"); segmentation is of the whole foreground system |
| **Wheelbase — NOT claimed as active triangulation** | `Bike.wheelbaseMm` is stored from the form only, never read into a scale calc (`Bike.swift:74` "candidate… never populated"). Copy calls it a recorded side-on reference, not a live cross-check. **Wire it before upgrading the claim.** |
| ±3% per-reading margin | `uncertaintyFraction = 0.03`, `uncertaintyCm2` |
| Combined floor = √(u_A²+u_B²); "indistinguishable" below it | `combinedNoiseCm2`, `isDistinguishable` (used in `ComparisonView`, `LeaderboardView`) |
| Handlebar-forward bias, cancels in comparison | `HowItWorksView` NoiseFloorNote (HANDOFF §2.4) |
| Shoulder-width plausibility 30–60 cm | `isShoulderWidthPlausible`, `shoulderWidthWarning` |
| Posture: torso/hip/head-drop | `torsoAngleDeg`, `hipAngleDeg`, `headDropCm` |
| IT IS / IT ISN'T framing | `HowItWorksView` FactColumn |

**Deliberate departures from the outreach/spec drafts (need a later fix in those files):**

1. **No "camera intrinsics."** The app uses **no intrinsics** — the known-length ruler is
   the entire calibration. Reconciled across all files: `website-spec.md` §3 corrected, and
   the Reddit draft's math line rewritten to "a known handlebar width used as an in-frame
   ruler, so no depth sensor and no camera calibration needed."
2. **No "personal noise floor" / "capture twice" self-test / "median-of-three."** The app
   does **not** measure per-user repeatability — it applies a fixed, conservative ±3% and
   combines in quadrature. Reconciled: this copy, the racer/Reddit/press drafts, and the
   spec all now say "the measurement floor" (fixed ±3%), not "your noise floor," and frame
   re-shooting as a manual sanity-check rather than a measured self-test. If the empirical
   twice-capture feature is later built, the stronger claim can return — until then, every
   file speaks the fixed-±3% truth.
