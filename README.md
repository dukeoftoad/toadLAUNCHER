# toadLAUNCHER

Part of the toad family (with toadGALLERY and toadPLAYER). Hand-made, calm,
instant — an Android home-screen launcher with no ads, no analytics and **no
network permission at all**.

Built from the approved UI/UX design proposal v1.1 (14 mockups, 4 themes).

## Status — Stage 1 of 4 complete

| Stage | Scope | State |
|---|---|---|
| 1 (M1) | Theme engine (4 skins), home screen, hero clock, memories card, app grid, page dots, dock, static Pond home | **done** |
| 2 (M2a) | A–Z drawer + search + recents, folders (shared-axis open), long-press menus | pending |
| 3 (M2b/M3) | Edit mode with honest snapping, widget picker, wallpaper & style, settings hub + gestures, motion polish | pending |
| 4 (M4) | Pond ambient loop (ripple/blink/croak/hop/flyby/fireflies/rain), mouth drawer, Calm-pond + battery guards | pending |

## Verify locally

```bash
flutter analyze   # zero issues
flutter test      # 31 tests
flutter run       # demo mode: the proposal's app set, no device needed
```

## Build an APK without a local Android SDK

Push this folder to a GitHub repository and let the included workflow build
it:

1. `git init && git add . && git commit -m "toadLAUNCHER stage 1"`
2. Create a GitHub repo, add it as origin and push.
3. The workflow (`.github/workflows/ci.yml`) runs analyze → test → release
   build and uploads `toadlauncher-release-apk` as an artifact.
4. To push from a machine without stored credentials, create a fine-grained
   PAT (repo: contents read/write) and use:
   `git remote add origin https://<TOKEN>@github.com/<user>/<repo>.git`

## Skins

- **Light Sketchbook** `#F7F1E6` paper, toad-green accent
- **Dark Night sketchbook** `#171613`, light-toad accent `#93C46D`
- **AMOLED** true black, deepest hairlines
- **Pond Pro** (opt-in) — living water scene, resident toad, lily-pad app
  grid, log dock. Day/night follows the clock (sunset 19:30 / sunrise 6:30
  anchors), never location.

All tokens live in `lib/core/theme/toad_tokens.dart` — one source of truth,
transcribed 1:1 from the design proposal (colours, radii, motion timings).

## Product invariants

- No `INTERNET` permission, ever. Fonts are bundled TTFs (Caveat, Patrick
  Hand, Inter) — no runtime font fetch.
- Remove is not uninstall; destructive actions confirm.
- App index renders locally; demo mode ships the proposal's demo app set
  behind the `AppRepository` seam (device-backed implementation lands in a
  later stage).
- Pond ambient animations pause when invisible, on battery saver, or when
  Calm-pond is on (stage 4).
