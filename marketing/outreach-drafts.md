# Get Tucked — Launch Outreach Drafts

**Sequencing:** landing page + methodology URL → racer seeding (TestFlight) → Reddit launch
post → press pitch. The press pitch depends on the Reddit reception and racer names — do
not send it early with those lines cut.

**Prerequisite:** the methodology page must exist as a public URL, not just an in-app
screen. It is the most-clicked link in every draft below.

---

## 1. Racer outreach (pre-launch, TestFlight)

Send to ~12 riders who actually post about setup/gear. Personalise the first line per
person or don't send it. Should read like one rider emailing another — over-polish hurts.

**Subject:** Built a frontal-area measurement app — want early access?

Hi [name] — followed your [Tour Divide / AMR] ride last year. [One specific, true
sentence — a setup choice they made, a scratch, a result.]

A mate and I built an iPhone app that measures the frontal area of you *and* your loaded
bike from photos — so it's not just body position, it's the fork bags, the seatpack, the
bar roll, all of it. You shoot against a plain wall, it segments the whole rig, gives you
cm² and posture angles, and compares setups: frame bag on vs off, hoods vs drops, aero bars
vs not. It scales the photo off your handlebar width and double-checks that against your
wheel size, so a mis-tap gets caught instead of quietly poisoning the number. It doesn't
predict CdA and doesn't pretend to; it measures what a photo can honestly measure. Every
reading carries a ±3% margin, and when two setups land inside it, the app just says
"indistinguishable" instead of inventing a decimal to make you feel productive.

It's called Get Tucked. (Yes, on purpose. Our kids think it's the funniest thing we've ever
done, which tells you where the bar is.) We're two dads building it around day jobs,
launching at USD $20, no subscription. Would love to get it on your phone before launch —
no obligation to say anything about it, ever. If it's useful, use it. If you happen to
mention it, we won't complain.

TestFlight link: [link]

Kah

> Note: the "no obligation" line is load-bearing — it's the difference between seeding and
> asking for a shill.

---

## 2. Reddit launch post

Post to r/bikepacking; adapt for r/ultracycling and r/xbiking. One shot per subreddit.
Block out the evening it goes up — the comment replies are the actual marketing.

**Title:**

I built an app that measures your frontal area from photos — and tells you when the
difference is too small to trust

**Body:**

Two of us (both dads with day jobs, both just cycling fans) spent [X months] building an
iPhone app called Get Tucked. Yes, that's the name. We have children; this is the level of
humour you get. You photograph your position against a plain background and it extracts the
whole silhouette — you *and* the loaded bike — then gives you frontal area in cm² plus
posture angles. So it's not only "am I tucked?", it's "what are these fork bags actually
costing me?" Then you compare setups: bags on vs off, hoods vs drops, layered up vs
stripped down.

What it deliberately doesn't do: predict CdA, run CFD, or model airflow. Wind tunnels and
Notio-class sensors do that, at wind-tunnel and Notio prices. This measures what a
calibrated photo can honestly tell you — a planar projection of your frontal area — which
is enough to answer "did moving my fork bags actually change anything?"

The feature I'm proudest of is the boring one: honesty about error. Every reading carries a
±3% margin. When you compare two setups, the app combines both margins and checks whether
the difference actually clears that floor. If it doesn't, it says "indistinguishable" — not
"1.4% better." A difference smaller than the noise isn't a result, it's noise, and I've
never seen a consumer measurement tool willing to say so out loud. It also nudges you to
re-shoot the same position, so you can watch the floor move with your own eyes before you
trust a change.

Everything runs on-device. Photos stay in your library, no account, no cloud, no
analytics. USD $20 one-time, no subscription.

[App Store link] · [Methodology page link]

Happy to answer anything about how the measurement works — the math has some genuinely fun
problems in it: scale from a known handlebar width used as an in-frame ruler (no depth
sensor, no camera calibration), then triangulated against your wheel size as a second
independent ruler so a bad tap gets caught; when the difference between two setups actually
beats the noise floor; and when a segmentation mask is trustworthy enough to count.

> **r/xbiking variant.** Same body, dumber energy — that crowd will meet an honesty pitch
> with a shrug and a bigger bag. Lean in. Suggested line to work into the body or drop as
> the first comment: *"We finally measured Fabio's Chest. Turns out a bag that rides in
> your torso's shadow barely adds any frontal area — the delta came in under the noise
> floor and the app called it indistinguishable, which we are choosing to read as
> scientific permission to run the big bag. Aero is a lifestyle, not a penalty."* The line
> is load-bearing on being *true*: an object inside your existing frontal silhouette really
> does add almost nothing to projected area, so this isn't a bit we're inventing — it's the
> honest result, which is exactly why it's funny. (Do not quote a specific cm² we haven't
> actually shot.)

---

## 3. Press pitch (bikepacking.com, Escape Collective, The Radavist)

Send after the Reddit post has reception to point at. Journalists skim — everything above
the fold, links do the heavy lifting.

**Subject:** Two dads built a $20 aero measurement app that refuses to overstate its own
accuracy

Hi [name],

Quick pitch: Get Tucked is an iPhone app that measures the frontal area of a rider *and
their loaded bike* from photos — silhouette extraction, cm², posture angles, side-by-side
comparison of setups. Because it measures the whole rig, not just the body, it answers the
question this audience actually argues about: what does a set of fork bags, or a bar roll,
or a different seatpack, actually cost you? It's aimed at riders tuning luggage and position
across a season, not TT racers chasing watts. (The name is a joke our children are far
prouder of than we are. It stuck.)

The angle I think is interesting for [outlet]: it's a measurement tool that's honest about
its limits in a category full of aero snake oil. No CdA prediction, no CFD claims. It scales
each photo off two independent rulers already on the bike — handlebar width, cross-checked
against wheel size — so a mis-measurement gets caught rather than quietly reported. And every
reading carries a fixed ±3% margin: the app refuses to report a difference smaller than that
floor, telling you two setups are "indistinguishable" rather than inventing a decimal to
justify the purchase. The full methodology, including a plain list of what it can't do, is a
screen inside the app and a page on the site: [methodology link].

It landed well with the community — the r/bikepacking launch post is here [link], and
riders including [names, if any bit] have been using it since the beta.

We're a two-person team (both full-time-employed dads, building this from New Zealand), $20
one-time, everything on-device, no accounts or analytics. Happy to send promo codes, a press kit [link], or get
on a call. Also happy to be technically grilled on the measurement math — that's the fun
part.

Kah [+ surname, links]

> Credibility load-bearing lines: the Reddit reception link and the racer names. If neither
> exists yet, wait.

### Media / press target list

Pitch order: outlets whose audience *is* this rider, warmest first. Personalise the "[outlet]"
angle line per publication — a Radavist pitch is not an Escape Collective pitch.

| Outlet | Why them / angle | Fit | Notes |
|---|---|---|---|
| **The Radavist** | Rider-culture, characterful rigs, anti-hype. The "honest tool in a snake-oil category" + Fabio's-Chest energy is *made* for their voice. | **Strong** | You flagged this as a definite. Lead with culture/story, not specs. |
| **BIKEPACKING.com** | The core audience; they do rig breakdowns and gear deep-dives all season. Methodology page is catnip for their readers. | **Strong** | Their "Rigs of…" coverage is proof they care about exactly this. |
| **Escape Collective** | Member-funded, allergic to marketing spin, loves technically honest stories. Our "refuses to overstate its accuracy" angle is their whole ethos. | **Strong** | Pitch the honesty/measurement-integrity angle hard; expect real scrutiny (good). |
| **DotWatcher.cc** | Ultra-racing hub; the racers we're seeding are their coverage subjects. | Good | Better once we have racer names using it — pitch after seeding lands. |
| **Velo (Outside)** | Ran Joe Nation's "bikepacking aero hack" piece — already interested in loaded-bike aero. | Good | Natural follow-on if Joe engages. |
| **NZ Cycling Journal** ⭐ | **Local angle.** Two Wellington dads + a homegrown app + Kiwi racers (Joe, Matt) = a clean NZ story they'd likely run. | **Strong (local)** | Easiest first "win" for a reception link; lower barrier than the big internationals. |
| **The Gravel Ride / Detours (podcasts)** | Long-form, love measurement/setup nerdery; Kah is happy to be "technically grilled." | Good | A pod appearance doubles as demo + press kit content. |

Press-kit link goes in every pitch. Don't send the big three (Radavist, BIKEPACKING, Escape)
until there's a Reddit reception link and ≥1 named rider using it (see credibility note above).
NZ Cycling Journal is the exception — a good candidate to go *first* and generate that first link.

---

## Notes across all three

- **"Two dads with day jobs"** appears in all three deliberately — best narrative asset
  with this audience, inoculates against the "another VC aero-gadget" reflex.
- **The NZ lens — layer it, calibrated by audience.** "Two dads *in New Zealand*" stacks well
  on the day-jobs line (bootstrapped, far from the aero industry, indie underdog), but it's a
  *texture*, not the pitch — the honesty is still the positioning.
  - **Loud for local:** NZ Cycling Journal and the Kiwi racers (Joe, Matt) → lead with **"two
    Wellington dads"** and the shared scene (Tour Te Waipounamu, the brevets). Genuine common
    ground, warmest possible cold-open.
  - **Light for global:** r/bikepacking, US press → keep "two dads with day jobs" as the
    headline; a single "…building this from New Zealand" is plenty. Don't oversell Kiwi-made to
    a global crowd for whom it isn't a credibility signal.
  - Optional grace-note joke, once, where it fits (footer / press bio): *"about as far from a
    wind tunnel as you can get"* — ties the place to the honest-limits positioning.
- **Press kit contents needed before pitch:** screenshots, methodology screen, ~90-second
  demo video, promo codes.
- **Fill-in slots to resolve before sending:** [X months], App Store link, methodology
  URL, TestFlight link, press kit link, racer names.
