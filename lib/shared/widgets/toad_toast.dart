library;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_theme.dart';
import '../../features/home/home_controller.dart';

SnackBar toadToast(
  BuildContext context,
  ToastEvent event, {
  VoidCallback? onUndo,
}) {
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
    action: event.undoable && onUndo != null
        ? SnackBarAction(
            label: 'Undo',
            textColor: palette.accentInk,
            onPressed: onUndo,
          )
        : null,
    content: Text(
      event.message,
      style: ToadType.hand(13.5, color: palette.ink),
    ),
  );
}
