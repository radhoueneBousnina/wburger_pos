part of '../app_providers.dart';

class PurchaseInvoiceUploadSession {
  final String token;
  final String purchaseId;
  final String? sessionId;
  final String? sessionDate;
  final String uploadUrl;
  final double purchaseTotalAmount;
  final DateTime? expiresAt;
  final bool isExpired;
  final bool isUploaded;
  final DateTime? uploadedAt;
  final String? originalFilename;

  const PurchaseInvoiceUploadSession({
    required this.token,
    required this.purchaseId,
    required this.sessionId,
    required this.sessionDate,
    required this.uploadUrl,
    required this.purchaseTotalAmount,
    required this.expiresAt,
    required this.isExpired,
    required this.isUploaded,
    required this.uploadedAt,
    required this.originalFilename,
  });

  factory PurchaseInvoiceUploadSession.fromJson(Map<String, dynamic> json) {
    double amount(String key) =>
        double.tryParse(json[key]?.toString() ?? '') ?? 0.0;
    DateTime? dateTime(String key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return PurchaseInvoiceUploadSession(
      token: json['token']?.toString() ?? '',
      purchaseId: json['purchase']?.toString() ?? '',
      sessionId: json['session']?.toString(),
      sessionDate: json['session_date']?.toString(),
      uploadUrl: json['upload_url']?.toString() ?? '',
      purchaseTotalAmount: amount('purchase_total_amount'),
      expiresAt: dateTime('expires_at'),
      isExpired: json['is_expired'] == true,
      isUploaded: json['is_uploaded'] == true,
      uploadedAt: dateTime('uploaded_at'),
      originalFilename: json['original_filename']?.toString(),
    );
  }
}

class PurchasesNotifier extends StateNotifier<AsyncValue<List<Purchase>>> {
  final Ref ref;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  DateTime? _lastFetchedAt;
  Future<void>? _inFlight;

  PurchasesNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchPurchases();
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  bool _isFresh(Duration maxAge) {
    final lastFetchedAt = _lastFetchedAt;
    return state.asData != null &&
        lastFetchedAt != null &&
        DateTime.now().difference(lastFetchedAt) < maxAge;
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 90),
  }) {
    if (_isFresh(maxAge)) return Future.value();
    return fetchPurchases(silent: true);
  }

  Future<void> fetchPurchases({
    bool silent = false,
    bool loadMore = false,
    bool force = false,
  }) async {
    if (loadMore && (!_hasMore || _isLoadingMore)) return;
    if (!loadMore && _inFlight != null && !force) return _inFlight!;

    final future = _fetchPurchases(
      silent: silent,
      loadMore: loadMore,
    );
    if (!loadMore) {
      _inFlight = future.whenComplete(() => _inFlight = null);
      return _inFlight!;
    }
    return future;
  }

  Future<void> _fetchPurchases({
    required bool silent,
    required bool loadMore,
  }) async {
    try {
      if (ref.read(testModeProvider).isActive) {
        if (!loadMore && state.asData == null) {
          state = const AsyncValue.data([]);
        }
        _lastFetchedAt = DateTime.now();
        _hasMore = false;
        return;
      }
      final hadData = state.asData != null;
      if ((!silent || !hadData) && !loadMore) {
        state = const AsyncValue.loading();
        _currentPage = 1;
        _hasMore = true;
      }

      if (loadMore) {
        _isLoadingMore = true;
      }

      final res = await apiClient.dio.get(
        ApiConstants.purchases,
        queryParameters: {
          'page': loadMore ? _currentPage : 1,
        },
      );

      final List results =
          res.data is List ? res.data : (res.data['results'] ?? []);
      final nextUrl = res.data is Map ? res.data['next'] : null;
      final purchases = results.map((j) => Purchase.fromJson(j)).toList();

      if (loadMore) {
        state.whenData((current) {
          state = AsyncValue.data([...current, ...purchases]);
        });
        if (nextUrl != null) _currentPage++;
      } else {
        state = AsyncValue.data(purchases);
        _currentPage = 2; // Next page to load
      }

      _hasMore = nextUrl != null;
      _lastFetchedAt = DateTime.now();
    } catch (e, st) {
      apiClient.logError('Fetch purchases error', e);
      if (!loadMore && (!silent || state.asData == null)) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load purchases from the server.',
          ),
          st,
        );
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> submitPurchase({
    required List<Map<String, dynamic>> lines,
    required Uint8List invoiceBytes,
    required String invoiceFileName,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      final localPurchase = _purchaseFromSubmission(
        id: 'test-purchase-${DateTime.now().microsecondsSinceEpoch}',
        lines: lines,
      );
      _prependPurchase(localPurchase);
      ref.read(stockProvider.notifier).applyPurchaseLines(lines);
      return;
    }

    try {
      final createRes = await apiClient.dio.post(
        ApiConstants.purchases,
        data: {'lines': lines},
      );
      final purchaseId = createRes.data['id'].toString();

      final formData = FormData.fromMap({
        'invoice_image': MultipartFile.fromBytes(
          invoiceBytes,
          filename: invoiceFileName,
        ),
      });

      await apiClient.dio.patch(
        '${ApiConstants.purchases}$purchaseId/',
        data: formData,
      );

      await apiClient.dio.post(
        '${ApiConstants.purchases}$purchaseId/confirm_purchase/',
      );

      final localPurchase = _purchaseFromSubmission(
        id: purchaseId,
        lines: lines,
      );
      _prependPurchase(localPurchase);
      ref.read(stockProvider.notifier).applyPurchaseLines(lines);
      unawaited(fetchPurchases(silent: true, force: true));
      unawaited(ref.read(stockProvider.notifier).fetchStock(
            silent: true,
            force: true,
          ));
    } catch (e) {
      apiClient.logError('Submit purchase error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to submit the purchase right now.',
      );
    }
  }

  Future<PurchaseInvoiceUploadSession> createInvoiceUploadSession({
    required List<Map<String, dynamic>> lines,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      return PurchaseInvoiceUploadSession(
        token: 'test-token',
        purchaseId: 'test-purchase-${DateTime.now().microsecondsSinceEpoch}',
        sessionId: null,
        sessionDate: null,
        uploadUrl: '',
        purchaseTotalAmount: 0,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isExpired: false,
        isUploaded: true,
        uploadedAt: DateTime.now(),
        originalFilename: 'training-invoice.jpg',
      );
    }

    try {
      final createRes = await apiClient.dio.post(
        ApiConstants.purchases,
        data: {'lines': lines},
      );
      final purchaseId = createRes.data['id'].toString();
      final response = await apiClient.dio.post(
        '${ApiConstants.purchases}$purchaseId${ApiConstants.purchaseInvoiceUpload}',
      );
      return PurchaseInvoiceUploadSession.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      apiClient.logError('Create invoice upload session error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to create the invoice QR upload right now.',
      );
    }
  }

  Future<PurchaseInvoiceUploadSession> fetchInvoiceUploadSession({
    required String purchaseId,
    required String token,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      return PurchaseInvoiceUploadSession(
        token: token,
        purchaseId: purchaseId,
        sessionId: null,
        sessionDate: null,
        uploadUrl: '',
        purchaseTotalAmount: 0,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isExpired: false,
        isUploaded: true,
        uploadedAt: DateTime.now(),
        originalFilename: 'training-invoice.jpg',
      );
    }

    try {
      final response = await apiClient.dio.get(
        '${ApiConstants.purchases}$purchaseId${ApiConstants.purchaseInvoiceUpload}',
        queryParameters: {'token': token},
      );
      return PurchaseInvoiceUploadSession.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      apiClient.logError('Fetch invoice upload session error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to refresh the invoice upload status right now.',
      );
    }
  }

  Future<void> confirmUploadedPurchase({
    required String purchaseId,
    required List<Map<String, dynamic>> lines,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      final localPurchase = _purchaseFromSubmission(
        id: purchaseId.isEmpty
            ? 'test-purchase-${DateTime.now().microsecondsSinceEpoch}'
            : purchaseId,
        lines: lines,
      );
      _prependPurchase(localPurchase);
      ref.read(stockProvider.notifier).applyPurchaseLines(lines);
      return;
    }

    try {
      await apiClient.dio.post(
        '${ApiConstants.purchases}$purchaseId/confirm_purchase/',
      );

      final localPurchase = _purchaseFromSubmission(
        id: purchaseId,
        lines: lines,
      );
      _prependPurchase(localPurchase);
      ref.read(stockProvider.notifier).applyPurchaseLines(lines);
      unawaited(fetchPurchases(silent: true, force: true));
      unawaited(ref.read(stockProvider.notifier).fetchStock(
            silent: true,
            force: true,
          ));
    } catch (e) {
      apiClient.logError('Confirm uploaded purchase error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to confirm the purchase right now.',
      );
    }
  }

  Future<void> discardPendingPurchase(String purchaseId) async {
    if (purchaseId.isEmpty) return;
    if (ref.read(testModeProvider).isActive) {
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncValue.data(
          current.where((purchase) => purchase.id != purchaseId).toList(),
        );
      }
      return;
    }
    try {
      await apiClient.dio.delete('${ApiConstants.purchases}$purchaseId/');
      final current = state.asData?.value;
      if (current != null) {
        state = AsyncValue.data(
          current.where((purchase) => purchase.id != purchaseId).toList(),
        );
      }
    } catch (e) {
      apiClient.logError('Discard pending purchase error', e);
    }
  }

  void enterTestMode() {
    _currentPage = 1;
    _hasMore = false;
    _lastFetchedAt = DateTime.now();
    state = const AsyncValue.data([]);
  }

  void exitTestMode() {
    _currentPage = 1;
    _hasMore = true;
    _lastFetchedAt = null;
    state = const AsyncValue.loading();
    unawaited(fetchPurchases(force: true));
  }

  void _prependPurchase(Purchase purchase) {
    final current = state.asData?.value ?? const <Purchase>[];
    state = AsyncValue.data([
      purchase,
      ...current.where((existing) => existing.id != purchase.id),
    ]);
    _lastFetchedAt = DateTime.now();
  }

  Purchase _purchaseFromSubmission({
    required String id,
    required List<Map<String, dynamic>> lines,
  }) {
    final stockItems = {
      for (final item in ref.read(stockProvider).asData?.value ?? <StockItem>[])
        item.id: item,
    };
    final parsedLines = lines.map((line) {
      final stockItemId = line['stock_item'].toString();
      final stockItem = stockItems[stockItemId] ??
          StockItem(
            id: stockItemId,
            name: 'Stock #$stockItemId',
            unit: 'piece',
            quantity: 0,
            minThreshold: 0,
            purchasePrice: 0,
            basePrice: 0,
          );
      return PurchaseLine(
        stockItem: stockItem,
        quantity: double.tryParse(line['quantity']?.toString() ?? '0') ?? 0,
        purchasePrice:
            double.tryParse(line['unit_price']?.toString() ?? '0') ?? 0,
      );
    }).toList();

    return Purchase(
      id: id,
      createdAt: DateTime.now(),
      lines: parsedLines,
      status: PurchaseStatus.validated,
      validatedBy: ref.read(authProvider).username,
      totalAmount:
          parsedLines.fold<double>(0, (sum, line) => sum + line.lineTotal),
    );
  }
}

final purchasesProvider =
    StateNotifierProvider<PurchasesNotifier, AsyncValue<List<Purchase>>>((ref) {
  return PurchasesNotifier(ref);
});

// ============================================================
// POS WARMUP / REFRESH COORDINATION
// ============================================================
