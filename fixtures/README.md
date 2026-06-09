# fixtures/

Drop real cyclist photos here before running `npm run verify`.

## What "real" means

- Full-body cyclists (head to toe or close to it)
- Cluttered outdoor backgrounds — trees, crowds, road furniture
- Various light conditions: overcast, direct sun, backlit
- Multiple angles: front, side, 3/4

Studio shots or clean backgrounds are useless for this test. The spike exists
to validate the *hard* case: a person on a visually noisy background.

## Format

JPG or PNG. Any resolution — the segmenter handles it. Smartphone photos are fine.

## How many

3–10 images covering the conditions above gives a meaningful signal. One image
is enough to start, but a single clean photo passing doesn't retire the risk.

## Privacy

Don't commit photos of real people without their permission. The `output/` folder
(gitignored) is where mattes land — nothing from `fixtures/` is written out
verbatim by the verifier.
