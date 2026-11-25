# toadLAUNCHER — Owner Decisions (roadmap.md §10)

Acting owner: Rock (via agent session, 2026-11-25). Each decision is reversible and
recorded here so future sessions don't re-guess. Veto anything by editing this file.

| # | Question | Decision |
|---|---|---|
| 1 | Free-form grid (icons+widgets share cells) vs current paged/stack model? | **Free-form grid is the Phase 2 target** (FEAT-01), but the current widget-stack model is deliberate for v1.x — it is what the approved design proposal specifies. Not a bug; scheduled work. |
| 2 | Raise minSdk above 26? | **Keep minSdk 26.** No raise. The 8.x user base is small but the cost of staying is bounded (guards already exist for API-28+ lock, API-29+ roles). |
| 3 | Accept breaking in-place updates for Android 8.x during key rotation (SEC-01)? | **Accept.** v3 proof-of-rotation lineage lets Android 9+ update in place; Android 8.x reinstalls once. Documented in the release notes and README. |
| 4 | Will this ever go to Google Play? | **No — sideload-only via GitHub Releases** (it is what enables QUERY_ALL_PACKAGES + the self-updater + accessibility service without Play policy friction). Revisit only if the family strategy changes. |
| 5 | Is "no INTERNET" absolute? | **Absolute for the launcher itself, forever.** No optional networked companion is planned; weather/online search stay out of scope. |
| 6 | Notification text "peek"? | **Keep "package names only" — invariant, not relaxable.** Dots and counts only; never titles or text. |
| 7 | License + contributions? | **MIT** (permissive, matches the README's open ethos; the pond stays hand-made either way). Contributions accepted via issues/PRs — triaged by the owner. |
| 8 | Priority: icon packs vs tablet vs Focus tools? | **Focus tools (FEAT-10) first**, then icon packs (FEAT-04), tablet last (PLT-11) — matches the "calm launcher" identity; polish follows substance. |
| 9 | Whimsical copy stays default? | **Stays default.** The plain-microcopy toggle (UX-03) is a Phase 3 nicety, not a promise. |
| 10 | Quality budgets (§7)? | **Confirmed as written** (≤500 ms cold start target, 95 % frame pacing, ~0 % idle cost, CI-enforced no-INTERNET, crash-loop safe mode acceptance). Measurements land in docs/PERF.md from Phase 1 on. |

## Additional standing decisions made this session

- **SEC-01 executed**: new 4096-bit RSA release key (CI secrets only), v3
  rotation lineage `android/toad-lineage.bin` with **rollback revoked for
  the old key** (verified: `apksigner lineage --print-certs` shows
  `Has rollback capability: false` for signer #1), keystore/properties
  removed from the working tree and gitignored, fingerprints published in
  SECURITY.md, and Settings → About displays the installed certificate.
  **Git history rewrite deferred** — the exact purge procedure is in
  SECURITY.md for a future owner-run pass (it invalidates every clone).
  Fingerprints: old `6AE99F0B…702A`, new `5FDADDE0…C6B6`.
- **SEC-02 executed**: ECDSA P-256 update-signing key pair (private in CI
  secrets, public embedded in `MainActivity.kt` + SECURITY.md). CI attaches
  a detached `.sig` over `tagName|sha256|assetName`. The updater refuses
  unsigned/tampered releases before any banner; the APK's signer
  certificate is checked at install time against the two known keys.
- **Enforcement floor**: releases from v1.1.0 on **must** carry the `.sig`; older
  releases simply won't be offered to the new updater (they're older — the version
  compare handles that).
- **Strings/i18n**: Phase 0–1 keep English hand-written copy (no l10n infra yet —
  I18N-01 is Phase 2). New user-visible strings stay few and centralized.
- **Update policy default** (SEC-04): **Daily** silent check with a persisted
  24-hour throttle (was: every process start). Manual check always available.
  Pre-releases can't appear: GitHub's `/releases/latest` endpoint only returns full
  releases.
- **PR #1 (BLD-07)**: close — net-zero diff, research content preserved in its
  description.

## What this session ships (Phase 0 + CLOCK)

SEC-01, SEC-02, SEC-03 (sweep), SEC-04, PLT-01, REL-01, PRV-01, BLD-01, BLD-02,
BLD-07, NEW-01; CLOCK = hero clock styles (hand · analog · word · flip), 12/24 h
setting (follow-system default), PLT-13 hardening; plus PLT-06 (pinned shortcuts
query) and PLT-07 (widget size options on resize) as low-cost correctness fixes.
