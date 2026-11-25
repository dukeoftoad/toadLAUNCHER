library;

import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';

enum MenuContext {
  homeApp,
  dockApp,
  drawerApp,
  pondApp,
  folderApp,
  folderTile,
  emptySpace,
}

@immutable
class MenuShortcut {
  const MenuShortcut({required this.label, required this.onPick});

  final String label;
  final VoidCallback onPick;
}

@immutable
class MenuActions {
  const MenuActions({
    required this.onAppInfo,
    required this.onWidgets,
    required this.onShare,
    required this.onUninstall,
    this.shortcuts = const [],
    this.onEditHome,
    this.onRemove,
    this.onRename,
    this.onOpen,
    this.onWallpaper,
    this.onHomeSettings,
  });

  final VoidCallback onAppInfo;
  final VoidCallback onWidgets;
  final VoidCallback onShare;
  final VoidCallback onUninstall;

  final List<MenuShortcut> shortcuts;

  final VoidCallback? onEditHome;
  final VoidCallback? onRemove;
  final VoidCallback? onRename;
  final VoidCallback? onOpen;
  final VoidCallback? onWallpaper;
  final VoidCallback? onHomeSettings;
}

@immutable
class MenuRequest {
  const MenuRequest({
    required this.context,
    required this.anchor,
    required this.actions,
    this.app,
    this.folder,
  });

  final MenuContext context;
  final Offset anchor;
  final MenuActions actions;
  final AppEntry? app;
  final FolderData? folder;
}

@immutable
class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onPick, {this.danger = false});

  final String icon;
  final String label;
  final VoidCallback onPick;
  final bool danger;
}

List<_MenuItem> _itemsFor(MenuRequest request) {
  final a = request.actions;
  final shortcutRows = [
    for (final s in a.shortcuts.take(3)) _MenuItem('⤴', s.label, s.onPick),
  ];
  switch (request.context) {
    case MenuContext.homeApp:
      return [
        ...shortcutRows,
        _MenuItem('ⓘ', 'App info', a.onAppInfo),
        _MenuItem('▦', 'Widgets', a.onWidgets),
        _MenuItem('✎', 'Edit home screen', a.onEditHome!),
        _MenuItem('↗', 'Share', a.onShare),
        _MenuItem('✕', 'Remove', a.onRemove!),
        _MenuItem('🗑', 'Uninstall…', a.onUninstall, danger: true),
      ];
    case MenuContext.dockApp:
      return [
        ...shortcutRows,
        _MenuItem('ⓘ', 'App info', a.onAppInfo),
        _MenuItem('▦', 'Widgets', a.onWidgets),
        _MenuItem('↗', 'Share', a.onShare),
        _MenuItem('✕', 'Remove', a.onRemove!),
        _MenuItem('🗑', 'Uninstall…', a.onUninstall, danger: true),
      ];
    case MenuContext.drawerApp:
    case MenuContext.pondApp:
      return [
        ...shortcutRows,
        _MenuItem('ⓘ', 'App info', a.onAppInfo),
        _MenuItem('▦', 'Widgets', a.onWidgets),
        _MenuItem('↗', 'Share', a.onShare),
        _MenuItem('🗑', 'Uninstall…', a.onUninstall, danger: true),
      ];
    case MenuContext.folderApp:
      return [
        ...shortcutRows,
        _MenuItem('ⓘ', 'App info', a.onAppInfo),
        _MenuItem('▦', 'Widgets', a.onWidgets),
        _MenuItem('↗', 'Share', a.onShare),
        _MenuItem('✕', 'Remove from folder', a.onRemove!),
        _MenuItem('🗑', 'Uninstall…', a.onUninstall, danger: true),
      ];
    case MenuContext.folderTile:
      return [
        _MenuItem('▦', 'Open', a.onOpen!),
        _MenuItem('✎', 'Rename', a.onRename!),
        _MenuItem('✕', 'Remove', a.onRemove!),
      ];
    case MenuContext.emptySpace:
      return [
        _MenuItem('▤', 'Wallpaper & style', a.onWallpaper!),
        _MenuItem('▦', 'Widgets', a.onWidgets),
        _MenuItem('⚙', 'Home settings', a.onHomeSettings!),
      ];
  }
}

class ContextMenuLayer extends StatefulWidget {
  const ContextMenuLayer({
    super.key,
    required this.request,
    required this.onDismissed,
  });

  final MenuRequest request;

  final VoidCallback onDismissed;

  @override
  State<ContextMenuLayer> createState() => _ContextMenuLayerState();
}

class _ContextMenuLayerState extends State<ContextMenuLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _confirmingUninstall = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: ToadMotion.popoverScaleIn,
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_entrance.isCompleted) {
      _entrance.reverse().then((_) {
        if (mounted) widget.onDismissed();
      });
    } else {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final items = _itemsFor(widget.request);
    final confirming = _confirmingUninstall && widget.request.app != null;

    final double estHeight =
        16 + (confirming ? items.length + 1 : items.length) * 44;

    const double menuWidth = 196;
    final maxLeft = (size.width - menuWidth - 12).clamp(12.0, double.infinity);
    var left = (widget.request.anchor.dx - 26).clamp(12.0, maxLeft);
    var top = widget.request.anchor.dy + 10;
    var alignTop = true;
    if (top + estHeight > size.height - 92) {
      top = (widget.request.anchor.dy - estHeight - 10).clamp(
        12.0,
        double.infinity,
      );
      alignTop = false;
    }

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const ColoredBox(color: Color(0x00000000)),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _entrance,
                curve: Curves.easeOutCubic,
              ),
              alignment: alignTop ? Alignment.topLeft : Alignment.bottomLeft,
              child: FadeTransition(
                opacity: _entrance,
                child: _PopoverCard(
                  request: widget.request,
                  confirmingUninstall: confirming,
                  onArmConfirm: () =>
                      setState(() => _confirmingUninstall = true),
                  onCancelConfirm: () =>
                      setState(() => _confirmingUninstall = false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.request,
    required this.confirmingUninstall,
    required this.onArmConfirm,
    required this.onCancelConfirm,
  });

  final MenuRequest request;
  final bool confirmingUninstall;
  final VoidCallback onArmConfirm;
  final VoidCallback onCancelConfirm;

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final items = _itemsFor(request);

    final cardColor = palette.surface.withValues(
      alpha:
          palette.surface.a * (skin.skin == ResolvedSkin.amoled ? 0.98 : 0.97),
    );
    final rowColor = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(ToadRadii.popover),
          border: Border.all(color: palette.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x73140F05),
              offset: Offset(0, 18),
              blurRadius: 44,
              spreadRadius: -14,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (confirmingUninstall) ...[
              _ConfirmHeader(appName: request.app!.name, rowColor: rowColor),
              _PopoverRow(
                icon: '🗑',
                label: 'Yes, uninstall it',
                color: palette.danger,
                chipColor: palette.danger.withValues(alpha: 0.14),
                onTap: request.actions.onUninstall,
              ),
              _PopoverRow(
                icon: '☺',
                label: 'Keep it',
                color: rowColor,
                chipColor: palette.accentWash,
                chipInk: palette.accentInk,
                onTap: onCancelConfirm,
              ),
            ] else
              for (final item in items)
                _PopoverRow(
                  icon: item.icon,
                  label: item.label,
                  color: item.danger ? palette.danger : rowColor,
                  chipColor: item.danger
                      ? palette.danger.withValues(alpha: 0.14)
                      : (dark
                            ? palette.accent.withValues(alpha: 0.14)
                            : palette.accent.withValues(alpha: 0.12)),
                  chipInk: item.danger ? palette.danger : palette.accentInk,
                  onTap: item.danger ? onArmConfirm : item.onPick,
                ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmHeader extends StatelessWidget {
  const _ConfirmHeader({required this.appName, required this.rowColor});

  final String appName;
  final Color rowColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Uninstall "$appName"?',
          style: ToadType.hand(14.5, color: rowColor, height: 1.2),
        ),
      ),
    );
  }
}

class _PopoverRow extends StatelessWidget {
  const _PopoverRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.chipColor,
    required this.onTap,
    this.chipInk,
  });

  final String icon;
  final String label;
  final Color color;
  final Color chipColor;
  final Color? chipInk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ToadRadii.popoverItem),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  color: chipInk ?? color,
                  fontFamily: ToadType.fontHand,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ToadType.hand(14.5, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
