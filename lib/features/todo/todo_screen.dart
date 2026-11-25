/// toadLIST screen — the launcher's own todo list with comments.
///
/// Sketchbook paper, Patrick Hand rows, Caveat header — the same calm as
/// every other toad page:
///   · add a fly at the top pill, tick it when caught
///   · tap a task to unfold its comments — small notes pinned under it
///   · filter all / open / done; destructive actions confirm
///   · nothing leaves the device, ever (SharedPreferences, offline-first)
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_toast.dart';
import '../home/home_controller.dart';
import 'todo_store.dart';

/// Entry point — the drawer's pinned row, the settings hub and the
/// sticky widget all land here.
Future<void> openTodoList(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const TodoListScreen()),
  );
}

enum _TodoFilter { all, open, done }

class TodoListScreen extends ConsumerStatefulWidget {
  const TodoListScreen({super.key});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  _TodoFilter _filter = _TodoFilter.all;
  String? _expandedId;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(toadToast(context, ToastEvent(message)));
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(todoListProvider.notifier).add(text);
    _input.clear();
    _inputFocus.requestFocus();
  }

  Future<void> _confirmRemoveTask(ToadTask task) async {
    final palette = ToadTheme.of(context).palette;
    final dark = ToadTheme.of(context).isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final comments = task.comments.length;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToadRadii.settingsGroup),
          side: BorderSide(color: palette.hairline),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'catch and release?',
              style: ToadType.caveat(24, color: ink),
            ),
            const SizedBox(height: 10),
            Text(
              comments == 0
                  ? '"${_clip(task.title)}" leaves the list for good.'
                  : '"${_clip(task.title)}" and its $comments '
                      '${comments == 1 ? 'comment' : 'comments'} leave the '
                      'list for good.',
              style: ToadType.hand(14, height: 1.4, color: ink),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('keep it', style: ToadType.hand(14)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.danger,
              foregroundColor: Colors.white,
            ),
            child: Text('release it', style: ToadType.hand(14)),
          ),
        ],
      ),
    );
    if (yes == true) {
      ref.read(todoListProvider.notifier).remove(task.id);
      if (_expandedId == task.id) setState(() => _expandedId = null);
    }
  }

  Future<void> _renameTask(ToadTask task) async {
    final palette = ToadTheme.of(context).palette;
    final dark = ToadTheme.of(context).isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final controller = TextEditingController(text: task.title);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ToadRadii.settingsGroup),
          side: BorderSide(color: palette.hairline),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('re-word the fly', style: ToadType.caveat(24, color: ink)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              cursorColor: palette.accent,
              style: ToadType.hand(15, color: ink),
              decoration: InputDecoration(
                isCollapsed: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.hairline),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('cancel', style: ToadType.hand(14)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: Colors.white,
            ),
            child: Text('save', style: ToadType.hand(14)),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(todoListProvider.notifier).rename(task.id, controller.text);
    }
  }

  static String _clip(String s, [int max = 40]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;
    final hintColor = ink.withValues(alpha: ink.a * 0.45);

    final tasks = ref.watch(todoListProvider);
    final openCount = tasks.where((t) => !t.done).length;
    final doneCount = tasks.length - openCount;

    final visible = switch (_filter) {
      _TodoFilter.all => tasks,
      _TodoFilter.open => tasks.where((t) => !t.done).toList(),
      _TodoFilter.done => tasks.where((t) => t.done).toList(),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.statusIconBrightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: palette.statusIconBrightness,
      ),
      child: Scaffold(
        backgroundColor: palette.paper,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  // Header — same chrome as the settings hub.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.accentWash,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: palette.hairline),
                            ),
                            child: Text(
                              '‹',
                              style: ToadType.hand(
                                22,
                                color: palette.accentInk,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('toadLIST',
                                  style: ToadType.caveat(34, color: ink)),
                              Text(
                                tasks.isEmpty
                                    ? 'a quiet pond — nothing to catch'
                                    : '$openCount open · $doneCount caught',
                                style: ToadType.inter(
                                  10.5,
                                  color: hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (doneCount > 0)
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(todoListProvider.notifier)
                                  .clearDone();
                              _toast('$doneCount caught flies released');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accentWash,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'clear caught',
                                style: ToadType.hand(
                                  13,
                                  color: palette.accentInk,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add-a-fly pill.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: palette.hairline),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text('+', style: ToadType.hand(18, color: hintColor)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _input,
                              focusNode: _inputFocus,
                              onSubmitted: (_) => _add(),
                              style: ToadType.hand(15, color: ink),
                              cursorColor: palette.accent,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                hintText: 'a fly to catch…',
                                hintStyle: ToadType.hand(15, color: hintColor),
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _add,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'add',
                                style: ToadType.hand(
                                  13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Filter chips.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        for (final f in _TodoFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _filter == f
                                      ? palette.accent
                                      : palette.accentWash,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: palette.hairline),
                                ),
                                child: Text(
                                  switch (f) {
                                    _TodoFilter.all => 'all',
                                    _TodoFilter.open => 'open',
                                    _TodoFilter.done => 'caught',
                                  },
                                  style: ToadType.hand(
                                    13,
                                    color: _filter == f
                                        ? Colors.white
                                        : palette.accentInk,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // The list itself.
                  Expanded(
                    child: visible.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              switch (_filter) {
                                _TodoFilter.all =>
                                  'nothing on the list — add a fly above',
                                _TodoFilter.open => 'every fly is caught',
                                _TodoFilter.done => 'nothing caught yet',
                              },
                              textAlign: TextAlign.center,
                              style: ToadType.hand(
                                15,
                                color: hintColor,
                                height: 1.5,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => _TaskCard(
                              task: visible[i],
                              expanded: _expandedId == visible[i].id,
                              ink: ink,
                              palette: palette,
                              onToggle: () => ref
                                  .read(todoListProvider.notifier)
                                  .toggle(visible[i].id),
                              onToggleExpand: () => setState(() =>
                                  _expandedId = _expandedId == visible[i].id
                                      ? null
                                      : visible[i].id),
                              onRename: () => _renameTask(visible[i]),
                              onRemove: () => _confirmRemoveTask(visible[i]),
                              onAddComment: (body) => ref
                                  .read(todoListProvider.notifier)
                                  .addComment(visible[i].id, body),
                              onRemoveComment: (commentId) => ref
                                  .read(todoListProvider.notifier)
                                  .removeComment(visible[i].id, commentId),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One task — sticky paper with a hand-drawn checkbox; unfolds into its
/// comments. Long-press re-words, the ✕ confirms before releasing.
class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.expanded,
    required this.ink,
    required this.palette,
    required this.onToggle,
    required this.onToggleExpand,
    required this.onRename,
    required this.onRemove,
    required this.onAddComment,
    required this.onRemoveComment,
  });

  final ToadTask task;
  final bool expanded;
  final Color ink;
  final ToadPalette palette;
  final VoidCallback onToggle;
  final VoidCallback onToggleExpand;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final void Function(String body) onAddComment;
  final void Function(String commentId) onRemoveComment;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  final TextEditingController _commentInput = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  @override
  void dispose() {
    _commentInput.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _submitComment() {
    final body = _commentInput.text.trim();
    if (body.isEmpty) return;
    widget.onAddComment(body);
    _commentInput.clear();
    _commentFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final palette = widget.palette;
    final ink = widget.ink;
    final hintColor = ink.withValues(alpha: ink.a * 0.45);

    return Container(
      decoration: BoxDecoration(
        color: task.done
            ? palette.surface2.withValues(alpha: palette.surface2.a * 0.6)
            : palette.surface,
        borderRadius: BorderRadius.circular(ToadRadii.inner + 4),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hand-drawn checkbox.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggle,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: task.done ? palette.accent : palette.hairline,
                      width: task.done ? 2 : 1.4,
                    ),
                    color: task.done
                        ? palette.accentWash
                        : Colors.transparent,
                  ),
                  child: task.done
                      ? Text(
                          '✓',
                          style: ToadType.hand(
                            16,
                            color: palette.accentInk,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onToggleExpand,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: ToadType.hand(
                          15.5,
                          height: 1.3,
                          color: task.done
                              ? ink.withValues(alpha: ink.a * 0.55)
                              : ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            timeAgo(task.createdAt),
                            style: ToadType.inter(10, color: hintColor),
                          ),
                          if (task.comments.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accentWash,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${task.comments.length} '
                                '${task.comments.length == 1 ? 'note' : 'notes'}',
                                style: ToadType.inter(
                                  9.5,
                                  color: palette.accentInk,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Unfold chevron.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    widget.expanded ? '⌃' : '⌄',
                    style: ToadType.hand(16, color: hintColor),
                  ),
                ),
              ),
            ],
          ),

          // Unfolded: comments + inputs.
          if (widget.expanded) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: palette.hairline),
            const SizedBox(height: 8),
            if (task.comments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'no notes yet — pin a thought below',
                  style: ToadType.hand(13, color: hintColor),
                ),
              )
            else
              for (final c in task.comments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.body,
                              style: ToadType.hand(
                                14,
                                height: 1.35,
                                color: ink.withValues(alpha: ink.a * 0.85),
                              ),
                            ),
                            Text(
                              timeAgo(c.createdAt),
                              style: ToadType.inter(9.5, color: hintColor),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onRemoveComment(c.id),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            '✕',
                            style: ToadType.hand(12, color: hintColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            // Comment input.
            Container(
              decoration: BoxDecoration(
                color: palette.accentWash,
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Text('✎', style: ToadType.hand(13, color: hintColor)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _commentInput,
                      focusNode: _commentFocus,
                      onSubmitted: (_) => _submitComment(),
                      style: ToadType.hand(14, color: ink),
                      cursorColor: palette.accent,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        hintText: 'pin a note…',
                        hintStyle: ToadType.hand(14, color: hintColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Row actions: re-word · release.
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onRename,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Text(
                      're-word',
                      style: ToadType.hand(12, color: hintColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: palette.danger.withValues(
                          alpha: palette.danger.a * 0.4,
                        ),
                      ),
                    ),
                    child: Text(
                      'release it',
                      style: ToadType.hand(12, color: palette.danger),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
