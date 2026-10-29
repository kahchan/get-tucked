# AEO baseline — 2026-10-29

Prompt set: `plans/plan-at-answer-engine-visibility.md`. Engines: Google (AI Overview,
signed out, `hl=en`, from NZ), ChatGPT (signed out, search on). Perplexity now needs a
sign-in — not run.

## Results

| # | Prompt (short) | Google: GT named? | Google AI Overview / top sources | ChatGPT |
|---|---|---|---|---|
| P1 | improve cycling performance | no | training, nutrition, strength; aero is section 3 of 4. NIH, Lucca CC, Bauerfeind, Cycling UK | answer did not load; not scored |
| P2 | faster without training more | no | **aero first**: "position saves up to 26 W". YouTube, BikeRadar, CycleCoach | — |
| P3 | cheapest ways to go faster | no | **aero first**, same 26 W claim. Bicycling, BikeRadar, Canyon | — |
| P4 | aero matters for bikepacking? | no | 70–90% of effort is air. Tailfin, CyclingAbout, Cyclite | — |
| P5 | bikepacking setup more aero | no | opens with "**reduce your frontal area**". Tailfin, CyclingAbout, Cyclite, Torsten Frank, Apidura | — |
| P6 | position vs weight | no | position wins, 20–40 W. RoadBikeRider, StackExchange, CyclingAbout | — |
| P7 | ultra racers aero position | no | Roadman, Torsten Frank, Canyon, TrainRight | — |
| P8 | measure my frontal area | **organic only** | AI Overview describes **our exact method** (head-on photo, bar width as scale, pixel count) citing TrainerRoad, Sci-Sport, PubMed (Debraux 2009). Our r/bikepacking post ranks #2 organic, 31 min after posting | no; describes the photo method, cites PubMed |
| P9 | app for aero / CdA | no | MyWindsock, AeroX, FramIQ, Notio, Cycling Weekly, Slowtwitch | no; lists AeroDial, aero.chat, AeroX, AeroProfile, myCdA |
| P10 | test aero without wind tunnel | no | Chung method, roll-down. Rule 28, Roadman, Silca | — |
| P11 | bikepacking bags drag | no | bags add 6–8%. CyclingAbout, Tailfin, Cyclite | — |
| P12 | what is Get Tucked app | no | **"tuck." UK cashback app** owns the query | "couldn't find a cycling app called Get Tucked" |

Index check: Google has 5 pages (`site:impreciselyaccurate.com`). **Bing has none** —
and ChatGPT and Copilot search run on Bing. No `sitemap.xml`, no JSON-LD on any page.

## What the baseline says

1. **ChatGPT cannot see us at all**, even by name. Cause: not in Bing. This is the
   biggest and cheapest fix.
2. **The broad theme works through "free speed", not "performance".** P1 answers lead
   with training. P2/P3 lead with aero position. So target "get faster without training"
   and "cheapest speed", not "improve performance".
3. **P8 is ours to take.** Google's answer to "how do I measure frontal area" describes
   the Get Tucked method step for step, citing a 2009 paper and TrainerRoad. We have no
   page that answers that question in those words.
4. **Reddit gets indexed in minutes and ranks.** One post beat every app site for P8.
   Off-site is half the job.
5. **The name collides.** "Get Tucked app" returns a cashback app. Always pair the name
   with "cycling" / "frontal area".
6. **CyclingAbout is the authority** on bikepacking aero (cited in P4, P5, P6, P7, P11).
   Torsten Frank is cited twice.

## Suggested changes (ranked)

### A. Indexing — Kah, ~30 min, no code
1. Verify the domain in Google Search Console (Google showed "Try Search Console", so
   it is likely not verified).
2. Bing Webmaster Tools → import from Search Console → submit sitemap. This is what
   puts us into ChatGPT and Copilot.
3. I add `docs/sitemap.xml`. Also check `https://impreciselyaccurate.com/robots.txt`
   (root repo) does not block anything.

### B. Site — I build
1. **New page: "How to measure your frontal area from a photo"** (`measure.html`).
   Answer-first: the Debraux photo method in 5 steps, with handlebar width as the scale,
   the ±3% floor, and when a difference is noise. Then "or let the app do the pixel
   count". Cites Debraux 2009. Target: P8, P10.
2. **New page: "Free speed: the aero ladder"** (`free-speed.html`). Answer-first for
   P2/P3/P5/P6: position → clothing → bags → equipment, each with a cited watt or %
   range (CyclingAbout, Debraux, Tailfin data), ending at "measure before and after".
   Every number has a source, per §3.
3. **JSON-LD:** `MobileApplication` (name, iOS, price, App Store URL) + `Organization`
   (Imprecisely Accurate Instruments, `sameAs` App Store) on `index.html`; `FAQPage`
   on the index FAQ; `HowTo` on `measure.html`.
4. **Disambiguate:** `<title>` → "Get Tucked · Cycling frontal area app". First body
   sentence names "cyclists" and "frontal area".
5. **Optional:** honest comparison section, "Get Tucked vs CdA apps": we measure A
   outdoors with the whole loaded bike, no trainer or power meter; we do not measure
   CdA. Names AeroX, MyWindsock, Chung method by category, not by claim.
6. Skip `llms.txt` for now: no engine has confirmed it reads it.

### C. App Store — next version
1. **Name** → `Get Tucked: Cycling Aero` (24/30). Fixes the cashback collision in store
   search. Name and subtitle need a new version.
2. **Subtitle** → `Measure frontal area by photo` (29/30).
3. **Keywords** → drop words now in name/subtitle (`cycling`), add `aerodynamics`,
   `aero`, `wind tunnel`. Draft:
   `bikepacking,bike fit,drag,cda,aerodynamic,tuck,bags,gravel,touring,time trial,ultra,triathlon,wind`
   — count to 100 before paste.
4. **Promo text** (no new version needed): lead with the question riders ask —
   "Want free speed? Measure your frontal area from one photo…".

### D. Off-site — Kah posts, I draft
1. Reply to the threads that rank for P8–P10: timetriallingforum "Measuring your
   frontal area by camera", Slowtwitch CdA app threads, r/bikepacking and r/cycling
   aero questions. Disclose you made it.
2. Pitch CyclingAbout (Alee Denham) — the most-cited source in this space.
3. Ask to be added to the "CdA apps" round-ups that rank for P9 (Cycling Weekly,
   Roadman, FramIQ's list is a competitor — skip).

## Re-run

2026-12-10, same prompts, same engines, signed out. Add Perplexity if signed in.
