// All thresholds are env-overridable for one-off experiments.
export const COVERAGE_MIN = parseFloat(process.env['COVERAGE_MIN'] ?? '0.05');
export const COVERAGE_MAX = parseFloat(process.env['COVERAGE_MAX'] ?? '0.80');

// Headless CPU ceiling — regression guard only, not the device quality bar.
// 300–500ms is the on-device target; headless will run much higher.
export const TIMING_CEILING_MS = parseInt(process.env['TIMING_CEILING_MS'] ?? '5000', 10);
export const TIMING_TARGET_MS = parseInt(process.env['TIMING_TARGET_MS'] ?? '500', 10);
