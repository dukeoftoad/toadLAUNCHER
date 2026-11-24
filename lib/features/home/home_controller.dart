/// Home screen state — loads the app index and tracks the visible page.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repositories/app_repository.dart';

/// Async home layout from the repository (demo-seeded for this alpha).
final AsyncNotifierProvider<HomeController, HomeLayout> homeLayoutProvider =
    AsyncNotifierProvider<HomeController, HomeLayout>(HomeController.new);

class HomeController extends AsyncNotifier<HomeLayout> {
  @override
  Future<HomeLayout> build() async {
    final repo = ref.read(appRepositoryProvider);
    return repo.loadHomeLayout();
  }

  Future<void> launch(AppEntry app) async {
    final repo = ref.read(appRepositoryProvider);
    await repo.launch(app);
  }
}

/// Current home page index (drives the pill dots).
class CurrentPageController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int page) => state = page;
}

final NotifierProvider<CurrentPageController, int> currentPageProvider =
    NotifierProvider<CurrentPageController, int>(CurrentPageController.new);
