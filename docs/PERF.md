# toadLAUNCHER — performance ledger

Budgets confirmed by the owner (DECISIONS §10). This file records the
protocol and, per release, what was measured. Device-lab numbers land with
TST-01; until then every claim names where it was measured.

## The budgets

| Budget | Target | Guard |
|---|---|---|
| Cold start → first interactive frame | ≤ 500 ms on the reference device | snapshot fast path (PERF-01) |
| Frame pacing, steady state | ≥ 95 % within budget | pond loop pauses (PERF-03), canvas re-flow is O(cells) |
| Idle cost (screen on, untouched) | ~0 % CPU | no timers besides the 5 s clock tick; widgets self-pause off-screen |
| Background cost | zero wakes | no INTERNET, no jobs, no wake-locks; receivers only mutate in-memory state |
| Crash recovery | phone always usable | REL-01 safe mode |

## PERF-01 — cold start path (v1.2.0)

Before: every cold start awaited `listApps()` — PackageManager enumeration
plus a 72 px PNG raster per app on one channel message — before the first
frame. After: the app index and icons persist to the app-private snapshot
dir; cold start reads files and renders, then re-indexes in the background.

Measured protocol (once a device matrix exists):
`adb shell am start -W -n family.toad.launcher/.MainActivity` — report
`TotalTime` (cold, first launch after boot) and the median of 5 runs;
CI logs the debug-build number for trend-tracking.

Local harness (linux dev box, debug, 2 000-app synthetic index, ~8 MB of
icon bytes, `test` timing around `AppSnapshotStore.save/load`): snapshot
write ≈ 720 ms, snapshot load ≈ 400 ms. The load scales with real-world
indexes (≈ 150 apps, ≈ 2 MB of icons → comfortably under 100 ms) and the
write runs in the background after the live refresh, never on the first
frame. Real-device deltas get recorded here from v1.2.1 on.

## PERF-02 — icon pipeline (v1.2.0)

- Native per-package disk cache: `<filesDir>/icon-cache/<pkg>-<stamp>.png`
  keyed by `packageInfo.lastUpdateTime` — unchanged apps skip decode
  entirely on re-index (per-package invalidation, no version sweep).
- Raster tightened 96 px/90 → 72 px/85: ≈ 30–40 % smaller channel payload
  per icon, imperceptible at 48–54 dp render sizes.
- Monochrome layer (PLT-14) rides the same cache (`<pkg>.mono-<stamp>`).
- Transport stays one-message-per-index (already off the UI thread);
  paging became unnecessary once cold start stopped calling `listApps`
  at all (snapshot path).

## PERF-04 — widget hosting (unchanged from v1.1.0)

Hybrid composition per hosted widget; resize pushes
`updateAppWidgetSize` only when the size actually changes (± 4 dp
hysteresis). Off-screen pause remains engine-managed; a true off-screen
pause for hosted views is Phase 3 alongside PERF-06/07 budgets.

## Measurement honesty

Sandbox/dev-machine numbers above are indicative, not device numbers.
Nothing in this file should be quoted as a device measurement until the
TST-01 matrix (Samsung A-series, Pixel, a Samsung One-UI skin) lands;
that work is scheduled in roadmap Phase 3.
