# Launcher engineering research: VoltageOS Launcher3 vs toadLAUNCHER

**Reviewed:** 25 November 2026  
**Scope:** Source-level comparison and recommendations. This is a research/roadmap document, not a performance benchmark or code audit of every Android edge case.

## Why this comparison

VoltageOS Launcher3 is a mature native launcher based on AOSP Launcher3, while toadLAUNCHER is Flutter-first with a Kotlin Android adapter. The useful goal is to borrow proven Android launcher engineering patterns without sacrificing toadLAUNCHER's design identity.

## Latest toadLAUNCHER commits reviewed first

The latest repository commits at review time were read before drafting this comparison:

- `71e4574` — settings-hub test now mocks the platform channel correctly and scrolls back to the header; reported local validation: analyzer clean, 106/106 tests.
- `48b099c` — release prep for 1.0.0, version fallback synchronized, UI tests updated for v0.12 layout, release/install copy updated.
- `f88a217` — fixed analyzer/build errors in battery monitor, permissions, todo store, battery page and settings hub.
- `e541734` — in-app update flow fixes: private update destination, system installer content URI handoff, streaming SHA-256, separate update executor, metered-network handling, release asset fallback and version comparison.
- `36520a9` — v0.12 features: permission ask flows, intro, toadLIST, battery drain history and low-battery calm.
- `476348c` — Kotlin/API 37 build fixes and manifest/service export corrections.
- `4c70a6e` — v0.11 launcher infrastructure: real AppWidgetHost, package-change refresh, default-home role, shade/lock/share actions, notification dots, app shortcuts.
- `0ee349a` — API 37 widget-provider ComponentName compatibility fix.

**Current baseline:** source reports version `1.0.0+43`. The README's status/install sections still contain older v0.12/v0.11 wording, so documentation drift is a clear follow-up.

Commit links:
- https://github.com/dukeoftoad/toadLAUNCHER/commit/71e4574b23c28b458ddcf7b4e39eb5a52df792d4
- https://github.com/dukeoftoad/toadLAUNCHER/commit/48b099cd6f7eece5db3177cf0214eeb8926a4445
- https://github.com/dukeoftoad/toadLAUNCHER/commit/f88a21784dd7effdf951d3e6d89f51154d5d2239
- https://github.com/dukeoftoad/toadLAUNCHER/commit/e541734084f5d7cb2def945e7e89e7b19d0f9426
- https://github.com/dukeoftoad/toadLAUNCHER/commit/36520a9d523f7dc49fdbedf426d09c4294155050
- https://github.com/dukeoftoad/toadLAUNCHER/commit/476348c91be57ccb37f3313991c299869066f849
- https://github.com/dukeoftoad/toadLAUNCHER/commit/4c70a6e506acb992a360d87eb59ce70e5223d682
- https://github.com/dukeoftoad/toadLAUNCHER/commit/0ee349a753bd90334040eb4b39995ed546344b2e

## Technology stack

| Area | VoltageOS Launcher3 | toadLAUNCHER |
|---|---|---|
| UI | Native Android Views | Flutter |
| Languages | Java/Kotlin | Dart + Kotlin adapter |
| Workspace/model | Launcher model, loader, database/cache infrastructure | Riverpod, Dart layout/model state |
| App discovery | Android launcher APIs/model | Android PackageManager/bridge, Dart app model |
| Widgets | Native AppWidgetHost/HostView integration | Native host views embedded in Flutter |
| UI customisation | Launcher3 + ROM-specific changes | Custom themes, sketchbook/pond visual style |
| Target role | ROM-integrated launcher | Standalone Android launcher app |

VoltageOS source: https://github.com/VoltageOS/packages_apps_Launcher3  
toadLAUNCHER source: https://github.com/dukeoftoad/toadLAUNCHER

## Feature comparison

| Capability | VoltageOS Launcher3 | toadLAUNCHER (current repo/release notes) |
|---|---|---|
| Home workspace and dock | Mature native workspace/hotseat | Flutter home pages and dock |
| Drawer/search | Native launcher drawer/search | A–Z drawer and search |
| Folders | Native folder behavior | Flutter folders/rename |
| App icons | Native cache and loading | Android icons bridged/rasterized for Flutter |
| Android widgets | Mature native widget host/lifecycle/interaction | AppWidgetHost with native views embedded in Flutter |
| Local widgets | Native ecosystem integration | Clock, calendar, Memories, toadLIST note |
| Shortcuts | Native launcher shortcuts | LauncherApps shortcut integration |
| Notification indicators | Native launcher/ROM integration | Opt-in listener and package counts |
| Work/profile handling | Native launcher model support | Feature parity not yet established in this review |
| Visual freedom | Native/Material and ROM settings | High; original themes, animation and custom rendering |
| System integration | Direct Android framework/ROM integration | Kotlin adapter and public/restricted system interfaces |

VoltageOS release notes include Launcher3 customisations such as Smart Dock, workspace style choices, icon/dock options and launcher fixes. Confirm that each ROM release feature belongs to Launcher3 before attributing it to the launcher; many VoltageOS features are system-wide.

## What to learn from Launcher3

### 1. App model, refresh and caching

Launcher3 has a dedicated model/loader architecture rather than treating every refresh as a complete UI reconstruction. Its model and cache layers are designed to coordinate workspace items, apps, icons, shortcuts and widgets.

**Recommended direction for toadLAUNCHER:** keep the Flutter-facing model, but make the Android app index more incremental and component-aware:
- identify apps by launchable component, not only package name;
- cache icon/label data and invalidate it on package changes;
- process install/update/remove events for only the affected package when practical;
- preserve profile/user identity if work profiles are added;
- avoid blocking UI rebuilds during app discovery.

Reference source:
- https://github.com/VoltageOS/packages_apps_Launcher3/tree/17/src/com/android/launcher3/model
- https://github.com/VoltageOS/packages_apps_Launcher3/blob/17/src/com/android/launcher3/LauncherModel.kt

### 2. Native widget lifecycle and failure handling

Launcher3's dedicated widget holder/host/view classes illustrate how much lifecycle and interaction work surrounds Android widgets.

toadLAUNCHER already has real AppWidgetHost allocation, binding, ID persistence and Android platform views. This is an important achievement; do not replace it with fake previews.

**Recommended follow-up checklist:**
- provider configuration activity support;
- explicit handling for denied binding permission (system bind flow);
- recovery when providers/apps are removed or widget IDs become invalid;
- resize/minimum-size/host options compatibility;
- lifecycle behavior when Home role changes or app is backgrounded;
- verify hosted-widget undo/restore does not revive a deleted/stale host ID;
- tests for widget add/configure/resize/remove/restart/recovery on a real device.

References:
- https://developer.android.com/develop/ui/views/appwidgets/host
- https://github.com/VoltageOS/packages_apps_Launcher3/tree/17/src/com/android/launcher3/widget

These are engineering follow-ups and test recommendations—not assertions that every listed item is currently broken.

### 3. Workspace persistence and interaction

The native workspace has a long-established interaction model for dragging, snapping, folders, shortcuts and widgets. Use it as a reference for edge cases (drag across pages, folder interactions, widget resizing, accessibility, restoring state), but preserve the toadLAUNCHER interaction design and Flutter rendering.

## Current toadLAUNCHER-specific opportunities

### Confirmed from current source
- The clock provider emits every five seconds. If the UI only needs minute precision, minute-aligned updates could reduce avoidable rebuild/wakeup activity.
- The battery system is now implemented: Android battery broadcasts, local persisted samples, unplugged-span drain-rate calculation, runtime estimate and low-battery calm. Earlier claims that battery monitoring was absent are obsolete.
- The update flow was recently repaired in commit `e541734`; do not carry forward the earlier suspected DownloadManager/installer failure without retesting the latest implementation.
- The recent commits report analyzer-clean and 106 passing tests. Treat that as commit-reported validation, not an independently rerun test suite in this research.

### Follow-up questions to validate
- How much app-index work and icon rasterisation occurs on cold launch versus package-event refresh?
- Are only clock/time-sensitive widget tiles subscribing to the five-second provider?
- Is the ambient animation completely paused when invisible/screen-off, and is its battery-saver state sourced from the OS?
- Are all real widget lifecycle cases covered by integration tests, including provider configuration and permission denial?
- Do notification counts remain correct on notification update/repost/clear behavior?
- Is work-profile app discovery/launch intentionally unsupported, or is it a missing feature?
- Does README/install/release documentation accurately match the 1.0.0 source and workflow?

## Size, RAM, CPU and battery: what is not known

No APK size, RAM, CPU, launch latency or idle-battery comparison was performed. Repository storage size is not installed APK size and must not be used as a proxy.

Flutter has runtime overhead relative to a native-only launcher, but framework choice alone does not prove higher battery drain in actual use. The workload—animations, app-index work, icon rendering, widget updates, rebuild frequency and lifecycle behavior—matters.

**Suggested repeatable device benchmark (same phone/settings):**
1. Clean start, record cold-start-to-home-ready time.
2. Measure RAM after settling, with identical apps/widgets.
3. Idle on home for 60 minutes with screen on, same brightness and wallpaper.
4. Repeat idle with screen off/background.
5. Open drawer, search, scroll and launch apps; record frame smoothness and CPU.
6. Compare widget-heavy homes and ambient animations on/off.
7. Repeat each test several times and report medians, not a single run.

## Roadmap

### P0 — correctness and release confidence
- Validate widget configuration and binding-permission flows.
- Test widget ID persistence/reconciliation, removal/undo, provider removal and restore.
- Validate notification count semantics for updates/reposts/ongoing notifications.
- Test update download, checksum and install handoff across Android versions/OEMs.
- Ensure the version/install/release documentation matches current 1.0.0 source.

### P1 — model quality and native integration
- Improve app indexing/caching/incremental package updates.
- Component/profile-aware app model if work-profile support is desired.
- Strengthen widget sizing, configuration, lifecycle and error recovery.
- Add device integration tests for launcher role, widgets and shortcuts.

### P2 — idle efficiency and polish
- Align the clock ticker to minute boundaries (unless second-level display is needed).
- Isolate time-dependent UI subscriptions.
- Measure and tune animations/rebuilds rather than assuming they're expensive.
- Confirm battery guard reflects real Android battery-saver state and clearly labels demo state.

### P3 — feature parity decisions
Only implement native-launcher features when they fit toadLAUNCHER's goals: work profiles, additional shortcut affordances, more robust drag/drop and accessibility. Avoid copying ROM-only settings or adding complexity just for parity.

## Conclusion

**Keep Flutter as the product UI; strengthen the Android foundation.** VoltageOS Launcher3 is a reference for model/cache design, native widget lifecycle, workspace edge cases and system integration—not a visual target. toadLAUNCHER's unique themes, local widgets and custom pond/sketchbook experience are differentiators.

The highest-value next work is test coverage and reliability of Android integration, followed by app-model/cache improvements and measured idle-performance optimisation. Benchmark results should be collected on hardware before making size, RAM or battery claims.
