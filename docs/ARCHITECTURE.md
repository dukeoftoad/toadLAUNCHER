# Architecture

One page, no magic — how the pond fits together.

## The rule

**Decisions live in Dart; the OS adapter lives in Kotlin (one file).**

```
lib/                                 android/.../MainActivity.kt
├── app.dart            ← root: theme scope, update banner, first-run gate
├── core/
│   ├── device/         ← the SEAM
│   │   ├── device_bridge.dart    (typed MethodChannel wrapper)
│   │   ├── update_engine.dart    (update state machine — Dart decides)
│   │   ├── battery_monitor.dart  (sampling + drain math)
│   │   └── toad_family.dart      (registry + repo coordinates)
│   ├── repositories/   ← demo vs device index (AppRepository)
│   ├── settings/       ← LauncherSettings (Riverpod + SharedPreferences)
│   ├── reliability/    ← crash_guard.dart (REL-01 ledger + verdict)
│   └── theme/          ← tokens, skins, theme scope
├── features/
│   ├── home/           ← home screen, controller (undo, placements)
│   ├── pond/           ← pond pro home, ambient loop, mouth drawer
│   ├── drawer/ folder/ edit/ widget_picker/ context_menu/
│   ├── settings/       ← hub + pages (permissions, battery, about…)
│   ├── safe_mode/      ← REL-01 recovery UI
│   ├── intro/ todo/ wallpaper_style/
└── shared/widgets/     ← clock faces, placed widgets, asks, toasts
```

Kotlin: `MainActivity.kt` (the adapter: apps, widgets, shade, updates,
battery, shortcuts, cert fingerprints…), `ToadLockService.kt` (lock/shade/
screenshot global actions — opt-in accessibility), `ToadNotificationListener.kt`
(package counts only — opt-in). That is the whole native side.

## Key flows

**Index.** `appRepositoryProvider` picks `DeviceAppRepository` when the
channel answers AND device mode is on; otherwise the honest demo set. A
bridge failure on a real device shows a loud banner with retry — never a
silent fallback. Package broadcasts → channel event → index reload.

**Widgets.** Real Android widgets: picker lists every provider →
`allocateAppWidgetId` + `bindAppWidgetIdIfAllowed` (needs the HOME role) →
platform view (`toad-widget-host`, hybrid composition) → placements persist
in SharedPreferences; removal releases the id; resize pushes size options
to the view.

**Updates (SEC-02/03/04).** checkLatestRelease (via system
DownloadManager — no INTERNET permission) → verify the detached ECDSA
signature over `tagName|sha256|assetName` → banner only if valid → download
to the app-private dir → SHA-256 gate → APK signer-certificate gate →
system installer. Policy-throttled (daily default); stale files swept.

**Crash safety (REL-01).** `main.dart` installs the crash ledger, reads the
verdict (≥ 3 crashing boots in 5 minutes) and either runs the normal app
inside a guarded zone or the safe mode screen (own minimal UI, four exits).

**The clock (CLOCK).** `clockProvider` ticks every 5 s (self-heals time and
timezone changes within one tick — PLT-13). `HeroClockFace` renders one of
four faces (hand · analog · word · flip) using the 12/24-hour setting; the
hero zone and the placed clock widget share the same engine.

**Signing/CI.** CI restores keystores from secrets, signs with the v3
rotation lineage (`android/toad-lineage.bin`), verifies certificates +
lineage rollback=false, runs the merged-manifest permission allow-list gate
(PRV-01), and attaches `.sha256` + `.sig` to releases. See SECURITY.md.

## Testing

133 Dart tests: bridge contract (mock channel), update security (signature
gate, throttle, version compare), clocks (formats, phrases, settings),
crash guard (verdict logic, ledger), widget hosting, package events,
notification counts, banner honesty, settings round-trips, skins. Device /
emulator-level tests are the known gap (roadmap TST-01) — the native
adapter's flows are exercised manually per release until that matrix lands.
