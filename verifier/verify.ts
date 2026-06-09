import http from 'node:http';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { chromium, type Page } from 'playwright';
import { COVERAGE_MIN, COVERAGE_MAX, TIMING_CEILING_MS, TIMING_TARGET_MS } from './thresholds.js';

const ROOT = path.resolve(import.meta.dirname, '..');
const FIXTURES = path.join(ROOT, 'fixtures');
const OUTPUT = path.join(ROOT, 'output');
const SMOKE = process.argv.includes('--smoke');

interface SegmentResult {
  matteDataUrl: string;
  coverageFraction: number;
  durationMs: number;
}

function createServer(root: string): http.Server {
  const MIME: Record<string, string> = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.mjs': 'application/javascript',
    '.css': 'text/css',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
  };

  return http.createServer((req, res) => {
    const urlPath = req.url?.split('?')[0] ?? '/';
    const file = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
      res.end(data);
    });
  });
}

async function fileToDataUrl(filePath: string): Promise<string> {
  const buf = await fsp.readFile(filePath);
  const ext = path.extname(filePath).slice(1).toLowerCase();
  const mime = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : 'image/png';
  return `data:${mime};base64,${buf.toString('base64')}`;
}

async function saveMatte(dataUrl: string, filePath: string): Promise<void> {
  const base64 = dataUrl.replace(/^data:image\/png;base64,/, '');
  await fsp.writeFile(filePath, Buffer.from(base64, 'base64'));
}

async function runSmoke(page: Page): Promise<number> {
  console.log('--- SMOKE TEST ---');
  const dataUrl = await page.evaluate(() => window.__smokeImage());
  const result: SegmentResult = await page.evaluate((url) => window.__segment(url), dataUrl);

  await saveMatte(result.matteDataUrl, path.join(OUTPUT, 'smoke_matte.png'));
  console.log(
    `coverage=${(result.coverageFraction * 100).toFixed(1)}%  time=${result.durationMs.toFixed(0)}ms`,
  );

  if (result.coverageFraction < 0 || result.coverageFraction > 1) {
    console.error('FAIL: coverageFraction out of range');
    return 1;
  }

  console.log('PASS: plumbing works. Matte written to output/smoke_matte.png\n');
  return 0;
}

async function runEval(page: Page): Promise<number> {
  const files = (await fsp.readdir(FIXTURES)).filter((f) => /\.(jpe?g|png)$/i.test(f));

  if (files.length === 0) {
    console.error(
      'ERROR: No fixture images found.\n' +
        'Add real cyclist photos (JPG/PNG) to fixtures/ and re-run `npm run verify`.\n' +
        'Run `npm run verify:smoke` to test plumbing without photos.',
    );
    return 1;
  }

  console.log(`--- EVAL: ${files.length} fixture(s) ---\n`);

  let passed = 0;
  let failed = 0;

  for (const file of files) {
    const dataUrl = await fileToDataUrl(path.join(FIXTURES, file));
    const result: SegmentResult = await page.evaluate((url) => window.__segment(url), dataUrl);

    const stem = path.basename(file, path.extname(file));
    await saveMatte(result.matteDataUrl, path.join(OUTPUT, `${stem}_matte.png`));

    const pct = (result.coverageFraction * 100).toFixed(1);
    const ms = result.durationMs.toFixed(0);
    const timingNote =
      result.durationMs > TIMING_TARGET_MS
        ? ` (>${TIMING_TARGET_MS}ms target — headless CPU proxy, see RUNBOOK)`
        : '';

    let reason: string | undefined;
    if (result.coverageFraction < COVERAGE_MIN) {
      reason = `coverage too low (${pct}% < ${(COVERAGE_MIN * 100).toFixed(0)}%) — mask may be empty`;
    } else if (result.coverageFraction > COVERAGE_MAX) {
      reason = `coverage too high (${pct}% > ${(COVERAGE_MAX * 100).toFixed(0)}%) — mask may be whole frame`;
    } else if (result.durationMs > TIMING_CEILING_MS) {
      reason = `timing exceeded ceiling (${ms}ms > ${TIMING_CEILING_MS}ms)`;
    }

    if (reason) {
      console.log(`✗ ${file}  coverage=${pct}%  time=${ms}ms${timingNote}`);
      console.log(`  → ${reason}`);
      failed++;
    } else {
      console.log(`✓ ${file}  coverage=${pct}%  time=${ms}ms${timingNote}`);
      passed++;
    }
  }

  console.log(`\nMattes written to output/ — review visually for edge quality.`);
  console.log(`\n${passed}/${passed + failed} passed.`);

  return failed > 0 ? 1 : 0;
}

async function main(): Promise<void> {
  await fsp.mkdir(OUTPUT, { recursive: true });

  const server = createServer(ROOT);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as { port: number };

  // SwiftShader provides software WebGL — MediaPipe's GL postprocessor needs it even in CPU mode.
  const browser = await chromium.launch({
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'],
  });
  const page = await browser.newPage();
  page.setDefaultTimeout(60_000);

  let exitCode = 0;

  try {
    await page.goto(`http://127.0.0.1:${port}/`);
    console.log('Waiting for segmentation model to load…');
    await page.evaluate(() => window.__segmentReady);
    console.log('Model ready.\n');

    exitCode = SMOKE ? await runSmoke(page) : await runEval(page);
  } catch (err) {
    console.error('Fatal:', err);
    exitCode = 1;
  } finally {
    await browser.close();
    server.close();
  }

  process.exit(exitCode);
}

main();
