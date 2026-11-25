# Security policy

## Reporting

Open a private security advisory on GitHub (Security → Report a
vulnerability), or an issue tagged `security`. The pond is small and
hand-made — reports are read and answered.

## Trust anchors

toadLAUNCHER is **sideload-only** (GitHub Releases) and holds **no INTERNET
permission — ever** (CI-enforced: the built APK's permission list is checked
against an allow-list on every build). Two keys protect you:

### 1. The APK signing key (installs and updates)

| Key | Status | SHA-256 fingerprint (certificate) |
|---|---|---|
| v0.9 → v1.0 key | **RETIRED** — leaked into git history; cannot update the app on Android 9+ (rollback capability revoked in the lineage) | `6A:E9:9F:0B:B9:80:B0:CB:6B:C7:07:BF:F4:A6:65:9A:DE:18:94:7E:9D:B2:03:94:61:93:C5:14:C2:00:70:2A` |
| v1.1 key (current) | active, lives only in CI secrets | `5F:DA:DD:E0:1F:DF:25:17:A7:0A:AC:86:F3:15:88:7C:B7:9B:74:A0:D4:78:79:6F:0D:4B:F4:0C:CB:7A:C6:B6` |

Verify an installed build against this table in the app:
**Settings → About → Signing certificate**.

The rotation uses APK Signature Scheme v3 with a proof-of-rotation lineage
(`android/toad-lineage.bin`, also embedded in every signed APK):

- **Android 9+** verifies v3: the current key + lineage. The retired key
  has **no rollback capability**, so the leaked key can never retake the
  app — even a perfectly valid APK signed with it is refused as an update.
- **Android 8.x** verifies v2 only (signed with the retired key): updates
  from v1.0 keep installing, but those devices remain exposed to the old
  key. Accepted trade-off (docs/DECISIONS.md #3); the 8.x share is small.

`apksigner verify --print-certs --verbose <apk>` shows everything above.

### 2. The update-signing key (release authenticity, SEC-02)

A separate ECDSA P-256 key pair. The **private** half exists only in
GitHub Actions secrets; the **public** half is embedded in the app:

```
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEaQeJVytfG0WM4Y4W1w6kBq37zee6cyVJ9Lt
/EqYxe1UdP4g95Ty9KHv21TiDbYyChWODrDAjXxvrNJpEjY0Vsg==
```

Every release ships a detached signature (`*.apk.sig`) over the exact
string `tagName|sha256|assetName`. The in-app updater:

1. verifies the signature **before** any "update available" banner shows,
2. re-verifies the downloaded APK's SHA-256,
3. checks the APK's **signing certificate** against the table above,
4. refuses downgrades (version compare) — and Android itself refuses
   versionCode downgrades at install time.

Unsigned, badly signed, wrongly-hashed or wrongly-signed releases are
refused with an honest message and a browser handoff to the release page.

## The no-network promise

The launcher process never holds the INTERNET permission. Update checks and
downloads ride the **system DownloadManager** (its process holds the
network, ours never asks for it). CI fails any build whose merged manifest
requests a permission outside the allow-list:

```
QUERY_ALL_PACKAGES · SET_WALLPAPER · REQUEST_DELETE_PACKAGES
REQUEST_INSTALL_PACKAGES · PACKAGE_USAGE_STATS
```

## History note (SEC-01)

The v0.9-era release keystore and its passwords were committed on purpose
("personal, sideload-only") and stayed in the tree until v1.1.0. That key
is treated as **compromised**: it is retired from CI, its rollback
capability is revoked in the rotation lineage, and the credentials were
removed from the working tree. Purging it from git history remains a
documented, owner-run maintenance step (it rewrites every clone):

```bash
git filter-repo --path android/app/toad-release.jks --path android/key.properties --invert-paths
git push origin main --force --tags   # coordinate with contributors first
```

Until that pass runs, treat the fingerprints above — not secrecy — as the
security boundary.
