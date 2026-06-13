part of '../app_providers.dart';

class PosWarmupService {
  final Ref ref;

  const PosWarmupService(this.ref);

  Future<void> warmUpAfterLogin() async {
    await warmUpSalesBeforeOpen();
    warmUpDeferredAfterOpen();
  }

  Future<void> warmUpSalesBeforeOpen() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    final tasks = <Future<void> Function()>[
      () => ref.read(categoriesProvider.notifier).refreshIfStale(),
      () => ref.read(productsProvider.notifier).refreshIfStale(),
      () => ref.read(staffListProvider.notifier).refreshIfStale(),
      () => ref.read(posSettingsProvider.notifier).refreshIfStale(),
    ];

    await Future.wait(tasks.map((task) => _runTask(task)));
  }

  void warmUpDeferredAfterOpen() {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    final tasks = <Future<void> Function()>[
      () => ref
          .read(ordersProvider.notifier)
          .refreshIfStale(maxAge: const Duration(seconds: 8)),
    ];

    if (auth.permissions['can_access_stock'] == true ||
        auth.permissions['can_access_purchases'] == true ||
        auth.permissions['can_close_session'] == true) {
      tasks.add(
        () => ref.read(stockProvider.notifier).refreshIfStale(),
      );
    }

    if (auth.permissions['can_access_purchases'] == true) {
      tasks.add(
        () => ref.read(purchasesProvider.notifier).refreshIfStale(),
      );
    }

    unawaited(_runTasksGently(tasks));
  }

  Future<void> _runTask(Future<void> Function() task) async {
    try {
      await task();
    } catch (error) {
      apiClient.logError('POS warmup task failed', error);
    }
  }

  Future<void> _runTasksGently(List<Future<void> Function()> tasks) async {
    for (final task in tasks) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _runTask(task);
    }
  }
}

final posWarmupProvider = Provider<PosWarmupService>((ref) {
  return PosWarmupService(ref);
});

// ============================================================
// SELECTED CATEGORY PROVIDER
// ============================================================

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ============================================================
// SEARCH PROVIDER
// ============================================================

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final selectedCat = ref.watch(selectedCategoryProvider);
  final productsAsync = ref.watch(productsProvider);

  return productsAsync.whenData((products) {
    List<Product> result = products.where((p) => p.isActive).toList();

    if (query.isNotEmpty) {
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    } else if (selectedCat != null) {
      result = result.where((p) => p.categoryId == selectedCat).toList();
    }

    return result;
  });
});
