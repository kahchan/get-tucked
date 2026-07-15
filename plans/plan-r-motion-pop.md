# Plan R — Motion Pop (the outline draw-in, and fluidity where fingers touch)

Status: **planned** (2026-07-15). No code yet. Trigger: Kah's read that the app isn't
"getting much pop" — specifically wanting a staggered draw-in for the two silhouette
outlines on the comparison screen — with a directive to plan **against the `apple-design`
skill** (Apple's *Designing Fluid Interfaces* corpus, distilled).

**Read first:** `CLAUDE.md`, `plans/plan-n-motion-and-experience-polish.md` (the motion
philosophy this plan *amends* — see the translation table below),
`ios/GetTucked/Design/MotionViews.swift` (existing primitives: `RollingNumberText`,
`scanReveal`, `cascadeIn`), `ios/GetTucked/Design/SkeletonOverlay.swift` (the app's one
existing true draw-on — `Path.trim` driven by a `progress` var, callers own the
animation), `ios/GetTucked/Views/ComparisonView.swift` (`GhostCompareOverlay` — R1's
subject). The `apple-design` skill sections are cited as **§n** throughout.

**Scope:** presentation only. No analysis, schema, or flow changes. Every displayed
number is untouched.

---

## Translating the skill into this brand (read before writing any animation)

The skill and the design language agree on more than it first appears, but an
implementing agent must know which skill guidance is **adopted**, which is **already
satisfied**, and which is **deliberately rejected** here:

| Skill guidance | Verdict for Get Tucked |
|---|---|
| Springs as the default solver, **damping 1.0 = critically damped, no overshoot** (§4) | **Adopt — this amends Plan N.** N's "no springs" banned the *springy look* (overshoot/bounce). A critically damped spring has none; it is visually a clean settle but is interruptible and velocity-aware. Use it for **interactive** motion (things a finger can re-trigger mid-flight). Scripted, one-shot ceremonies keep N's eased curves. |
| Bounce when momentum precedes (§4, damping ~0.8) | **Rejected.** The brand is hard-edged; damping stays 1.0 *everywhere*. This is a stricter subset of the skill, not a violation of it. |
| Interruptibility; never lock input; animate from the presentation value (§3) | **Adopt.** RevealStep's tap-to-snap ceremony already models this; R1 must match it. Springs give the rest for free (SwiftUI springs re-target from the live value). |
| Velocity handoff at gesture end (§5), rubber-band at boundaries (§9) | **Adopt** — R3. The current pinch-zoom hard-clamps and eases on a fixed duration: the most un-Apple seam in the app. |
| Respond on touch-*down* (§1) | Partially satisfied (N8 covered buttons). **R4 audits the gaps** — plain-style rows currently give no press feedback at all. |
| Stagger/hinting — intermediate motion telegraphs the outcome (§8) | **Adopt** — R1's A-then-B overlap is exactly this. |
| Haptic causality / harmony / utility (§13) | **Adopt utility hardest:** this plan adds at most one haptic, and removes none. Over-feedback trains people to ignore all of it. |
| Reduced motion = gentler equivalent, not nothing (§14) | Already house style (`cascadeIn`, `RollingNumberText`, ceremonies). Every new animation degrades the same way. |
| Translucent materials, blur, vibrancy (§12); motion blur (§11) | **Rejected.** Opaque near-black surfaces and hard edges are the design language. No `Material`, no blur, anywhere. |

Concretely, add one token to `Theme.Motion` and update its header comment:

```swift
/// Interactive motion: critically damped spring — no overshoot (the brand
/// ban is on bounce, not on springs; damping 1.0 keeps the hard-edged look
/// while making the motion interruptible and velocity-aware, skill §3/§4).
/// Scripted one-shot ceremonies (reveals, cascades) keep the eased curves.
static func interactive(_ response: Double = 0.35) -> Animation {
    .spring(response: response, dampingFraction: 1.0)
}
```

Amend the "no springs/bounce/blur/overshoot" line in the header comment to "no
*overshoot/bounce/blur* — critically damped springs are the solver for interactive
motion" so Plan N's file-level philosophy and this token can't be read as contradicting.

---

## R1 — The outline draw-in (the hero increment)

**Goal:** entering the comparison screen in OUTLINE mode, position A's ring **draws
itself around the rider** in acid, B follows in amber, staggered but overlapping. The
two-silhouette overlay is the app's most argument-settling visual; today it just pops
into existence.

### R1.1 Contour tracing — raster ring → vector path

Today's outline is a raster ring (`MatteRenderer.outlineMask` → tinted `UIImage`). A
raster can wipe in, but it cannot *draw*. Drawing needs the mask boundary as a path:

- Add `MatteRenderer.contourPaths(mask: CGImage) -> [CGPath]` (unit-space, 0–1
  coordinates): marching-squares boundary trace over the stored mask (already
  downscaled at save time, so this is cheap), discard contours enclosing less than
  ~0.5% of the foreground area (specks), simplify with Douglas–Peucker at ~1px
  tolerance. **Rotate each contour's point order so index 0 is its topmost point** —
  the draw then starts at the helmet and wraps down around the rider, which reads as
  tracing *them*, not scribbling.
- Pure geometry, off-main capable, and **unit-tested** (new `ContourTracerTests`):
  a synthetic square mask → 4-ish points after simplification; a donut → two
  contours; two blobs → two contours; all-empty → `[]`.
- **Display-only.** These paths feed no area computation, ever — state this in a
  comment at the declaration. The number pipeline is untouched (spec §3).

Build the paths in `buildGhostCompareLayer`'s existing detached task and carry them on
`GhostCompareLayer` alongside (not replacing) `outlineImage`.

### R1.2 Rendering the draw

In `GhostCompareOverlay`'s OUTLINE mode, when a layer has contour paths, render them as
SwiftUI `Path`s scaled into the existing `overlayPlacement` rect —
`.trim(from: 0, to: progress)` per contour (all of a layer's contours share one
progress; no per-contour ceremony), stroked ~2pt screen-space in the layer's tint at
the raster ring's 0.85 opacity. `SkeletonOverlay` is the in-repo reference for the
whole pattern (trim + progress + caller-owned `withAnimation`).

The raster `outlineImage` remains the **settled/fallback** representation: when
tracing returns `[]` (fragmented matte, degenerate mask), that layer keeps today's
raster ring and its entrance falls back to a `scanReveal` wipe — the stagger story
survives even when the draw can't (same graceful-degrade shape as every optional
visual in this app).

### R1.3 The choreography

- A draws over `Theme.Motion.sweep` (0.9s, `travel` easing — this is a scripted
  ceremony, not interactive motion; eased curve per the translation table).
- **B starts at ~0.35s** — overlapping, not sequential (§8: the overlap hints "these
  are a pair being laid over each other"; a full A-then-B serial read would double the
  wait and feel like a slideshow). Total ceremony ≈ 1.25s.
- **Causality beat (§13):** each `LayerToggleChip` sits at `fg4`/`line` (its off
  state) until its layer's draw completes, then flips to its tint with the existing
  `Motion.fast` entrance — the chip visibly *becomes armed* by its outline finishing.
  No haptic: `DeltaHero` already owns this screen's one haptic, and a second tap
  landing ~1s earlier fails §13's utility rule.
- **Plays once per screen visit** (a `@State` flag): toggling PHOTO → OUTLINE, or A/B
  off/on, never replays the draw — toggles are inspection, not ceremony (the same rule
  Plan P set for the capture ghost).

### R1.4 Interruptibility (§3 — non-negotiable)

The ceremony must never gate the screen: scrolling, pinch-zoom, PHOTO/OUTLINE, and A/B
chips all stay live throughout. Any of those interactions during the draw **snaps both
progresses to 1** (RevealStep's `cancelCeremony` is the exact pattern — copy its
shape, including the guard flag). Reduce Motion: outlines appear fully drawn with the
standard opacity fade; chips arm immediately.

### Acceptance (R1)

- Fresh entry, OUTLINE, both layers traceable: A draws from the helmet down, B follows
  at ~0.35s, chips arm as each completes; ceremony ≈ 1.25s; scroll/pinch/toggles never
  blocked; any interaction snaps to done.
- Untraceable layer: raster ring wipes in via `scanReveal` on the same stagger.
- Replay does not occur on toggles; re-push of the screen replays.
- Reduce Motion: no draw, fade only. `ContourTracerTests` green; area numbers
  byte-identical (no analysis file touched).

---

## R2 — Springs where fingers re-trigger things

Adopt `Theme.Motion.interactive()` for motion a user can re-trigger mid-flight — the
places fixed-duration easing produces §3's "brick wall" when tapped rapidly:

- **CompareBar** slide-up/away (`PositionListView`) — a drawer by behaviour; response
  0.3 (the skill's own sheet value, minus its bounce).
- **Segmented underlines** — `SegmentedToggleBar` and `LeaderboardView.FilterBar`
  matched-geometry slides; response 0.3. Rapid tab-tapping today cross-fades two
  eased animations; a spring re-targets from the live underline position.
- **Q5's IndexOverlay** enter/exit — and per §7, it must exit along the path it
  entered (same edge, mirrored motion), whatever presentation the Q5 implementation
  chose.

Visual bar: at rest, before/after frames are indistinguishable from today's — no
overshoot anywhere (damping 1.0). The difference only exists mid-interruption.

### Acceptance (R2)

Rapidly toggling any segmented bar or the compare bar shows the element redirecting
smoothly from wherever it is — no jump-to-start, no completion-wait. Nothing
overshoots. Reduce Motion behaviour unchanged from today.

---

## R3 — Pinch-zoom physics (feel, not flourish)

`PinchZoom.swift` today: pan is hard-clamped, and release snaps to legal values with a
fixed 0.15s ease. Skill violations: hard boundary (§9), no velocity continuity at the
drag→animation seam (§5).

- **Rubber-band during the gesture** past legal bounds (pan beyond edges; zoom below
  1 or above max): port the skill's function as a pure helper —
  `rubberband(overshoot:dimension:constant: 0.55)` — and **unit-test it** (monotonic,
  bounded, ~0 at 0).
- **On release, spring home** with `Theme.Motion.interactive()`, seeding velocity
  from the gesture: iOS 17 `DragGesture.Value.velocity` /
  `MagnifyGesture.Value.velocity`, normalized per §5
  (`gestureVelocity / (target − current)`) into
  `.interpolatingSpring(..., initialVelocity:)` where seeding matters (fast flick
  against an edge); plain `interactive()` where measured velocity is negligible.
- No momentum-projected panning (§6) — the zoomed photo is an inspection surface, not
  a scroll surface; projecting flicks would fight precise loupe-style examination.
  Decided against, not forgotten.

All three `pinchZoomable()` call sites (RevealStep, PositionDetailView,
GhostCompareOverlay) inherit this from the one modifier.

### Acceptance (R3)

Dragging past an edge resists progressively (never freezes); releasing springs back
carrying the finger's velocity — no visible seam at release; zoom-out below 1×
stretches slightly and settles back to exactly 1×. Rubber-band helper tests green.

---

## R4 — Touch-down feedback audit (§1)

N8 covered buttons with bespoke styles; the `.plain`-style rows never got press
states — on iOS, `.plain` on custom row content shows **nothing** on touch-down,
which §1 calls the foundation everything else sits on.

- Add one shared `RowPressStyle: ButtonStyle`: background flashes `bg1` (list rows
  sit on `bg0`) instantly on press-down via `Theme.Motion.press` — the existing N8
  pattern, applied to a fill instead of a glyph.
- Apply to every tappable row: `PositionRow`'s open target, `BikeRow`, `RankRow`,
  the Q5 index rows. Not the checkbox (it has its own selection visual), not chips
  (bordered, already state-ful).

### Acceptance (R4)

Press-and-hold any row: it visibly responds the frame the finger lands, and cancels
by dragging away (free from `ButtonStyle`). No behaviour change on tap-commit.

---

## Sequencing

R2 (token + trivial swaps) → R1 (hero) → R3 → R4. R2 first because it lands the
`interactive()` token and the amended Motion philosophy comment that R3 builds on;
R1 is independent of both. Run `GetTuckedTests` (122 green baseline) plus the new
`ContourTracerTests` and rubber-band tests after each increment.

**Review motion the way the skill says to (§17):** Simulator → Debug → Slow
Animations for the R1 ceremony frame-by-frame; the R2/R3 interruption behaviour can
only be judged by rapid-fire tapping and flicking on device — add both to the
standing on-device pass alongside Plans P and Q.

## What this plan deliberately does not do

- No bounce, overshoot, blur, translucency, or motion blur — skill guidance
  consciously rejected for this brand (see the translation table).
- No new haptics beyond existing ones (§13 utility; R1 explicitly declines one).
- No momentum-projected panning in pinch-zoom (decided against in R3).
- No draw-on for the capture-time ghost overlay (`GhostOverlay` in LiveCameraView) —
  it's an alignment tool the rider holds a bike through; ceremony there costs accuracy.
- No replaying ceremonies on toggles, anywhere.
