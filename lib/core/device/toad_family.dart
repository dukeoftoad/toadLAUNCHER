/// The toad family registry — every sibling app under the pond.
///
/// IDs are verified against each app's build config on GitHub
/// (github.com/dukeoftoad). Family membership is NOT guessed from package
/// prefixes: toadNOTES ships as `com.nestnote.app`, toadTIMER as
/// `dev.toad.toadtimer`. An explicit list is the honest source of truth,
/// plus the `family.toad.` prefix that toad-family apps may adopt going
/// forward (the launcher itself uses it).
library;

/// Display metadata for one known family app.
class ToadFamilyApp {
  const ToadFamilyApp({required this.packageId, required this.displayName});

  final String packageId;
  final String displayName;

  /// Lowercase match key (index search should find "notes" for toadNOTES).
  String get searchable => displayName.toLowerCase();
}

/// The family — ordered as the pond would present it (gallery first).
const List<ToadFamilyApp> kToadFamilyApps = [
  ToadFamilyApp(packageId: 'com.toadgallery.app', displayName: 'toadGALLERY'),
  ToadFamilyApp(packageId: 'com.toadfiles.app', displayName: 'toadFILES'),
  ToadFamilyApp(packageId: 'com.toadplayer.app', displayName: 'toadPLAYER'),
  ToadFamilyApp(packageId: 'com.toadhealth.app', displayName: 'toadHEALTH'),
  ToadFamilyApp(packageId: 'dev.toad.toadtimer', displayName: 'toadTIMER'),
  ToadFamilyApp(
    packageId: 'com.toadcalculator',
    displayName: 'toadCALCULATOR',
  ),
  ToadFamilyApp(packageId: 'com.toadlight.filter', displayName: 'toadLIGHT'),
  ToadFamilyApp(packageId: 'com.nestnote.app', displayName: 'toadNOTES'),
];

/// Packages that are family apps by prefix (the launcher's own namespace
/// and any future sibling adopting it).
const List<String> kToadFamilyPrefixes = ['family.toad.'];

/// True when [packageId] belongs to a known family app.
bool isToadFamilyPackage(String packageId) {
  if (packageId == 'family.toad.launcher') return true;
  for (final prefix in kToadFamilyPrefixes) {
    if (packageId.startsWith(prefix)) return true;
  }
  for (final app in kToadFamilyApps) {
    if (app.packageId == packageId) return true;
  }
  return false;
}

/// Display name for a family package, or null for unknown packages.
String? toadFamilyDisplayName(String packageId) {
  for (final app in kToadFamilyApps) {
    if (app.packageId == packageId) return app.displayName;
  }
  if (packageId.startsWith('family.toad.')) {
    final tail = packageId.substring('family.toad.'.length);
    if (tail.isNotEmpty) {
      return 'toad${tail[0].toUpperCase()}${tail.substring(1)}';
    }
  }
  return null;
}

/// GitHub coordinates of this repo — the single endpoint the auto-update
/// flow ever contacts (through the system download service, never a
/// network permission of our own).
const String kUpdateRepo = 'dukeoftoad/toadLAUNCHER';
const String kReleasePageUrl = 'https://github.com/$kUpdateRepo/releases/latest';
