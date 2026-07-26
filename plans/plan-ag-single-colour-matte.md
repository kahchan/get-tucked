# Plan AG — Single-colour subject matte (retire the user-facing two-tone)

**Status:** APPROVED 2026-07-26 (Kah) — implementing alongside Plan AF.
**Decision:** the rider/bike two-tone split is structurally untrustworthy: the bike
colour is an *absence* (subject − person), so every person-mask flaw renders as a wrong
colour somewhere. Proven failure modes: amodal completion behind the thin fork (AD5b
crop shrinks it but leaves bars/bags green — Kah reviewed afcrop-t200), greedy claiming
of contact regions (bars/saddle/bags), and content-dependent inconsistency. A matte
that's confidently wrong in a different place per photo is worse than one colour that's
always true. The measurement never used the split — area = subject mask alone, the
rider+bike+bags system per the methodology.

## AG1 — User-facing matte is one colour

- `PositionDetailView.buildMaskOverlay` and `CaptureView`'s reveal overlay builder:
  when a subject mask exists, render `MatteRenderer.tintedOverlay(subjectMask, acid,
  0.5)` — no two-tone. Person-only fallback (nil subject mask) unchanged (already a
  single acid tint). Alpha/colour identical to today's rider tint so the change reads
  as unification, not a new look.
- Keep `twoToneOverlay*` in MatteRenderer with their tests (pure functions; also the
  reference implementation if the split ever earns its way back) — they just lose
  their user-facing call sites. Do NOT delete AD5a/AE2 tuned constants or tests.
- Z4 bike-coverage % row STAYS — it becomes the numeric "did the bike get included"
  check now that colour no longer plays that role.
- DEBUG diagnosis: if `MatteCheckView` (DEBUG-only) can gain a two-tone mode cheaply,
  wire it there; otherwise skip — the harness (tools/matte-lab) is the real
  diagnostic surface and keeps its composites.

## AG2 — Honesty pass on split-adjacent copy/UI

- Any UI copy or affordance that promises rider-vs-bike colour separation must go or
  change (check methodology/how-the-number-is-made copy for mentions of two colours).
- AD5b stays shelved: proven and documented in plan AE, not shipped.

## Verification

- Full suite green (285 baseline).
- On-device: detail + reveal mattes render one acid tint over the whole subject;
  coverage row still populates; no orphaned amber legend anywhere.
