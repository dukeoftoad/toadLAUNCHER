library;

class ToadFamilyApp {
  const ToadFamilyApp({required this.packageId, required this.displayName});

  final String packageId;
  final String displayName;

  String get searchable => displayName.toLowerCase();
}

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

const List<String> kToadFamilyPrefixes = ['family.toad.'];

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

const String kUpdateRepo = 'dukeoftoad/toadLAUNCHER';
const String kReleasePageUrl = 'https://github.com/$kUpdateRepo/releases/latest';
