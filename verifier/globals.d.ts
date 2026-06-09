export {};

declare global {
  interface Window {
    __segmentReady: Promise<void>;
    __segment(dataUrl: string): Promise<{
      matteDataUrl: string;
      coverageFraction: number;
      durationMs: number;
    }>;
    __smokeImage(): string;
  }
}
