# Get Tucked — Public Website Spec

**Status:** `specced` · v0.2
Companion to the design spec (visual direction) and outreach drafts (the site is the link
target for all three).

> **v0.2 change:** the *Visual system* section now maps to the real, current app design
> tokens (`ios/GetTucked/Design/Theme.swift`), so the site reads as a genuine sibling of
> the app rather than an approximation. Deliberate editorial divergences from the app are
> called out inline.

---

## Purpose

Two jobs, two pages, different standards:

1. **Landing page** — convert a click from Reddit / press / word of mouth into an App Store
   tap. Small, direct, almost brutally simple.
2. **Methodology page** — carry the credibility strategy. The most-clicked link in every
   outreach draft. Written for someone who *hasn't bought the app*: skeptical coaches,
   journalists, $20-hesitant buyers. This page justifies the price.

Nothing else in v1. No blog, no press page (press kit is a linked zip/folder), no
changelog, no mailing list.

---

## Locked decisions

| Decision | Call |
|---|---|
| Design language | App palette, warmer/more editorial in tone than the app UI |
| Methodology depth | Two layers: plain language, with expandable technical detail |
| Colour mode | Dark only |
| Tech | Static HTML/CSS, GitHub Pages, custom domain. No framework, no build step beyond what's needed. |
| Pages | `/` (landing) and `/methodology`. That's it. |

---

## Visual system

Inherits the app's direction (design spec: restrained greys, one accent, mono numerals,
instrument feel) but tuned for editorial reading rather than UI chrome. Below, the app
tokens are the *reference*; the site's values are the app values with a deliberate,
documented editorial lift for long-form reading.

### Design tokens — app source of truth → site values

The app's tokens live in [`Theme.swift`](../ios/GetTucked/Design/Theme.swift). The site
should ship these as CSS custom properties on `:root`.

| Role | App token (`Theme.Palette`) | App hex | Site value | Why the site differs |
|---|---|---|---|---|
| Primary canvas | `bg0` | `#080808` | `#121417` | App is near-black instrument chrome; a methodology-length read on pure black strobes. Lift to deep grey. |
| Secondary surface | `bg1` | `#101010` | `#16191D` | Cards / callout blocks / disclosure panels sit one step above canvas. |
| Tertiary surface | `bg2` | `#161616` | `#1C2025` | Code / figure backgrounds, table zebra. |
| Divider / border | `line` | `#262626` | `#2A2E34` | Hairline rules, `<details>` borders, table lines. |
| Subtle divider | `line2` | `#1A1A1A` | `#20242A` | Low-contrast internal separators. |
| Primary text | `fg` | `#EEEEEE` | `#E8E6E1` | Off-white with a hair of warmth — pure white on dark fatigues over a long read. |
| Secondary text | `fg2` | `#999999` | `#A6A29B` | Captions, metadata, methodology asides. |
| Tertiary text | `fg3` | `#777777` | `#8A867F` | Footnotes, citation lines. |
| Dim labels | `fg4` | `#555555` | `#5E5A54` | Eyebrow labels, disabled/quiet UI. |
| **Accent (acid-yellow)** | `acc` | `#D9F020` | `#D9F020` | **Unchanged.** The one accent, carried verbatim from the app for brand continuity. Links, noise-floor callout, one hero highlight — sparingly. |
| Amber (warning) | `amb` | `#E8A020` | `#E8A020` | **Unchanged.** Reserved for "caution / inside the noise floor" emphasis if needed; do not use as a second decorative accent. |

**Accent discipline (unchanged from v0.1):** if the accent appears more than a handful of
times per page, it's overused. Links, the noise-floor callout, one hero highlight — that's
the budget.

### Typography

The app pairs **Space Mono** (numbers, labels, metric rows) with **Barlow Condensed Bold**
(headings only). The site keeps that pairing and adds a prose face the app doesn't need.

| Role | Face | Notes |
|---|---|---|
| Headings | **Barlow Condensed** (700) | Same as app `Theme.FontName.heading`. Condensed display; use for page/section titles. |
| Every figure on the page | **Space Mono** | cm², percentages, prices, tolerances, citation years — *all* numbers read as instrument output, including the price. Matches app `Theme.FontName.mono` / `monoBold`. |
| Body prose | System sans **or** one webfont | Editorial sizes: **18–19px body, 1.6+ line-height, ~65ch measure.** The app has no long-form prose face; the site introduces one. If a webfont is used, self-host it (no third-party CDN — consistent with the no-analytics posture). |

**Optical tracking** (mirror the app's `Theme.Typography`): large display type reads loose
— give hero numbers and the wordmark negative tracking (~-1.5 at 56px+, ~-0.8 for large
headings); body and small labels keep default / slight-positive tracking. Do not let the
site's headings default to loose browser tracking.

**Radius:** `0px` everywhere. The app has a single hard rule — `Theme.Radius.none` — and no
non-zero radius token exists. The site inherits this: no rounded corners on buttons, cards,
images, callouts, or the App Store button. Hard edges are load-bearing brand, not an
oversight.

### Motion (new in v0.2)

The app's motion language is **"hard-edged in form, eased in timing"** (`Theme.Motion`):
shapes stay hard — wipes, scan lines, clipped reveals, count-ups — no springs, bounce,
blur, or overshoot; but every duration runs on an easing curve, nothing linear. The site
should stay almost entirely still (it's a document, not an instrument), but where motion
appears, follow the app:

- **Allowed, sparingly:** a single hero reveal echo (e.g. a clipped/wipe reveal of the
  silhouette overlay, or a one-shot count-up on the hero cm² figure), section entrances
  that fade/decelerate in on scroll.
- **Durations, from the app tokens:** press/fast `0.15s`, base `0.25s`, gentle entrance
  `0.45s`, a hero sweep up to `~0.9s`, count-up `~0.8s`. Use `ease-out` for entrances,
  `ease-in-out` for travel/sweeps. Never linear.
- **Forbidden:** springs, bounce, parallax theatre, blur transitions, anything that reads
  as "web animation library." The app doesn't bounce; neither does the site.
- **`prefers-reduced-motion`:** honour it — collapse the hero reveal to its final state and
  disable scroll entrances. (The app is careful here; the site must be too.)

### The hero reveal (the site's one signature motion)

**Concept: reproduce the app's own reveal moment.** In-app, a measurement resolves as an
acid-yellow **scan line sweeps across the matte** and the number **counts up** (`Theme.Motion`
`sweep 0.90` + `roll 0.80`). The website hero should be that exact moment, on the web — so a
rider who lands from Reddit sees the thing the app does before they've downloaded it.

Sequence, once, on load (or when scrolled into view):

1. **t=0** — the plain original photo is shown (rider + loaded bike against the wall). Nothing
   else yet.
2. **Scan-wipe, ~0.9s, `ease-in-out`** — a 1–2px acid-yellow line travels across the frame
   (left→right or top→bottom). *In its wake*, the silhouette matte and pose joints are
   revealed by a hard clip mask following the line — a **wipe, not a fade**. Hard edge tracks
   the line exactly; nothing blurs or springs.
3. **Count-up, ~0.8s, `ease-out`, overlapping the tail of the sweep** — the Space-Mono cm²
   figure rolls from `0` to its final value. Fixed-width digits so nothing reflows; land on the
   real number, no rounding drama.
4. **Hold.** Final composited state stays. No loop, no idle animation — an instrument that has
   finished measuring sits still.

**Implementation:** pure CSS where possible — the wipe is a `clip-path` inset (or a masked
overlay) animated across the axis; the count-up is the one place a few lines of vanilla JS are
allowed (increment a `textContent`), since the site's JS target is otherwise zero. Keep the JS
inline, tiny, and dependency-free. The hero image is asset **A1** in `website-copy.md`.

**Reduced motion / no-JS:** render the final composited frame (matte + joints + final number)
immediately, no sweep, no count. The hero must be complete and correct with JS disabled — the
animation is enhancement, never the content.

**Restraint:** this is the *only* place the site animates anything of substance. Section
entrances (a quiet fade/decelerate-in on scroll) are the sole exception, and even those are
optional. If in doubt, don't move it.

### Editorial tone shift vs app

The app is a straight-faced instrument; the site can breathe slightly — longer sentences, a
touch of voice — but the same rules hold: **no exclamation marks, no gamification copy, the
name is the only joke.**

### Imagery

Loaded rigs, gravel, bikepacking. Not TT bullets. Real screenshots and real captures from
the app, not device-frame mockup theatre. The hero is a genuine app output (silhouette
overlay + pose joints + mono cm² readout), rendered against the site canvas so it reads as
continuous with the page, not a floating phone.

---

## Page 1: Landing (`/`)

Top to bottom. No feature grid, no testimonial carousel, no FAQ accordion.

1. **Name + tagline.** "Get Tucked" / "Be informed, don't guess." Wordmark in Barlow
   Condensed with hero negative tracking.
2. **Hero visual.** The reveal moment: a rider photo with silhouette overlay, pose joints,
   and a mono cm² readout. This is the whole product in one image. *Asset dependency: needs
   a real capture from the app — flag if not yet available.* If a clipped-reveal or count-up
   is used, it's the one hero motion moment (see Motion above).
3. **Three-sentence description.** Leads with what it does, immediately followed by what it
   deliberately doesn't do (no CdA, no CFD, no airflow modelling). The honesty is the
   positioning; put it above the fold.
4. **Noise floor section.** One paragraph + one small visual (e.g. "1.4% difference / your
   noise floor ±2.1% → *Indistinguishable*"). This is the differentiator; it earns the only
   dedicated feature section on the page. This is where the accent (or amber for the
   "indistinguishable" verdict) is allowed to land.
5. **Price block.** $20 · one-time · no subscription · no account · no cloud · no analytics.
   In this market, that list *is* a feature list. Mono numerals throughout.
6. **App Store button.** One CTA. Not repeated three times down the page — the page is short
   enough that once is fine, twice max (top-right and here). Hard-edged (0px), consistent
   with tokens.
7. **Methodology link.** Prominent, phrased as an invitation to scrutiny: "Read exactly how
   we measure — and what we don't claim."
8. **Footer.** Contact email, press kit link, "two dads with day jobs" one-liner (consistent
   with all outreach), copyright.

---

## Page 2: Methodology (`/methodology`)

The in-app "How this works" screen, expanded for the web. Dense is correct. Structure:

1. **Opening statement.** "Here is exactly what we measure, how we measure it, and what we
   are not claiming." (Mirrors the in-app voice.)
2. **What we measure and how.** Frontal area of the **whole system — rider + bike + bags** —
   from calibrated photos, so bag/luggage comparisons are first-class, not just body position.
   Plain-language walkthrough: photo → segmentation → pixel count → real-world cm².
3. **The scale chain.** Handlebar width (user-entered) → tapped bar endpoints in the photo →
   pixels-to-cm from that known length alone (**no camera intrinsics** — the ruler *is* the
   calibration). **Triangulated against a second independent ruler, wheel size,** with a >10%
   disagreement flag. Wheelbase is recorded as a side-on reference but is **not yet a wired
   cross-check** — don't claim it as one. This is the section technical readers will probe.
4. **What we deliberately don't do.** CdA prediction, CFD, yaw/crosswind, drag modelling.
   Prominent — its own section, not a buried caveat. This section is the brand.
5. **The noise floor.** The self-test method, why repeatability is measured per-user, why
   "indistinguishable" is a result and not a failure.
6. **Known limitations.** Planar projection assumption, segmentation under poor lighting,
   scale-reference dependence on accurate handlebar width, multi-capture spread.
7. **Citations.** Defraeye et al, Crouch et al, García-López et al, plus one or two
   accessible overview articles. Real links.
8. **Footer CTA.** Single quiet App Store link — the reader who finishes this page is sold
   or isn't.

### Two-layer mechanism

- **Layer 1 (default):** plain language, readable end-to-end by a non-technical bikepacker
  in ~5 minutes.
- **Layer 2 (expandable):** `<details>/<summary>` disclosure blocks under sections 2, 3, 5,
  6 containing the technical depth — mask thresholding and padding-safe pixel counting,
  aspect-ratio rescaling into mask space, the fixed ±3% margin and quadrature combination,
  the wheel cross-check, and the sanity checks (shoulder-width plausibility). Note: the app
  uses **no camera intrinsics** and **no median-of-three aggregation** — do not describe
  either (see `website-copy.md` Grounding notes).
- Native `<details>` elements, styled to the tokens (border `line`, surface `bg1`, 0px
  radius, mono for the summary's figures). No JS required. Expanded state should print
  sensibly (`@media print` opens all disclosures).
- Rule: **every number and claim in Layer 1 must be defensible in Layer 2.** Same standard
  as the app: if it can't be explained in two sentences, it doesn't appear.

---

## Tech notes

- Static HTML + CSS. Two files of markup, one stylesheet, assets folder. No React, no build
  framework — this doesn't need one.
- **Design tokens as CSS custom properties** on `:root`, mirroring the table above, so the
  two pages share one source of truth (same discipline as `Theme.swift`).
- Self-host any webfont (Barlow Condensed, Space Mono, prose face) — no third-party CDN,
  consistent with the no-analytics / on-device posture.
- GitHub Pages with a custom domain, HTTPS via Pages defaults.
- OpenGraph/Twitter meta on both pages — these URLs will be pasted into Reddit and press
  emails; the preview card matters. OG image = the hero visual.
- Basic, honest `<title>`/meta description. No SEO theatre; discovery comes from outreach,
  not search, in v1.
- No analytics. Consistent with the app's posture, and it's a marketing line ("no analytics
  — including on our own site"). If curiosity wins later, a privacy-respecting counter (e.g.
  GoatCounter) is a v1.x decision, not v1.

---

## Build order

1. Copy first, in markdown — both pages, reviewed and locked before any HTML.
2. Methodology page built and reviewed first (it's the hard one and the outreach
   prerequisite).
3. Landing page.
4. Domain + Pages setup, OG cards, print check on methodology.

Copy is the actual work. The build is half a day once copy is locked.

---

## Out of scope for v1

- Blog, changelog, mailing list, FAQ
- Light mode
- Press page (kit is a linked folder)
- Localisation
- Any JS beyond zero (target: none)

## Extension points

| Version | Feature |
|---|---|
| v1.x | Privacy-respecting visit counter, if wanted |
| v1.x | Press hits strip on landing ("as seen on…") once coverage exists |
| v2 | Demo video embed (90-sec press kit video, self-hosted or unlisted) |
| Later | TT/road landing variant if that audience is pursued |

## Open questions

- **Domain.** Not decided. `gettucked.app` vs alternatives; also needs the "Tuck" fallback
  thought through — if Apple rejects the name, does the domain survive? Decide before
  outreach drafts get URLs.
- **Hero asset.** Needs a real capture with silhouette + readout. If the app can't produce a
  clean one yet, this gates the landing page.
- **Who writes the technical Layer 2 copy** — needs whoever owns the measurement math to
  review every sentence.
- **Prose webfont vs system stack** — the app has no prose face, so this is a net-new
  choice. System sans ships zero bytes and zero third-party requests; a self-hosted
  editorial serif/sans buys warmth. Decide before landing-page build.
