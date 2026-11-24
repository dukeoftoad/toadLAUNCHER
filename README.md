# toadLAUNCHER

Part of the toad family (with toadGALLERY and toadPLAYER). Hand-made, calm,
instant — an Android home-screen launcher with no ads, no analytics and **no
network permission at all**.

Built from the approved UI/UX design proposal v1.1 (14 mockups, 4 themes).

## Status — v0.11.0-beta (the launcher infrastructure release)

v0.10 wired the launcher to the phone; v0.11 closes the gap between "a
Flutter app shaped like a home screen" and "a real launcher". Every item on
the completeness checklist below is now real Android integration:

- **Default Home, verified** — Settings → *Device & updates* shows the HOME
  role status, and a calm, dismissable, gesture-transparent banner offers
  *make Home* (system role dialog) whenever toadLAUNCHER isn't the actual
  Home app. Widgets and shortcuts key off this role — as Android intends.
- **Device mode, fixed and loud** — v0.10's bridge provider shipped a
  permanently null channel (device mode could never engage; the phone
  silently showed demo apps). Fixed: the real channel is wired on Android.
  If the bridge ever stops answering on a real phone, a banner now says why
  demo apps are showing, with a retry — never a silent fallback.
- **Real widget hosting (AppWidgetHost)** — the picker lists **every**
  widget provider on the phone (live previews from the providers).
  *Add* allocates an id from the launcher's own `AppWidgetHost`, binds it
  (allowed for the default Home app), and lands it on the page — rendered
  through hybrid-composition platform views, live-updating and
  touch-reactive like a stock launcher. Placements persist across
  restarts; removal releases the id. The family section (system-confirmed
  pinning) stays.
- **Real gestures** — swipe down pulls the **actual notification shade**
  (status-bar expand call); double-tap locks the screen through a
  minimal accessibility service (opt-in, one deep-linked toggle, retrieves
  no window content); long-press *Share* opens the real share sheet.
- **Live app index** — installs, updates and removals refresh the index
  immediately (package broadcast → channel → reload), and the index also
  refreshes on resume.
- **Notification dots, real** — opt-in Notification access feeds live
  per-package counts from a `NotificationListenerService` (package names
  only — never titles or text). Dots follow the *Notification dots*
  switch; *Badges* upgrades the dot to a written count.
- **App shortcuts** — long-press menus list each app's real dynamic
  shortcuts (LauncherApps) and start them; empty unless we are Home,
  which Android enforces and the menu respects.
- **Auto-update, toadFILES flow, zero INTERNET** — one silent check per
  process against `github.com/dukeoftoad/toadLAUNCHER/releases/latest`, a
  slim dismissable home banner, DownloadManager download with live
  progress, a SHA-256 gate, then the system installer. The download runs
  in the **system's process** — the launcher itself still holds **no
  INTERNET permission**.
- **Kotlin budget: one adapter file + two tiny services.**
  `MainActivity.kt` is a pure OS adapter — every decision (index, family
  registry, update state machine, version compare, settings, persistence,
  widget placements) is Flutter/Dart. `ToadLockService` (screen lock) and
  `ToadNotificationListener` (dots) are opt-in system hooks, not adapters.
  CI runs on **target/compile SDK 37**.

| Stage | Scope | State |
|---|---|---|
| 1 (M1) | Theme engine (4 skins), home screen, hero clock, memories card, app grid, page dots, dock, static Pond home | **done** |
| 2 (M2a) | A–Z drawer + search + recents, folders (shared-axis open, inline rename), long-press menus with two-step uninstall | **done** |
| 3 (M2b/M3) | Edit mode with honest snapping, widget picker, wallpaper & style, settings hub + gestures | **done** |
| 4 (M4) | Pond ambient loop, mouth drawer, Calm-pond + battery guard | **done** |
| 5 (v0.10) | Device mode, real permissions, toad family theming, auto-update, API 37 | **done** |
| 6 (v0.11) | Launcher infrastructure: default-home verification, AppWidgetHost hosting, live index, shade + lock + share, notification dots, app shortcuts, honest fallback | **done** |

## Stage 6 walkthrough (the launcher infrastructure)

- **Make it Home, honestly** — the *Default home screen* row states the
  role plainly ("toadLAUNCHER is your Home…" / "Another app is Home…"),
  and the home banner offers the one-tap fix. The banner never swallows
  gestures: taps and swipes pass through its paper; only its pills react.
- **The widget shelf** — picker section *real Android widgets — live from
  this phone*: provider previews, honest `provider/package` captions, and
  the rule spelled out ("real widgets need toadLAUNCHER as your Home —
  Android binds them to the Home app"). When not Home, *add* opens the
  system role dialog instead of pretending. Hosted widgets live in the
  same widget stack as the local engines: same edit mode, same move
  gestures, same undoable toasts; their `AppWidgetHost` ids survive
  restarts (the OS keeps the binding until we delete the id).
- **Dots that mean something** — grant Notification access once (the
  exact settings toggle opens from *Notifications* settings); every
  active notification lights a dot on that app's icon, everywhere icons
  render. Ongoing (persistent) notifications never count — chips are not
  news. Counts die with the process and re-seed from the live shade on
  reconnect.
- **The lock service** — smallest legal accessibility footprint
  (`canRetrieveWindowContent=false`, no event subscriptions, no
  feedback channels): it exists to perform the API 28+ screen-lock global
  action. Double-tap then locks; if the service is off, the toast says so
  and the Accessibility settings open pre-targeted at the component.

## Stage 4 walkthrough (the pond comes alive)

- **Ambient loop** — one shared clock, repaint-only (no widget rebuilds):
  ripple idle (4.4 s, 3 concurrent), rising bubbles, pad bob (4.8 s,
  phase-offset), toad bob (5.4 s, slower asleep), reed sway (5.6 s, ±1.7°),
  blink (two-frame 180 ms, random 5–8 s), glitter shimmer, the dragonfly
  flyby (every 45–90 s · 2.4 s crossing with a mid-air hover), night
  fireflies (5 dots, 7.5 s drift + 2.3 s flicker), and the manual rain
  shower (1.1 s drops, ripple density ×3, sky dim). Ripple amplitude halves
  at night — "the pond is quieter when you are". Day→night crossfades over
  2 s on the clock anchors.
- **The resident** — blinks on schedule; tap him and he croaks (900 ms
  throat puff + floating ♪); at night he sleeps with drifting z's, and
  tapping him wakes him with a grumpy, flat-mouthed croak. Long-pressing a
  pad hops (320 ms arc with squash-and-stretch).
- **The mouth drawer** (screen 13) — swiping up on the pond, the drawer is
  the toad: bulging eyes peek over the jaw and blink while you browse, the
  tongue is the search bar ("what fly do you seek?"), a 4-column showcase
  grid scrolls inside the deep-moss interior, and the A–Z rail hugs the
  jaw's right edge. It tracks your finger 0→100%; release below 40% and it
  swallows shut (260 ms) with a gulp bounce and a satisfied blink; pull
  past the top and it hiccups a bubble.
- **Calm pond + battery guard** — Calm-pond (or an active battery saver on
  device) falls night instantly and freezes the whole loop into a still
  painting — zero animation cost.

## Stage 3 walkthrough

- **Edit mode** (screen 7) — long-press → *Edit home screen*, or pinch-in.
  Faint grid lines (12% ink) show the real 4-column cells; the selected
  widget wears a dashed toad-green outline with four corner handles; pulling
  a corner resizes between 2x1 and 4x4 and **the clock re-renders live at
  every size** (persisted). The hint bubble teaches once, then never again
  (persisted dismiss). Bottom strip: Wallpapers · Widgets · Settings; the
  Done pill (or back) exits, and every action ends with an undoable toast.
- **Widget picker** (screen 8) — bottom sheet with real mini-previews (the
  same engines as the placed widgets, never stock images). toadGALLERY's
  Memories strip is the featured first citizen; the Caveat clock, a real
  month calendar (4x4, local only) and a Patrick Hand sticky note round out
  the set — and, since v0.11, every real widget provider on the phone.
  Placed kinds stay tappable and explain themselves calmly; picking
  drops you straight into edit mode with the widget attached — drag it onto
  home and it snaps into the page's widget stack.
- **Wallpaper & style** (screen 9) — bundled sketchbook papers (user photos
  import via SAF in device mode), Auto/Light/Dark/AMOLED segmented control,
  six accent stickers with instant re-tint, squircle/circle/rounded icon
  shapes, and the Pond Pro switch. Everything offline; papers ship inside
  the APK.
- **Settings hub** (screen 10) — hub-plus-pages with honest subtitles that
  compose themselves from live settings. The gestures sub-page mirrors the
  mockup: swipe-up drawer, double-tap sleep, swipe-down shade, two-finger
  screenshot (off — Android 11+ restricts the global action for
  accessibility services, so it stays a demo-honest gesture), pinch for
  edit mode, dock-area swipe for search (off). Switches apply live, no
  save button.
- **Gesture map** (screen 11) — tap icon launches; tap the clock opens
  Clock; swipe up drawer; swipe down pulls the real shade (device) or says
  so honestly (demo); pinch edit mode; double-tap locks (device, opt-in
  service) or says so (demo); dock-area swipe opens search.

## Stage 2 walkthrough

- **Drawer** — swipe up anywhere (or tap the dock chevron / the log's APPS
  handle). Frosted-paper sheet over the home: sticky search pill, recents row
  (last 4 launches, updated live), Caveat-lettered A–Z index, local badges.
  Search filters instantly; swipe-down on the header, back, or Esc closes.
- **Folders** — page 2 leads with the *Media* tile (2x2 mini preview). Tapping
  opens the card with 240 ms shared-axis motion from the tile's rect over a
  dimmed, 6 px-blurred home. Tap the Caveat title to rename inline; more than
  9 apps paginate with home-style dots.
- **Long-press menus** — icons raise a 180 ms scale-in popover beside them
  (app shortcuts · app info / widgets / share / remove / uninstall…). Share
  opens the real chooser in device mode. Remove takes the icon off that page
  only; Uninstall is danger-colored and always asks twice. Empty space shows
  the smaller trio: Wallpaper & style · Widgets · Home settings. Device-only
  actions say so honestly — demo mode never pretends.

## Install the beta (signed APK)

Grab `toadlauncher-v0.11.0-beta-universal-install.apk` from the **v0.11.0-beta
Release** page (or the `toadlauncher-release-apk` artifact of any run).

1. Updates from v0.9.0-beta or later install straight over — same signing
   key since the v0.9.0-beta fix. (Builds *older* than v0.9.0-beta were
   signed with a random per-run debug keystore and must be uninstalled
   once.)
2. Allow *Install unknown apps* for your file manager / browser when asked.
3. Requires **Android 8.0+** (minSdk 26); the lock gesture needs **Android
   9+**. The APK is universal — every ABI.
4. After install: Home → default launcher → **toadLAUNCHER** (or tap
   *make Home* in the banner).
5. Verify integrity (optional): the release ships a `.sha256` alongside the
   APK.

## Permissions, plainly

| Permission | Why | Ask? |
|---|---|---|
| `QUERY_ALL_PACKAGES` | build the local app index | never — silent, sideload-only app |
| `SET_WALLPAPER` | wallpaper & style | never |
| `REQUEST_DELETE_PACKAGES` | real uninstall via system dialog | never — system confirms |
| `REQUEST_INSTALL_PACKAGES` | self-update through the system installer | system dialog at install time |
| `PACKAGE_USAGE_STATS` | usage-based recents (opt-in) | only if you flip the switch |
| Notification access | real dots (opt-in) | only from Notifications settings |
| Accessibility (lock) | double-tap sleep (opt-in) | only on first lock attempt |
| `INTERNET` | — | **never. not now, not ever** |

## Signing

`android/app/toad-release.jks` + `android/key.properties` are **committed on
purpose**: this is a personal, sideload-only project, and a fixed key is what
makes updates installable. Alias `toadrelease`, passwords `toadlauncher`.
Rotating the key means users must uninstall first — don't do it lightly.
(If this repo ever goes public-wide, move the keystore to GitHub Secrets and
strip it from history.)

## Release process

```bash
git add -A && git commit -m "release: v0.11.0-beta"
git tag v0.11.0-beta
git push origin main --tags
```

CI runs analyze → test → signed universal APK, then publishes a GitHub
Release named `toadLAUNCHER v0.11.0-beta` with the APK + sha256 attached.

## Verify locally

```bash
flutter analyze   # zero issues
flutter test      # 106 tests — incl. bridge contract, widget hosting,
                  # package events, notification counts, banner honesty
flutter run       # demo mode: the proposal's app set, no device needed
```

## Build an APK without a local Android SDK

1. Push this folder to a GitHub repository and let the included workflow build
   it (see *Release process* above, or just push `main` for a check run).
2. The workflow (`.github/workflows/ci.yml`) runs analyze → test → signed
   release build and uploads `toadlauncher-release-apk` as an artifact.
3. To push from a machine without stored credentials, create a fine-grained
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
  Hand, Inter) — no runtime font fetch; update checks ride the system
  download service.
- Remove is not uninstall; destructive actions confirm.
- The app index renders locally. Device mode is real (package manager) and
  demo mode is the honest fallback — when a real phone's bridge fails, a
  banner says so; a pure non-Android surface stays quietly demo.
- Real widgets are hosted, not drawn: the AppWidgetHost owns ids and views;
  placements persist; removal releases the id.
- Opt-in services (lock, notification dots) request the minimum: the lock
  service watches nothing, the dots service reads package names only.
- Pond ambient animations pause when invisible, on battery saver, or when
  Calm-pond is on.
