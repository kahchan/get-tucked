# Plan AQ: change or create the bike during analysis

Kah, 2026-10-17: the goal is to **correct** the bike the photo was shot on, not to explore what-if bikes. Testers did not see the camera's bike chip. Build A + C, skip B. Show the bar width in the row.

**Status: A + C implemented 2026-10-17, uncommitted, 387 tests green (two `isAvailable` tests deleted with the function), reviewer pass done. Device pass outstanding.**

## The key fact

`runAnalysis` (`CaptureView.swift`) reads the bar width only after CONFIRM SCALE. So a swap on the bar-tap step needs no rescale.

## A · Bike row on the bar-tap step: done

`BikeRulerRow` (`BARS 420 MM · NICKNAME`, `CHANGE ▾`) sits above the head-on `TapCalibrationStep` banner and opens `BikePickerSheet` (pick or add). This covers the camera and library paths. The side-on ruler step does not get the row. If the bar type changes (drop ↔ flat), the bar taps are cleared, because drop ends and grip ends are different points. Wheel taps stay: they are image pixels, and the wheel check skips when the new bike has no wheel size.
**Device:** row visible on camera and library paths; a swap before CONFIRM SCALE gives the new bike's number on the reveal; a swap with a different bar type clears the taps and the prompts change; side-on uses the swapped bike's wheelbase.

## C · New bike from WRONG BIKE?: done

Inline add form moved from `BikePickerSheet` to a shared `AddBikeForm` (both sheets use it). `WrongBikeSheet` adds a bike and goes to the existing confirm. The link now shows when the position has `handlebarWidthMmUsed` (the same guard as `BikeSwap.apply`), not only when another bike exists. This also removes an old no-op, where CONFIRM did nothing on a position with no bar-width provenance.
**Device:** with one bike only, WRONG BIKE? shows; add a bike → confirm → numbers rescale.

## B · Swap on the reveal: rejected

The number would change in front of the user for a reason that is not the rider (§3).
