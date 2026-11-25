# Changelog

The format follows keep-a-changelog; versions follow `pubspec.yaml`
(the single source of truth — CI derives release names from it).

## [1.2.0] — stabilization and the free-form pond

Phase 1 (stabilization) and Phase 2 (free-form canvas) of the roadmap
(roadmap.md); findings and evidence in docs/verification-report.md.

### Reliability & data (Phase 1)
- **REL-02 — persistence is atomic and versioned.** A two-generation
  `SafeStore` writer now wraps every JSON blob (settings, hosted-widget
  placements, toadLIST, battery samples): schema version inside the
  payload, a last-good mirror slot, validation on read. A corrupt or
  half-migrated payload falls back to the previous good state instead of
  silently resetting to defaults. v1.1.0-era payloads are read as-is and
  migrate on the next save.

### Performance (Phase 1)
- **PERF-01 — fast cold start.** The app index and icons persist to a
  snapshot in the app-private dir; cold start renders home from files
  before PackageManager is ever asked, then re-indexes quietly in the
  background and re-persists. Package events keep it fresh; a corrupt
  snapshot falls through to the live index. Numbers in docs/PERF.md.
- **PERF-02 — icon pipeline.** Native per-package icon disk cache keyed by
  `packageId + lastUpdateTime` (unchanged apps skip decode entirely),
  raster tightened 96 px/90 → 72 px/85 — smaller channel payload,
  imperceptible at launcher sizes.

### Platform correctness (Phase 1 + 2)
- **PLT-07 — widget checklist complete.** Widgets that declare a configure
  activity now launch it right after binding (cancel frees the id, the
  widget never lands half-configured); placed widgets with a configure
  activity get a **Set up** chip in edit mode; orphaned host ids are
  freed at startup and placements whose ids the host lost are dropped;
  bind now carries size options.
- **PLT-08 — Home-press behavior.** Pressing Home while already here peels
  exactly one overlay (placement ghost → menu → folder → drawer → edit
  mode) and, with a clear desk, walks back to page 1.
- **PLT-14 — themed icons.** The monochrome layer of adaptive icons
  (Android 13+) is rasterized and shipped per package; Settings → Home
  screen → *Themed icons* renders them in the palette's ink on paper.
  Apps without the layer keep their color icons.

### The free-form pond (Phase 2, FEAT-01)
- **One shared canvas per page.** Android and toad widgets claim
  rectangular spans at explicit (row, col); app and folder cells flow
  into every cell left free. Drag a widget anywhere in edit mode, pull
  its corners to resize (now for every kind, not just the clock), drop a
  new widget exactly where you aimed — collisions slide down, apps
  re-flow, nothing ever overlaps. The grid skeleton, hint bubble and
  page dots follow the same geometry.
- Per-app free placement, drawer drag-in and drop-to-create-folders stay
  Phase 3 (FEAT-01b), as recorded in the roadmap.

### Focus tools (Phase 2, FEAT-10)
- **Focus session** (long-press empty space → *Focus session*): dots,
  badges and the memories card hide, the pond calms and rain stops for
  15/25/45/60 minutes (Settings → Home screen). One quiet countdown chip
  marks the session; tapping it ends early; a real timer always ends it.

### Accessibility
- **A11Y-01 — semantics pass.** App icons, folder tiles, dock, page dots,
  the edit strip, placed-widget chrome and the focus chip now carry
  labels for screen readers (spoken folder contents included).

### Build & docs
- roadmap.md restored as the source of truth (Phase 1/2 marked shipped,
  Phase 3 planned: FEAT-01b, icon packs, I18N, tablet, work profile).
- docs/PERF.md — budgets, protocol and honest first measurements.

## [1.1.0] — trust, recovery, and the four clocks

Phase 0 of the audit roadmap (docs/verification-report.md) plus the hero
clock work.

### Security & trust
- **SEC-01 — signing key rotated.** The committed release keystore (public
  since v0.9) is retired: a new 4096-bit key lives only in CI secrets, the
  working tree carries no key material, and an APK Signature Scheme v3
  proof-of-rotation lineage (`android/toad-lineage.bin`) lets **Android 9+
  update in place** while the old key's rollback capability is revoked —
  the leaked key can never retake the app. Android 8.x reinstalls once.
  Fingerprints live in SECURITY.md; Settings → About shows the installed
  certificate so anyone can cross-check.
- **SEC-02 — updates are signature-verified.** Every release now ships a
  detached ECDSA signature over `tagName|sha256|assetName`; the app embeds
  the public half and refuses unsigned/tampered releases before any
  banner appears. The downloaded APK's signing certificate is checked
  against ours before the installer ever sees it.
- **SEC-03 — update leftovers swept.** The app-private updates dir cleans
  files older than a week at startup.
- **SEC-04 — update checks throttled.** The silent check runs at most once
  per policy (Off / Manual / Daily / Weekly — Daily default) instead of
  once per process; manual checks always work.

### Reliability
- **REL-01 — crash-loop safe mode.** Uncaught errors land in a local,
  never-uploaded crash ledger; three crashing boots inside five minutes
  opens a calm safe mode (pond off, no widgets, plain app grid — the phone
  stays usable) with: try again · reset layout · share crash log · choose
  another Home. Recovery needs no adb.
- **NEW-05 — settings restore drift**: restored settings no longer grow
  the hero clock to 2 rows (fromJson default now matches the constructor).

### Platform correctness
- **PLT-01 — Restricted Settings guide.** On Android 13+ sideloads the
  special-access asks now explain the one-time "Allow restricted settings"
  unlock (App info → ⋮) with a three-tap guide before deep-linking, and a
  retry tip after.
- **PLT-02 — shade fallback.** The notification-shade pull falls back to
  the accessibility service's global action when the hidden StatusBarManager
  call is blocked.
- **PLT-03 — screenshot, real.** The two-finger screenshot gesture now
  performs the accessibility global action (same consent as the lock).
- **PLT-06 — pinned shortcuts** are queried alongside dynamic and manifest
  ones.
- **PLT-07 — widget size options.** Hosted Android widgets are told their
  new size on resize, so responsive widgets re-render correctly.

### The clock (roadmap §6 + PLT-13)
- The hero clock wears **four faces**: hand-lettered Caveat (the original),
  a hand-drawn **analog dial**, a **word clock** ("twenty to eleven"), and
  **flip cards** — live-applied from Settings → Home screen, shared by the
  hero and the placed clock widget.
- **12/24-hour setting** (follow-system default) for every face.

### Build & CI
- **PRV-01 — permission gate.** CI fails any build whose merged manifest
  requests a permission outside the allow-list; INTERNET is a hard fail.
  Releases are gated too.
- Releases now attach the `.sig` update signature; CI verifies the rotation
  lineage and the current-certificate match before publishing.
- **BLD-01/02** — README restructured (no more changelog dump), CHANGELOG
  and docs/ added, MIT LICENSE added, `android/local.properties` untracked.
- **BLD-07** — the stale zero-diff research PR closed.

## [1.0.0] — first production release

The launcher is whole: hand-made home with pond and sketchbook skins,
device mode over the real Android bridge, ask-by-app permissions with deep
links, intro that hands over to the asks, toadLIST with notes, battery
drain guard with low-battery calm, and a working in-app update riding the
system download service (toadFILES flow: app-private dir + DownloadManager
content URI install handoff, SHA-256 gated). 106 tests.

## [0.12.0-beta] — the app asks

Special accesses ask calmly at the moment of use; first-run intro;
toadLIST (todos + comments); battery drain system with low-battery calm;
live sticky note; release-notes render.

## [0.11.0-beta] — the launcher infrastructure

Default-home verification + banner; real AppWidgetHost widget hosting with
live previews; notification shade pull; double-tap lock service; live app
index on package events; notification dots; app shortcuts; toadFILES
self-update flow.

## [0.10.0-beta] — device mode

Real backend (package manager index, adaptive icons), real permissions,
toad family theming, auto-update, API 37.

## [0.9.0-beta] — signed beta

Fixed release keystore (updates install over each other), craft toad
adaptive icon.

## [0.1.0-alpha.1] — the proposal

Theme engine (4 skins), home screen, hero clock, memories card, app grid,
page dots, dock, static pond.
