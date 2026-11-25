# toadLAUNCHER

Part of the toad family (with toadGALLERY and toadPLAYER). Hand-made, calm,
instant — an Android home-screen launcher with no ads, no analytics and **no
network permission at all**.

**Current release: v1.2.0** (see [CHANGELOG.md](CHANGELOG.md) — `pubspec.yaml`
is the single source of truth for the version).

- Calm by default: a hand-drawn sketchbook (or a living pond) instead of a
  glass slab; a hero clock with four faces; honest, undoable edit mode.
- A real launcher: AppWidgetHost widget hosting, notification dots, app
  shortcuts, the notification shade, double-tap sleep — each asks for its
  access calmly, at the moment of use, and degrades honestly when refused.
- Offline-first forever: the app index, settings, todos and battery history
  live on the device; update checks ride the system download service so the
  launcher itself never needs the INTERNET permission.
- Self-updating, safely: releases are signature-verified end-to-end (see
  [SECURITY.md](SECURITY.md)); a crash-loop safe mode keeps the phone usable
  even if the pond has a very bad day.

## Install

Grab `toadlauncher-v1.2.0-universal-install.apk` from the
[latest release](https://github.com/dukeoftoad/toadLAUNCHER/releases/latest)
(universal — every architecture).

1. **Updating from v1.1.0 or older**: installs right over it on
   **Android 9+** — the signing key rotated with an APK Signature Scheme v3
   lineage. **Android 8.x** reinstalls once (same app, new key; your layout
   and settings survive via Android's backup or re-setup).
2. Allow *Install unknown apps* for your browser/file manager when asked
   (sideload-only app).
3. Requires **Android 8.0+** (minSdk 26); the lock gesture needs
   **Android 9+**.
4. Press Home → choose **toadLAUNCHER** (or tap *make Home* on the banner).
5. Optional integrity check: the release ships `.sha256` and a `.sig`
   signature — [SECURITY.md](SECURITY.md) explains both.

Updates arrive in-app (Settings → Device & updates, at most once per the
update policy you choose) and are verified before anything is offered.

## Permissions, plainly

| Permission | Why | Ask? |
|---|---|---|
| `QUERY_ALL_PACKAGES` | build the local app index | never — silent, sideload-only app |
| `SET_WALLPAPER` | wallpaper & style | never |
| `REQUEST_DELETE_PACKAGES` | real uninstall via system dialog | never — system confirms |
| `REQUEST_INSTALL_PACKAGES` | self-update through the system installer | system dialog at install time |
| `PACKAGE_USAGE_STATS` | usage-based recents (opt-in) | only if you flip the switch |
| Notification access | real dots (opt-in) | calmly, from settings — package counts only, never text |
| Accessibility (lock) | double-tap sleep, shade fallback, screenshot (opt-in) | calmly, at first use |
| `INTERNET` | — | **never. not now, not ever** — CI-enforced |

## Privacy

Everything is local: no analytics, no telemetry, no crash upload (the crash
ledger stays on the device until *you* share it), no network permission.
The launcher reads app labels/icons, your settings, your toadLIST and
battery samples — nothing else, and nothing leaves the phone. The only
network activity is the update check/download, performed by the **system**
DownloadManager under your control.

## Build & develop

```bash
flutter pub get
flutter analyze   # zero issues
flutter test      # 133 tests — bridge contract, update security, clocks,
                  # crash guard, widget hosting, package events, banners
flutter run       # demo mode: the proposal's app set, no device needed
```

Building a release APK locally: `flutter build apk --release` (unsigned or
locally-keyed); CI signs with the rotation lineage — see below. No Android
SDK? Push to GitHub and let the workflow build.

### Signing (CI)

No key material lives in this repo. CI restores the release keystore from
GitHub Actions secrets and signs with an APK Signature Scheme v3
proof-of-rotation lineage:

- `android/toad-lineage.bin` — the public rotation lineage (also embedded
  in every signed APK),
- the retired v0.9–v1.0 key covers v2 (Android 8 keeps updating),
- the current key covers v3 for Android 9+, with rollback revoked for the
  old key.

Fingerprints, verification instructions and the update-signing key live in
[SECURITY.md](SECURITY.md). Never commit secrets; never `git add -A` a
release — tag a clean tree instead.

### Release process

```bash
# 1. bump version in pubspec.yaml, update CHANGELOG.md
git checkout main && git pull
git add <specific files> && git commit -m "release: v1.2.0"
git tag v1.2.0
git push origin main --tags
```

CI runs analyze → tests → manifest permission gate → build, then (on the
tag) signs, verifies the lineage, generates `.sha256` + `.sig` and
publishes the GitHub Release.

## Documentation

- [CHANGELOG.md](CHANGELOG.md) — what shipped, version by version
- [SECURITY.md](SECURITY.md) — trust anchors, fingerprints, reporting
- [docs/verification-report.md](docs/verification-report.md) — the audit
  verification pass (finding-by-finding evidence)
- [docs/DECISIONS.md](docs/DECISIONS.md) — owner decisions on the roadmap's
  open questions
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the pieces fit

## Skins

- **Light Sketchbook** `#F7F1E6` paper, toad-green accent
- **Dark Night sketchbook** `#171613`, light-toad accent `#93C46D`
- **AMOLED** true black, deepest hairlines
- **Pond Pro** (opt-in) — living water scene, resident toad, lily-pad app
  grid, log dock. Day/night follows the clock (sunset 19:30 / sunrise 6:30
  anchors), never location.

All tokens live in `lib/core/theme/toad_tokens.dart` — one source of truth,
transcribed 1:1 from the design proposal.

## Product invariants

- No `INTERNET` permission, ever (CI-enforced allow-list).
- No analytics, no telemetry, no crash upload — diagnostics stay on-device.
- Remove is not uninstall; destructive actions confirm.
- Honest degradation: every gated feature asks calmly, explains why, and
  degrades visibly when refused. Demo mode never pretends to be device mode.
- Opt-in services (lock, notification dots) request the minimum: the lock
  service watches nothing, the dots service reads package names only.
- Kotlin stays a thin OS adapter; decisions live in Dart.
- Pond ambient animations pause when invisible, on battery saver, or when
  Calm-pond is on.

## Contributing

Issues and PRs are welcome (MIT — see [LICENSE](LICENSE)). Read
[SECURITY.md](SECURITY.md) before touching anything update- or
signature-related, and keep the invariants above intact.

> Hand-made in the pond. 🐸
