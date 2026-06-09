// Knobs — safe for the agent to change
const MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite';
const WASM_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm';
const CONFIDENCE_THRESHOLD = 0.5;
const DELEGATE = 'CPU'; // keep CPU for headless determinism; GPU is faster on-device

import { ImageSegmenter, FilesetResolver } from
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/vision_bundle.mjs';

let segmenter = null;

window.__segmentReady = (async () => {
  const vision = await FilesetResolver.forVisionTasks(WASM_BASE);
  segmenter = await ImageSegmenter.createFromOptions(vision, {
    baseOptions: { modelAssetPath: MODEL_URL, delegate: DELEGATE },
    runningMode: 'IMAGE',
    outputCategoryMask: false,
    outputConfidenceMasks: true,
  });
})();

window.__segment = async function (dataUrl) {
  await window.__segmentReady;

  const img = await loadImage(dataUrl);
  const t0 = performance.now();
  const result = segmenter.segment(img);
  const durationMs = performance.now() - t0;

  const mask = result.confidenceMasks[0];
  const { width, height } = mask;
  const data = mask.getAsFloat32Array();

  const canvas = document.getElementById('output');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  const imageData = ctx.createImageData(width, height);

  let foreground = 0;
  for (let i = 0; i < width * height; i++) {
    const v = data[i] >= CONFIDENCE_THRESHOLD ? 255 : 0;
    imageData.data[i * 4 + 0] = v;
    imageData.data[i * 4 + 1] = v;
    imageData.data[i * 4 + 2] = v;
    imageData.data[i * 4 + 3] = 255;
    if (v === 255) foreground++;
  }

  ctx.putImageData(imageData, 0, 0);
  const matteDataUrl = canvas.toDataURL('image/png');
  const coverageFraction = foreground / (width * height);

  result.close();

  return { matteDataUrl, coverageFraction, durationMs };
};

// Returns a synthetic image data URL for smoke testing plumbing only.
// The selfie segmenter won't produce a meaningful mask from this — that's fine.
window.__smokeImage = function () {
  const canvas = document.createElement('canvas');
  canvas.width = 320;
  canvas.height = 480;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#8899aa';
  ctx.fillRect(0, 0, 320, 480);
  ctx.fillStyle = '#223344';
  ctx.beginPath();
  ctx.ellipse(160, 95, 45, 55, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillRect(108, 148, 104, 200);
  ctx.fillRect(108, 344, 44, 120);
  ctx.fillRect(168, 344, 44, 120);
  return canvas.toDataURL('image/jpeg', 0.9);
};

function loadImage(dataUrl) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = dataUrl;
  });
}
