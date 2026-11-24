/// Demo toast — sketchbook-card styled snackbar used by both homes.
///
/// Demo mode stays honest: launches record recents locally, while
/// device-only features say so instead of pretending.
library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_theme.dart';

SnackBar toadToast(BuildContext context, String message) {
  final palette = ToadTheme.of(context).palette;
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: palette.surface,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: palette.hairline),
    ),
    duration: const Duration(seconds: 2),
    content: Text(
      message,
      style: ToadType.hand(13.5, color: palette.ink),
    ),
  );
}
