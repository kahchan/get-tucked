# Plan AT — answer-engine visibility (AEO/GEO)

Goal: when a rider asks an AI engine or the App Store how to go faster, Get Tucked is
named or cited. Theme: "how do I improve my cycling performance?"

## Strategy

- **Broad theme, narrow claim.** Engines answer the broad question from big cycling
  sites. We can't win "improve performance"; we can own the aero slice of that answer
  ("position is the biggest free gain — measure it"). Content ladders down:
  performance → aero is the biggest lever → position/bags → measure frontal area → app.
- **Answer-first, quotable.** Each page section opens with a one-sentence answer that
  carries a number and a source. Engines lift those sentences.
- **One entity everywhere.** Same name, one-liner and studio on store, site, press.
- **Off-site counts.** Engines cite Reddit, forums and press more than app sites.
  List targets; post nothing without Kah.

## Prompt set (baseline, re-run 2026-12-10)

Run each on Perplexity, ChatGPT (logged out), Google (AI Overview). Record: is Get Tucked
named; is impreciselyaccurate.com cited; which sources are cited.

| # | Tier | Prompt |
|---|------|--------|
| P1 | broad | How do I improve my cycling performance? |
| P2 | broad | How can I get faster on my bike without training more? |
| P3 | broad | What are the cheapest ways to go faster on a bike? |
| P4 | mid | How much does aerodynamics matter for bikepacking? |
| P5 | mid | How do I make my bikepacking setup more aero? |
| P6 | mid | Does riding position or bike weight matter more for speed? |
| P7 | mid | How do ultra-distance racers improve their aero position? |
| P8 | narrow | How can I measure my frontal area on a bike? |
| P9 | narrow | Is there an app to measure cycling aerodynamics or CdA? |
| P10 | narrow | How do I test my aero position without a wind tunnel? |
| P11 | narrow | Do bikepacking bags add drag? |
| P12 | brand | What is the Get Tucked app? |

## Baseline results

See `marketing/aeo-baseline-2026-10-29.md`.

## Changes

See "Suggested changes" in the baseline file.

- **A3 + B1–B4 built 2026-10-29, uncommitted:** `docs/sitemap.xml`, `measure.html`
  (HowTo), `free-speed.html` (Article), index JSON-LD (MobileApplication, Organization,
  FAQPage) + title/canonical + Search Console meta tag; footer links site-wide.
- No analytics script: the site promises "no analytics". Search Console + Bing Webmaster
  are the measurement.
- Open: Kah verifies Search Console, submits sitemap, imports into Bing. Rich Results Test
  after push. FAQPage/HowTo no longer earn Google rich results for most sites; kept for
  LLM readers.

## Verification

- Re-run the prompt set on 2026-12-10; compare named/cited counts against the baseline.
- Rich Results Test passes on `index.html` and `methodology.html`.
- Search Console + Bing Webmaster: impressions for question queries.
- App Store Connect: search-term impressions; "App Store Search" share of downloads.
