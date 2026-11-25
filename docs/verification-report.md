# toadLAUNCHER — Verification Report (STEP 1 of roadmap.md)

Repo state audited: `main @ 71e4574` · pubspec `1.0.0+43` · tags `v1.0.0`, `v0.11.0-beta`, …
Toolchain verified locally: Flutter 3.50.1 stable (same as CI) — `flutter analyze` clean, `flutter test` **106/106 pass**.
Method: full read of `MainActivity.kt` (1167 lines), both services, manifest, gradle, all core Dart (bridge, settings, update engine, repositories, app entry) and the feature files touched by roadmap findings.

Legend: **CONFIRMED** / **PARTIAL** / **REFUTED**, with evidence (file:line).

## A. Security & trust

| ID | Verdict | Evidence |
|---|---|---|
| SEC-01 | **CONFIRMED** | `android/app/toad-release.jks`, `android/key.properties` and `android/local.properties` are tracked (`git ls-files`). README.md:275–280 documents alias + both passwords and says "committed on purpose". |
| SEC-02 | **CONFIRMED** | `checkLatestRelease` (MainActivity.kt:580–658) fetches the `.sha256` asset from the same release; `installDownloadedApk` (:770–793) gates on it. No detached signature, no update-signing key, version compare is `versionName`-only (update_engine.dart:169) — **no versionCode monotonic gate**, no APK-cert check, repo pinned only by the Dart const `kUpdateRepo` (toad_family.dart:78). |
| SEC-03 | **PARTIAL (largely fixed in v1.0.0)** | Downloads already go to the app-private dir `getExternalFilesDir/updates` (MainActivity.kt:566,577,684); verification streams over the DownloadManager content URI (:777). Remaining: no sweep of stale APKs, file survives after install, `getExternalFilesDir` is world-readable on API < 30 legacy storage. |
| SEC-04 | **CONFIRMED** | `silentStartupCheck` (update_engine.dart:161–175) runs once per process with no persisted last-check timestamp, no interval policy. `autoUpdateCheck` is a bool, default ON. A launcher process restarts often → the check effectively runs on every process start. |
| SEC-05 | **PARTIAL** | Family integration is name-only: `kToadFamilyApps` list (toad_family.dart:21–36) + prefix match; widget discovery via `installedProviders` filter (:518–530). No cross-app data flow exists yet (no exported providers, no signature permissions) — nothing to attack today; memories card is simulated. |
| SEC-06 | **PARTIAL (good shape)** | Only `MainActivity` is exported (required for Home); both services are `BIND_*`-guarded (manifest:63–86); no manifest receivers; no PendingIntents. Gaps: no `dataExtractionRules`/`fullBackupContent` (REL-03), channel args are trusted strings (launch/appDetails validate implicitly via PackageManager null returns — acceptable). |

## B. Android platform correctness

| ID | Verdict | Evidence |
|---|---|---|
| PLT-01 | **CONFIRMED** | `openAccessibilitySettings` (MainActivity.kt:1025–1039) and `openNotificationListenerSettings` (:1053–1060) deep-link straight to the toggles. No App-info "Allow restricted settings" pre-step for Android 13+ sideloads anywhere. |
| PLT-02 | **CONFIRMED** | `expandNotificationsPanel` (:989–1000) reflects into hidden `StatusBarManager`. No accessibility `GLOBAL_ACTION_NOTIFICATIONS` fallback (the lock service could provide one). |
| PLT-03 | **CONFIRMED** | `twoFingerScreenshot` is a settings row (launcher_settings.dart:61) but no screenshot action exists in Kotlin; README says it stays disabled. `GLOBAL_ACTION_TAKE_SCREENSHOT` (API 28+) is available on the existing lock service — currently unused. |
| PLT-04 | **CONFIRMED (absent)** | `listApps` uses `queryIntentActivities` (MainActivity.kt:358–374) — single user. `startShortcut` hardcodes `Process.myUserHandle()` (:1093). No profiles, no work badges, no Private Space. |
| PLT-05 | **CONFIRMED** | `QUERY_ALL_PACKAGES` in manifest:10; index built from `queryIntentActivities`. `LauncherApps.getActivityList` would serve a Home app without it. |
| PLT-06 | **PARTIAL** | Static + dynamic shortcuts queried (`FLAG_MATCH_MANIFEST or FLAG_MATCH_DYNAMIC`, :1071). **Pinned shortcuts not queried**; no `onNewIntent`/`EXTRA_PIN_ITEM_REQUEST` handling (incoming pin requests from Chrome/WhatsApp dead-end); we create no pinned shortcuts of our own. |
| PLT-07 | **PARTIAL** | Real hosting: allocate→bind→createView (:886–941), placeholders for gone providers, host listening tied to onStart/onStop (:240–249), placements persisted. Missing: **`updateAppWidgetSize` never called** (responsive widgets render wrong after resize), no configure-activity flow at bind, no orphan-id cleanup, no reconfigure. |
| PLT-08 | **PARTIAL** | edge-to-edge on (app.dart:239); `launchMode=singleTask`, `resizeableActivity`, configChanges handled. **No `onNewIntent` override** — Home-press-on-Home does nothing (no return-to-page-1 / close-drawer rule). |
| PLT-09 | **CONFIRMED (absent)** | `launch()` (:401–410) plain `startActivity` + NEW_TASK; no launch-bounds animation. |
| PLT-10 | **CONFIRMED (absent)** | Only enabled-state checks (`isLockServiceEnabled`, `hasNotificationAccess`); no "enabled but not running" detection, no per-OEM guidance. |
| PLT-11 | **CONFIRMED (absent)** | Fixed phone layout; grid columns 4/5 only; no landscape/foldable/tablet handling. |
| PLT-12 | **PARTIAL** | `WallpaperManager.setBitmap` (:478–484) + bundled papers + SAF photo import. No system-wallpaper read, no parallax, no dynamic color. |
| PLT-13 | **PARTIAL** | `clockProvider` (launcher_settings.dart:399–406) polls `DateTime.now()` every 5 s — time/TZ changes self-heal within one tick. But: **hero clock hardcodes 24 h `HH:MM`** (hero_zone.dart:55–57), weekday/month names are hardcoded English arrays (:31–53), no 12/24 h setting, no locale-aware date. |
| PLT-14 | **PARTIAL** | Adaptive icons rasterized correctly (iconPng, :376–399); 3 shape masks exist. No monochrome/themed icons, fixed 96 px raster, no legacy normalization. |

## C. Performance

| ID | Verdict | Evidence |
|---|---|---|
| PERF-01 | **PARTIAL (unmeasured, one real gap)** | Launch background = paper (no white flash). No persisted index/layout snapshot — every cold start re-enumerates apps + decodes all icons through the channel before home renders. |
| PERF-02 | **CONFIRMED** | `listApps()` decodes **every** app icon to a 96 px PNG in one message (MainActivity.kt:358–399). No paging, no memory/disk cache, no per-package invalidation. |
| PERF-03 | **PARTIAL** | Loop pauses when invisible/saver/calm claimed and coded (stage-4 tests). No thermal/quality tiers, no "remove animations" respect. |
| PERF-04 | **CONFIRMED** | Hybrid composition via `PlatformViewLink` (android_widget_view.dart:45–50). No caps, no off-screen pause. |
| PERF-05 | **CONFIRMED** | CI builds one universal APK only (ci.yml:48,83). |
| PERF-06/07 | **NOT IMPLEMENTED** | No memory budget, no self battery measurement. |

## D. Reliability & data

| ID | Verdict | Evidence |
|---|---|---|
| REL-01 | **CONFIRMED (absent)** | `main.dart` is 9 lines — no zone guard, no FlutterError capture, no crash counter, no safe mode, no local crash log. |
| REL-02 | **CONFIRMED** | Settings = one JSON blob via `prefs.setString` (launcher_settings.dart:334–342), non-atomic, silent catch on restore → defaults = data loss on corruption. No schema version inside payload, no last-good. Same pattern for todos/battery samples. |
| REL-03 | **CONFIRMED (absent)** | No backup rules in manifest, no export/import, no "delete all data". |
| REL-04 | **PARTIAL (v0.11 fixed the loud part)** | `appRepositoryProvider` (app_repository.dart:217–229) still falls back to `DemoAppRepository`, but the bridge-failure banner is loud and offers retry; demo on non-Android surfaces is by design. Device-mode default ON. |
| REL-05 | **PARTIAL** | Drain math excludes charging spans, 12-min evidence floor, 240-sample cap (README + battery_monitor.dart). No gap flagging (dead-process spans misread), no hysteresis on the 15 % night flip (UX-05 confirmed). |
| REL-06 | **PARTIAL** | Ongoing excluded, re-seed on reconnect (ToadNotificationListener.kt:37–47). Group summaries double-count (no `groupKey` dedupe), no per-user separation, no silent-notification setting. |
| REL-07 | **PARTIAL** | failed/needsPermission/checksumFailed states exist. Process death mid-download loses UI state (file persists); no stale sweep; version compare handles pre-releases correctly (tested). |

## E. UX / A11y / i18n

| ID | Verdict | Evidence |
|---|---|---|
| UX-01 | **CONFIRMED** | Widgets live in a per-page stack (`WidgetZone` header above the grid, home_screen.dart:669–685); no free-form cells, no drawer→home drag, no drop-to-create folders, no page add/remove. |
| UX-02 | **PARTIAL** | Long-press menus exist; edit-mode hint bubble exists; no gesture one-time hints. |
| A11Y-01 | **CONFIRMED (absent)** | Zero `Semantics` widgets in `lib/` (grep). Custom-painted pond/icons carry no semantics. |
| A11Y-02/03 | **PARTIAL** | `calmPond` freezes loop (manual); no system reduce-motion respect; no font-scale/contrast audit. |
| I18N-01 | **CONFIRMED (absent)** | All strings hardcoded English; Latin A–Z rail. |
| UX-03 | confirmed absent (fine) | — |

## F. Privacy

| ID | Verdict | Evidence |
|---|---|---|
| PRV-01 | **CONFIRMED (absent)** | No manifest permission gate in CI. Current manifest permissions: QUERY_ALL_PACKAGES, SET_WALLPAPER, REQUEST_DELETE_PACKAGES, REQUEST_INSTALL_PACKAGES, PACKAGE_USAGE_STATS. **No INTERNET** — invariant holds today, unguarded. |
| PRV-02 | **PARTIAL** | Memories card simulated; no hide/blur toggle. |
| PRV-03 | **PARTIAL** | Permissions page exists; no data-transparency detail/sizes. |

## G. Build / CI / repo hygiene

| ID | Verdict | Evidence |
|---|---|---|
| BLD-01 | **CONFIRMED (triple drift)** | README Status says v0.12.0-beta (:9), Install says v0.11.0-beta (:245), pubspec is `1.0.0+43`. |
| BLD-02 | **CONFIRMED** | No LICENSE, no CHANGELOG, no docs/; README is a changelog dump. |
| BLD-03 | **CONFIRMED** | Actions pinned by tag only; no lint, no dependabot, no per-ABI, no attestation. |
| BLD-04 | **PARTIAL** | No shrinking config in build.gradle.kts; no symbols kept. |
| BLD-06 | **CONFIRMED** | README documents `git add -A` release flow (:284–288). |
| BLD-07 | **CONFIRMED** | PR #1 (`docs/voltageos-launcher-research`) nets to a **zero-file diff** — its final commit removes the research file it added; only the PR description holds content. Triage: close. |

## H. Testing

106 Dart tests green (9 files). **TST-01 CONFIRMED**: zero device/instrumented tests. TST-02/03/04/05 absent.

## New defects found (NEW-)

| ID | Severity | Finding |
|---|---|---|
| NEW-01 | Low | `android/local.properties` is tracked (machine-specific SDK path; should be gitignored). |
| NEW-02 | Medium | Hero clock hardcodes 24 h and English weekday/month names (also tracked as PLT-13/CLOCK work). |
| NEW-03 | Low | `awaitDownload` busy-polls every 400 ms on the update thread for up to 25 s (fine functionally, wasteful but bounded). |
| NEW-04 | Low | Update `.sha256` fetch failure is silently ignored ("checksum optional") — combined with SEC-02 this is the weak gate; new signature scheme supersedes. |

## Requested inventories

- **Versions**: Flutter 3.50.1 · Dart 3.14.0 · AGP 9.3.1 (settings.gradle.kts) · Kotlin 2.4.20 · Gradle wrapper 9.5 · compile/target SDK 37, minSdk 26, Java 17 target.
- **Plugins/dependencies**: `material_ui ^1.1.0`, `flutter_riverpod ^2.6.1`, `shared_preferences ^2.3.2` (+ dev: flutter_test, flutter_lints ^6). Nothing else — icon transport and everything else is hand-rolled.
- **Persistence stores**: SharedPreferences JSON blobs — `toadlauncher.settings.v1` (settings), todo store key (todos+comments), battery samples key (240 cap), widget placements (per home_controller). No schema version field inside payloads; writes non-atomic.
- **Shade pull**: reflection into hidden `StatusBarManager.expandNotificationsPanel` (MainActivity.kt:989).
- **Widget hosting view mode**: `PlatformViewLink` + `AndroidViewSurface` hybrid composition, factory `toad-widget-host`, host id `0x70AD`.
- **Icon transport**: full-index 96 px PNG rasterization in one channel message at index build (no paging/caching).
- **Family integration**: package-id list match only; no IPC, no exported components; memories card simulated.

**Bottom line:** the roadmap's Phase 0 list stands as written — SEC-01/02/03/04, PLT-01, REL-01, PRV-01, BLD-01/02/07 are all real. The v1.0.0 tree is healthy (analyze clean, 106/106 tests) and the architecture rule (thin Kotlin adapter, decisions in Dart) is genuinely followed. Proceed to Phase 0 + CLOCK per owner instructions.
