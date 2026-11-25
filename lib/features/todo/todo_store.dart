library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reliability/safe_store.dart';

const String _kPrefsKey = 'toadlauncher.todolist.v1';
final SafeStore _kTodoStore = SafeStore(_kPrefsKey, schemaVersion: 2);

@immutable
class ToadComment {
  const ToadComment({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;

  ToadComment copyWith({String? body}) => ToadComment(
    id: id,
    body: body ?? this.body,
    createdAt: createdAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'body': body,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory ToadComment.fromJson(Map<dynamic, dynamic> json) => ToadComment(
    id: json['id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
  );
}

@immutable
class ToadTask {
  const ToadTask({
    required this.id,
    required this.title,
    required this.createdAt,
    this.done = false,
    this.doneAt,
    this.comments = const [],
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final bool done;
  final DateTime? doneAt;
  final List<ToadComment> comments;

  ToadTask copyWith({
    String? title,
    bool? done,
    DateTime? doneAt,
    List<ToadComment>? comments,
  }) => ToadTask(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    done: done ?? this.done,
    doneAt: doneAt ?? this.doneAt,
    comments: comments ?? this.comments,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'done': done,
    'doneAt': doneAt?.millisecondsSinceEpoch,
    'comments': [for (final c in comments) c.toJson()],
  };

  factory ToadTask.fromJson(Map<dynamic, dynamic> json) => ToadTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
    done: (json['done'] as bool?) ?? false,
    doneAt: json['doneAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (json['doneAt'] as num).toInt(),
          ),
    comments: [
      for (final c in (json['comments'] as List<dynamic>? ?? const []))
        ToadComment.fromJson(c as Map<dynamic, dynamic>),
    ],
  );
}

String _newId() =>
    't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

class TodoController extends Notifier<List<ToadTask>> {
  @override
  List<ToadTask> build() {
    _restore();
    return const [];
  }

  int get openCount => state.where((t) => !t.done).length;
  int get doneCount => state.where((t) => t.done).length;

  void add(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    state = [
      ToadTask(id: _newId(), title: clean, createdAt: DateTime.now()),
      ...state,
    ];
    _persist();
  }

  void toggle(String taskId) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            done: !t.done,
            doneAt: !t.done ? DateTime.now() : null,
          )
        else
          t,
    ];
    _persist();
  }

  void rename(String taskId, String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(title: clean) else t,
    ];
    _persist();
  }

  void remove(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
    _persist();
  }

  void clearDone() {
    state = state.where((t) => !t.done).toList();
    _persist();
  }

  void addComment(String taskId, String body) {
    final clean = body.trim();
    if (clean.isEmpty) return;
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            comments: [
              ...t.comments,
              ToadComment(
                id: _newId(),
                body: clean,
                createdAt: DateTime.now(),
              ),
            ],
          )
        else
          t,
    ];
    _persist();
  }

  void removeComment(String taskId, String commentId) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(
            comments: t.comments.where((c) => c.id != commentId).toList(),
          )
        else
          t,
    ];
    _persist();
  }

  Future<void> _persist() async {
    try {
      await _kTodoStore.write([for (final t in state) t.toJson()]);
    } catch (_) {
    }
  }

  Future<void> _restore() async {
    try {
      final tasks = await _kTodoStore.read<List<ToadTask>>(
        (json) {
          if (json is! List) return null;
          return [
            for (final item in json)
              if (item is Map) ToadTask.fromJson(item.cast<String, Object?>()),
          ]..removeWhere((t) => t.title.isEmpty);
        },
      );
      if (tasks == null || tasks.isEmpty) return;
      if (state.isNotEmpty) return;
      state = tasks;
    } catch (_) {
    }
  }
}

final NotifierProvider<TodoController, List<ToadTask>> todoListProvider =
    NotifierProvider<TodoController, List<ToadTask>>(TodoController.new);

String timeAgo(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
