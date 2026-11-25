# toadLAUNCHER roadmap

The working plan, owned by the project owner (Rock, acting via agent sessions).
Phase 0 shipped in v1.1.0. This file is the source of truth; findings and
evidence live in `docs/verification-report.md`, standing decisions in
`docs/DECISIONS.md`.

Status legend: `[ ]` planned · `[~]` in progress · `[x]` shipped · `[-]`
re-scoped (with a note explaining why).

## Phase 0 — trust + recovery (shipped in v1.1.0)

- [x] SEC-01 key rotation with v3 lineage, old key rollback revoked
- [x] SEC-02 detached ECDSA update signatures, installer cert gate
- [x] SEC-03 update leftover sweep
- [x] SEC-04 update check policy throttle (Daily default)
- [x] REL-01 crash-loop safe mode
- [x] PLT-01 Restricted Settings guide
- [x] PLT-02 shade pull fallback
- [x] PLT-03 real screenshot action
- [x] PLT-06 pinned shortcuts query
- [x] PRV-01 merged-manifest permission gate in CI
- [x] BLD-01/02/07 docs, LICENSE, CHANGELOG, stale PR closed
- [x] CLOCK four hero clock faces + 12/24 h (PLT-13 hardening)

## Phase 1 — stabilization (this release)

Everything a launcher must never get wrong: lose no data, start fast,
host widgets completely.

- [x] **REL-02 atomic persistence.** A `SafeStore` two-generation writer for
      every JSON blob: schema version inside the payload, last-good mirror
      slot, validation on read, silent-fallback-to-defaults eliminated.
      Wired into settings, hosted-widget placements, toadLIST, battery
      samples. Legacy v1 payloads (bare JSON, no version) are accepted and
      migrated on first save.
- [x] **PERF-01 fast cold start.** The app index + icons persist to a
      snapshot in the app-private dir. Cold start renders home from the
      snapshot, then refreshes from PackageManager in the background.
      Package events and every successful refresh re-persist the snapshot.
- [x] **PERF-02 icon pipeline.** Native per-package icon disk cache keyed
      by `packageId + lastUpdateTime` (per-package invalidation), raster
      tightened 96 px/90 → 72 px/85, decode skipped entirely for unchanged
      apps. The one-message transport stays (it already runs off the main
      thread); paging becomes unnecessary once cold start stops calling
      `listApps` at all.
- [x] **PLT-07 widget checklist completeness.** Configure-activity flow at
      bind (launch → RESULT_OK keeps, cancel deletes the id), orphan-id
      cleanup at startup (host ids not in placements are freed; placements
      whose ids the host lost are dropped), re-launchable configure
      ("Set up" chip in edit mode for widgets that have one), size options
      passed at bind.
- [x] **PERF budget ledger.** `docs/PERF.md` records the budgets
      (≤ 500 ms cold start, 95 % frame pacing, ~0 % idle cost) and the
      measurement protocol; numbers fill in per release until the device
      matrix (TST-01) lands.

## Phase 2 — the free-form pond (this release)

The layout promise of FEAT-01 and the calm-identity features.

- [x] **FEAT-01 free-form home canvas.** One shared grid per page: Android
      and toad widgets claim rectangular spans at explicit (row, col);
      app icons flow into the remaining cells. Drag widgets to any free
      spot in edit mode, resize handles unchanged, drop targets show the
      ghost at the hover cell, collisions resolve by re-flowing apps.
      Boundary (recorded): per-app free placement, drawer drag-in and
      drop-to-create-folders stay Phase 3 (FEAT-01b) — widgets are
      free-form first because that is where the current model is rigid.
- [x] **FEAT-10 focus tools.** A focus session (15/25/45/60 min): hides
      notification dots and the memories card, calms the pond and rain,
      dims nothing else, shows one quiet countdown chip. Ends early on
      tap, restores everything on completion. Decision #8 ordering:
      focus first, icon packs next, tablet last.
- [x] **PLT-08 home-press behavior.** `onNewIntent` on the native side
      fires a `homePressed` event; Dart closes the topmost overlay
      (placement ghost → menu → folder → drawer → edit mode) and, when
      nothing is open, returns to page 1. Exactly one behavior per press.
- [x] **A11Y-01 semantics pass.** Semantics labels on app icons, folder
      tiles, dock, page dots, hero + placed clocks (spoken time), edit
      strip, focus chip, widget chips. Custom-painted toad art carries a
      spoken name.
- [x] **PLT-14 themed icons.** Monochrome layer of adaptive icons is
      rasterized (API 33+) and shipped per package; Settings → Home
      screen offers "Themed icons" which renders them in the palette ink
      on the paper surface. Devices without the layer keep color icons.
- [-] I18N-01 — **re-scoped to Phase 3.** The string set is still moving
      (focus + canvas added user-visible copy this release); introducing
      l10n infra now doubles every upcoming edit. Revisited once Phase 3
      feature set freezes. Amends the Phase-2 note in DECISIONS §strings.
- [-] FEAT-04 icon packs — **re-scoped to Phase 3.** Decision #8 ordered
      focus first; icon packs follow after the canvas lands so pack
      previews can render on the new grid. Kept ahead of PLT-11.

## Phase 3 — breadth (planned)

- [ ] FEAT-01b per-app free placement, drawer drag-in, drop-to-folder
- [ ] FEAT-04 icon packs (advertise + appfilter mapping, previews on canvas)
- [ ] I18N-01 localization infrastructure + first locales
- [ ] PLT-11 tablet / foldable / landscape layout
- [ ] PLT-04 work profile + private space apps
- [ ] PLT-12 wallpaper depth (system read, parallax, dynamic color)
- [ ] REL-03 backup rules + export/import + delete-all
- [ ] UX-02 gesture one-time hints, UX-03 plain-microcopy toggle
- [ ] A11Y-02/03 reduce-motion + font-scale/contrast audit
- [ ] PERF-03 thermal tiers, PERF-06/07 memory + self-battery budgets
- [ ] TST-01 device/emulator test matrix (the standing gap)
- [ ] BLD-03 dependabot + per-ABI splits (PERF-05) + attestation
- [ ] BLD-04 shrinking config + native symbols

## Quality budgets (confirmed, DECISIONS §10)

- Cold start to first interactive frame ≤ 500 ms on the reference device
- 95 % of frames within budget in steady state; pond never costs while idle
- ~0 % background cost: no network, no jobs, no receivers that wake the app
- No INTERNET permission, ever (CI-enforced)
- Crash-loop safe mode must always leave the phone usable
