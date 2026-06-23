part of '../app_providers.dart';

class StockOverrideWarning {
  final String stockItemName;
  final String projectedQty;

  const StockOverrideWarning({
    required this.stockItemName,
    required this.projectedQty,
  });

  factory StockOverrideWarning.fromJson(Map<dynamic, dynamic> json) {
    return StockOverrideWarning(
      stockItemName: json['stock_item_name']?.toString() ?? 'Unknown item',
      projectedQty: json['projected_qty']?.toString() ?? '0.000',
    );
  }
}

class CheckoutResult {
  final String? error;
  final String? orderId;
  final String? ticketNumber;
  final Order? confirmedOrder;
  final List<StockOverrideWarning> warnings;
  final bool queuedOffline;

  const CheckoutResult({
    this.error,
    this.orderId,
    this.ticketNumber,
    this.confirmedOrder,
    this.warnings = const [],
    this.queuedOffline = false,
  });

  bool get isSuccess => error == null && warnings.isEmpty;
  bool get requiresStockOverride => warnings.isNotEmpty;
}

String _serviceTypePayload(OrderType orderType) {
  switch (orderType) {
    case OrderType.dineIn:
      return 'dine_in';
    case OrderType.takeaway:
      return 'takeaway';
    case OrderType.glovo:
      return 'delivery';
  }
}

PaymentType _paymentTypeForOrder(OrderType orderType, PaymentType paymentType) {
  return orderType == OrderType.glovo ? PaymentType.glovo : paymentType;
}

class OfflineQueuedOrder {
  final String clientOrderId;
  final String localOrderId;
  final String? serverOrderId;
  final DateTime queuedAt;
  final Map<String, dynamic> createPayload;
  final List<Map<String, dynamic>> itemPayloads;
  final Map<String, dynamic>? discountPayload;
  final Map<String, dynamic> confirmPayload;
  final Map<String, dynamic> localOrderJson;
  final int attempts;
  final String? lastError;

  const OfflineQueuedOrder({
    required this.clientOrderId,
    required this.localOrderId,
    required this.serverOrderId,
    required this.queuedAt,
    required this.createPayload,
    required this.itemPayloads,
    required this.discountPayload,
    required this.confirmPayload,
    required this.localOrderJson,
    this.attempts = 0,
    this.lastError,
  });

  Order get localOrder => Order.fromLocalJson(localOrderJson);

  OfflineQueuedOrder copyWith({
    String? serverOrderId,
    int? attempts,
    String? lastError,
  }) {
    return OfflineQueuedOrder(
      clientOrderId: clientOrderId,
      localOrderId: localOrderId,
      serverOrderId: serverOrderId ?? this.serverOrderId,
      queuedAt: queuedAt,
      createPayload: createPayload,
      itemPayloads: itemPayloads,
      discountPayload: discountPayload,
      confirmPayload: confirmPayload,
      localOrderJson: localOrderJson,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_order_id': clientOrderId,
      'local_order_id': localOrderId,
      if (serverOrderId != null) 'server_order_id': serverOrderId,
      'queued_at': queuedAt.toIso8601String(),
      'create_payload': createPayload,
      'item_payloads': itemPayloads,
      if (discountPayload != null) 'discount_payload': discountPayload,
      'confirm_payload': confirmPayload,
      'local_order': localOrderJson,
      'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    };
  }

  factory OfflineQueuedOrder.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapList(Object? value) {
      return (value as List? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }

    return OfflineQueuedOrder(
      clientOrderId: json['client_order_id']?.toString() ?? '',
      localOrderId: json['local_order_id']?.toString() ?? '',
      serverOrderId: _offlineFirstNonEmptyString([json['server_order_id']]),
      queuedAt:
          DateTime.tryParse(json['queued_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      createPayload: Map<String, dynamic>.from(
        _offlineAsMap(json['create_payload']) ?? const {},
      ),
      itemPayloads: mapList(json['item_payloads']),
      discountPayload: _offlineAsMap(json['discount_payload']),
      confirmPayload: Map<String, dynamic>.from(
        _offlineAsMap(json['confirm_payload']) ?? const {},
      ),
      localOrderJson: Map<String, dynamic>.from(
        _offlineAsMap(json['local_order']) ?? const {},
      ),
      attempts: _offlineParseInt(json['attempts'], fallback: 0),
      lastError: _offlineFirstNonEmptyString([json['last_error']]),
    );
  }
}

class OfflineOrderQueueStore {
  static const _storageKey = 'wburger_offline_order_queue_v1';
  static const _ticketCounterKey = 'wburger_ticket_counters_v1';

  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<OfflineQueuedOrder>> load() async {
    await init();
    final raw = _prefs?.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => OfflineQueuedOrder.fromJson(
                Map<String, dynamic>.from(entry),
              ))
          .where((entry) =>
              entry.clientOrderId.isNotEmpty && entry.localOrderId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<OfflineQueuedOrder> queue) async {
    await init();
    await _prefs?.setString(
      _storageKey,
      jsonEncode(queue.map((entry) => entry.toJson()).toList()),
    );
    PosMonitoringService.instance.setUnsyncedOrdersCount(queue.length);
  }

  Future<void> enqueue(OfflineQueuedOrder entry) async {
    final queue = await load();
    final existingIndex = queue.indexWhere(
      (queued) => queued.clientOrderId == entry.clientOrderId,
    );
    if (existingIndex == -1) {
      await save([...queue, entry]);
      return;
    }

    final next = [...queue];
    next[existingIndex] = entry;
    await save(next);
  }

  Future<void> rememberTicketNumbers(Iterable<String> ticketNumbers) async {
    await init();
    final counters = _readTicketCounters();
    var changed = false;
    for (final ticketNumber in ticketNumbers) {
      final parsed = _parseTicketNumber(ticketNumber);
      if (parsed == null) continue;
      final current = counters[parsed.dateStr] ?? 100;
      if (parsed.sequence > current) {
        counters[parsed.dateStr] = parsed.sequence;
        changed = true;
      }
    }
    if (changed) await _writeTicketCounters(counters);
  }

  Future<String> reserveTicketNumber({
    required String dateStr,
    Iterable<String> knownTicketNumbers = const [],
  }) async {
    await rememberTicketNumbers(knownTicketNumbers);
    final counters = _readTicketCounters();
    final nextSequence = (counters[dateStr] ?? 100) + 1;
    counters[dateStr] = nextSequence;
    await _writeTicketCounters(counters);
    return 'W-$dateStr-$nextSequence';
  }

  Map<String, int> _readTicketCounters() {
    final raw = _prefs?.getString(_ticketCounterKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) {
        final parsed = value is int ? value : int.tryParse(value.toString());
        return MapEntry(key.toString(), parsed ?? 100);
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeTicketCounters(Map<String, int> counters) async {
    await _prefs?.setString(_ticketCounterKey, jsonEncode(counters));
  }
}

class _ParsedTicketNumber {
  final String dateStr;
  final int sequence;

  const _ParsedTicketNumber({
    required this.dateStr,
    required this.sequence,
  });
}

_ParsedTicketNumber? _parseTicketNumber(String ticketNumber) {
  final parts = ticketNumber.trim().split('-');
  if (parts.length != 3 || parts.first != 'W') return null;
  final dateStr = parts[1];
  if (!RegExp(r'^\d{6}$').hasMatch(dateStr)) return null;
  final sequence = int.tryParse(parts[2]);
  if (sequence == null) return null;
  return _ParsedTicketNumber(dateStr: dateStr, sequence: sequence);
}

String _ticketDateFromDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}${two(value.month)}${value.year % 100}';
}

String? _ticketDateFromSessionDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parts = value.trim().split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return _ticketDateFromDateTime(DateTime(year, month, day));
}

Map<String, dynamic>? _offlineAsMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _offlineFirstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _offlineParseInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

// ============================================================
// ORDERS PROVIDER (Today's Sales)
// ============================================================

class OrdersNotifier extends StateNotifier<AsyncValue<List<Order>>> {
  final Ref ref;

  OrdersNotifier(this.ref) : super(const AsyncValue.loading()) {
    _bootstrapOfflineQueue();
    fetchTodayOrders();
  }

  bool _isFetchingTodayOrders = false;
  bool _isSyncingOfflineOrders = false;
  DateTime? _lastFetchedAt;
  Timer? _offlineSyncTimer;
  final OfflineOrderQueueStore _offlineQueueStore = OfflineOrderQueueStore();

  @override
  void dispose() {
    _offlineSyncTimer?.cancel();
    super.dispose();
  }

  void _bootstrapOfflineQueue() {
    unawaited(_offlineQueueStore.init().then((_) async {
      final queued = await _offlineQueueStore.load();
      PosMonitoringService.instance.setUnsyncedOrdersCount(queued.length);
      await _offlineQueueStore.rememberTicketNumbers(
        queued.map((entry) => entry.localOrder.ticketNumber),
      );
      if (queued.isNotEmpty) {
        _restoreOfflineOrders(queued);
      }
      _offlineSyncTimer?.cancel();
      _offlineSyncTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => unawaited(syncOfflineOrders()),
      );
      unawaited(syncOfflineOrders());
    }));
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  bool _isNetworkFailure(DioException error) {
    if (error.response != null) return false;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.unknown;
  }

  void _restoreOfflineOrders(List<OfflineQueuedOrder> queued) {
    if (queued.isEmpty || !mounted) return;
    final current = state.asData?.value ?? const <Order>[];
    final currentIds = current.map((order) => order.id).toSet();
    final restored = queued
        .map((entry) => entry.localOrder)
        .where((order) => order.id.isNotEmpty && !currentIds.contains(order.id))
        .toList();
    if (restored.isEmpty) return;
    final next = [...restored, ...current]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _lastFetchedAt = DateTime.now();
    state = AsyncValue.data(next);
  }

  CartState _cartWithClientLineIds(
    CartState cart,
    String clientOrderId,
  ) {
    return cart.copyWith(
      items: [
        for (var index = 0; index < cart.items.length; index++)
          cart.items[index].copyWith(
            lineId:
                cart.items[index].lineId ?? '$clientOrderId-line-${index + 1}',
          ),
      ],
    );
  }

  String _newClientOrderId() => 'pos-${const Uuid().v4()}';

  Future<String> _reserveNextTicketNumber(DateTime now) async {
    final sessionDate =
        ref.read(activeSessionStatusProvider).valueOrNull?.activeSessionDate;
    final dateStr =
        _ticketDateFromSessionDate(sessionDate) ?? _ticketDateFromDateTime(now);
    final localTickets =
        state.asData?.value.map((order) => order.ticketNumber) ?? const [];
    final queued = await _offlineQueueStore.load();
    return _offlineQueueStore.reserveTicketNumber(
      dateStr: dateStr,
      knownTicketNumbers: [
        ...localTickets,
        ...queued.map((entry) => entry.localOrder.ticketNumber),
      ],
    );
  }

  Map<String, dynamic> _createOrderPayload({
    required String clientOrderId,
    required OrderType orderType,
    required PaymentType paymentType,
  }) {
    return {
      'client_order_id': clientOrderId,
      'service_type': _serviceTypePayload(orderType),
      'payment_type': paymentType.name,
    };
  }

  Map<String, dynamic> _confirmPaymentPayload({
    required PaymentType paymentType,
    required OrderType? orderType,
    bool allowNegativeStock = false,
    bool skipKds = false,
    double? amountGiven,
    double? changeReturned,
    String? staffId,
    double? staffDiscountPercent,
    String? glovoOrderId,
    String? giftRecipient,
    DateTime? clientConfirmedAt,
    String? ticketNumber,
  }) {
    final effectivePaymentType = orderType == null
        ? paymentType
        : _paymentTypeForOrder(orderType, paymentType);
    return {
      'payment_type': effectivePaymentType.name,
      if (orderType != null) 'service_type': _serviceTypePayload(orderType),
      if (glovoOrderId != null && glovoOrderId.trim().isNotEmpty)
        'glovo_order_id': glovoOrderId.trim(),
      if (allowNegativeStock) 'allow_negative_stock': true,
      if (skipKds) 'skip_kds': true,
      if (amountGiven != null) 'amount_given': amountGiven,
      if (changeReturned != null) 'change_returned': changeReturned,
      if (staffId != null) 'staff_member': staffId,
      if (staffDiscountPercent != null)
        'staff_discount_percent': staffDiscountPercent,
      if (giftRecipient != null && giftRecipient.trim().isNotEmpty)
        'gift_recipient': giftRecipient.trim(),
      if (clientConfirmedAt != null)
        'client_confirmed_at': clientConfirmedAt.toUtc().toIso8601String(),
      if (ticketNumber != null && ticketNumber.trim().isNotEmpty)
        'ticket_number': ticketNumber.trim(),
    };
  }

  CheckoutResult _checkoutResultFromDio(
    DioException error, {
    String? orderId,
    String fallbackMessage = 'Error processing order',
  }) {
    final data = _asMap(error.response?.data);
    final envelope = _asMap(data?['error']);
    final details = _asMap(envelope?['details']);

    final overridePayload = data?['requires_override'] == true
        ? data
        : (details?['requires_override'] == true ? details : null);

    if (overridePayload != null) {
      final rawWarnings = overridePayload['warnings'] as List? ?? const [];
      return CheckoutResult(
        orderId: orderId,
        warnings: rawWarnings
            .whereType<Map>()
            .map(StockOverrideWarning.fromJson)
            .toList(),
      );
    }

    return CheckoutResult(
      error: apiClient.describeError(error, fallback: fallbackMessage),
      orderId: orderId,
    );
  }

  bool _isFresh(Duration maxAge) {
    final lastFetchedAt = _lastFetchedAt;
    return state.asData != null &&
        lastFetchedAt != null &&
        DateTime.now().difference(lastFetchedAt) < maxAge;
  }

  double _staffDiscountPercent() {
    return ref
            .read(posSettingsProvider)
            .valueOrNull
            ?.staffDiscountPercent
            .clamp(0, 100)
            .toDouble() ??
        0;
  }

  Future<void> refreshIfStale({
    Duration maxAge = const Duration(seconds: 15),
    bool showLoading = false,
  }) {
    if (_isFresh(maxAge)) return Future.value();
    return fetchTodayOrders(showLoading: showLoading);
  }

  Future<void> fetchTodayOrders({
    bool showLoading = true,
    bool force = false,
  }) async {
    if (_isFetchingTodayOrders) {
      return;
    }

    if (!force && _isFresh(const Duration(seconds: 8))) {
      return;
    }

    _isFetchingTodayOrders = true;
    try {
      if (ref.read(testModeProvider).isActive) {
        if (state.asData == null) {
          state = const AsyncValue.data([]);
        }
        _lastFetchedAt = DateTime.now();
        return;
      }
      if (showLoading && mounted && state.asData == null) {
        state = const AsyncValue.loading();
      }
      final sessionStatus = await const PosSessionService().fetchStatus();
      final queryParameters = <String, String>{
        'status': 'confirmed,cancelled',
        'page_size': '100',
        'sort': 'updated',
        if (sessionStatus.hasActiveSession)
          'session_id': sessionStatus.activeSessionId!
        else
          'period': 'today',
      };
      final orders = <Order>[];
      var page = 1;
      while (true) {
        final res = await apiClient.dio.get(
          ApiConstants.orders,
          queryParameters: {
            ...queryParameters,
            'page': page.toString(),
          },
        );
        final List data =
            res.data is List ? res.data : (res.data['results'] ?? []);
        orders.addAll(data.map((j) => Order.fromJson(j)));
        if (res.data is List || res.data['next'] == null) {
          break;
        }
        page += 1;
      }
      final queued = await _offlineQueueStore.load();
      if (queued.isNotEmpty) {
        final existingIds = orders.map((order) => order.id).toSet();
        orders.addAll(
          queued
              .map((entry) => entry.localOrder)
              .where((order) => !existingIds.contains(order.id)),
        );
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      await _offlineQueueStore.rememberTicketNumbers(
        orders.map((order) => order.ticketNumber),
      );
      if (!mounted) return;
      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data(orders);
      unawaited(syncOfflineOrders());
    } catch (e, st) {
      apiClient.logError('Fetch orders error', e);
      if ((showLoading || state.asData == null) && mounted) {
        state = AsyncValue.error(
          apiClient.describeError(
            e,
            fallback: 'Unable to load today\'s sales from the server.',
          ),
          st,
        );
      }
    } finally {
      _isFetchingTodayOrders = false;
    }
  }

  Future<CheckoutResult> _confirmOrder(
    String orderId,
    PaymentType paymentType, {
    OrderType? orderType,
    CartState? cart,
    bool allowNegativeStock = false,
    double? amountGiven,
    double? changeReturned,
    String? staffId,
    double? staffDiscountPercent,
    String? glovoOrderId,
    String? giftRecipient,
  }) async {
    try {
      final effectivePaymentType = orderType == null
          ? paymentType
          : _paymentTypeForOrder(orderType, paymentType);
      final response = await apiClient.dio.post(
        '${ApiConstants.orders}$orderId${ApiConstants.confirmPayment}',
        data: _confirmPaymentPayload(
          paymentType: effectivePaymentType,
          orderType: orderType,
          allowNegativeStock: allowNegativeStock,
          amountGiven: amountGiven,
          changeReturned: changeReturned,
          staffId: staffId,
          staffDiscountPercent: staffDiscountPercent,
          glovoOrderId: glovoOrderId,
          giftRecipient: giftRecipient,
        ),
      );

      final responseData = _asMap(response.data);
      final confirmedOrderData = _asMap(responseData?['order']);
      final parsedConfirmedOrder = confirmedOrderData != null
          ? Order.fromJson(confirmedOrderData)
          : null;
      final confirmedOrder = _normalizeConfirmedOrderPricing(
        parsedConfirmedOrder,
        cart: cart,
        paymentType: effectivePaymentType,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        giftRecipient: giftRecipient,
      );
      final ticketNumber =
          confirmedOrder != null && confirmedOrder.ticketNumber.isNotEmpty
              ? confirmedOrder.ticketNumber
              : responseData?['ticket_number']?.toString();
      _afterConfirmedOrder(
        orderId: orderId,
        paymentType: effectivePaymentType,
        orderType: orderType,
        cart: cart,
        ticketNumber: ticketNumber,
        confirmedOrder: confirmedOrder,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        giftRecipient: giftRecipient,
      );
      return CheckoutResult(
        orderId: orderId,
        ticketNumber: ticketNumber,
        confirmedOrder: confirmedOrder,
      );
    } on DioException catch (e) {
      return _checkoutResultFromDio(
        e,
        orderId: orderId,
      );
    }
  }

  Future<CheckoutResult> processCartOrder(
    CartState cart,
    PaymentType paymentType, {
    double? amountGiven,
    double? changeReturned,
    String? staffId,
    double? staffDiscountPercent,
    String? glovoOrderId,
    String? giftRecipient,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      final effectivePaymentType =
          _paymentTypeForOrder(cart.orderType, paymentType);
      final orderId = 'test-${DateTime.now().microsecondsSinceEpoch}';
      final ticketNumber =
          'TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _afterConfirmedOrder(
        orderId: orderId,
        paymentType: effectivePaymentType,
        orderType: cart.orderType,
        cart: cart,
        ticketNumber: ticketNumber,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        giftRecipient: giftRecipient,
      );
      return CheckoutResult(orderId: orderId, ticketNumber: ticketNumber);
    }

    String? orderId;
    final clientOrderId = _newClientOrderId();
    final preparedCart = _cartWithClientLineIds(cart, clientOrderId);
    try {
      final effectivePaymentType =
          _paymentTypeForOrder(preparedCart.orderType, paymentType);
      // 1. Create order
      final createPayload = _createOrderPayload(
        clientOrderId: clientOrderId,
        orderType: preparedCart.orderType,
        paymentType: effectivePaymentType,
      );
      final res = await apiClient.dio.post(
        ApiConstants.orders,
        data: createPayload,
      );
      orderId = res.data['id'].toString();
      if (res.data['status'] == 'confirmed') {
        final syncedOrder = await _fetchOrderById(orderId);
        if (syncedOrder != null) {
          _upsertLocalOrder(syncedOrder);
        }
        return CheckoutResult(
          orderId: orderId,
          ticketNumber: syncedOrder?.ticketNumber,
          confirmedOrder: syncedOrder,
        );
      }

      // 2. Add items
      for (final item in preparedCart.items) {
        await apiClient.dio
            .post('${ApiConstants.orders}$orderId${ApiConstants.addItem}',
                data: item.toJson(
                  orderId,
                  includeItemDiscount: false,
                  clientLineId: item.lineId,
                ));
      }

      if (preparedCart.discountAmount > 0) {
        await apiClient.dio.patch(
          '${ApiConstants.orders}$orderId/',
          data: {
            'discount_amount': preparedCart.discountAmount.toStringAsFixed(3),
          },
        );
      }

      // 3. Confirm payment
      return await _confirmOrder(
        orderId,
        effectivePaymentType,
        orderType: preparedCart.orderType,
        cart: preparedCart,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        staffId: staffId,
        staffDiscountPercent: staffDiscountPercent,
        glovoOrderId: glovoOrderId,
        giftRecipient: giftRecipient,
      );
    } on DioException catch (e) {
      apiClient.logError('Process order error', e);
      if (_isNetworkFailure(e)) {
        return _queueOfflineCartOrder(
          clientOrderId: clientOrderId,
          serverOrderId: orderId,
          cart: preparedCart,
          paymentType: paymentType,
          amountGiven: amountGiven,
          changeReturned: changeReturned,
          staffId: staffId,
          staffDiscountPercent: staffDiscountPercent,
          glovoOrderId: glovoOrderId,
          giftRecipient: giftRecipient,
          cause: apiClient.describeError(
            e,
            fallback: 'Unable to reach the server. Sale saved offline.',
          ),
        );
      }
      unawaited(PosMonitoringService.instance.recordEvent(
        level: 'error',
        eventType: orderId == null ? 'order_creation_failed' : 'payment_failed',
        message: apiClient.describeError(e,
            fallback: 'Unable to process the order right now.'),
        metadata: {'order_id': orderId},
      ));
      return _checkoutResultFromDio(
        e,
        orderId: orderId,
      );
    } catch (e) {
      apiClient.logError('Process order error', e);
      unawaited(PosMonitoringService.instance.recordEvent(
        level: 'error',
        eventType: 'order_creation_failed',
        message: apiClient.describeError(
          e,
          fallback: 'Unable to process the order right now.',
        ),
        metadata: {'order_id': orderId},
      ));
      return CheckoutResult(
        error: apiClient.describeError(
          e,
          fallback: 'Unable to process the order right now.',
        ),
        orderId: orderId,
      );
    }
  }

  Future<CheckoutResult> processQrRedemption(
    CartState cart,
    PaymentType paymentType, {
    bool allowNegativeStock = false,
    double? amountGiven,
    double? changeReturned,
    String? staffId,
    String? glovoOrderId,
    String? giftRecipient,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      final effectivePaymentType =
          _paymentTypeForOrder(cart.orderType, paymentType);
      final orderId = 'test-qr-${DateTime.now().microsecondsSinceEpoch}';
      final ticketNumber =
          'TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _afterConfirmedOrder(
        orderId: orderId,
        paymentType: effectivePaymentType,
        orderType: cart.orderType,
        cart: cart,
        ticketNumber: ticketNumber,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        giftRecipient: giftRecipient,
      );
      return CheckoutResult(orderId: orderId, ticketNumber: ticketNumber);
    }

    try {
      // For QR, order already exists. We just confirm payment via the redemption token's order lookup ID.
      final res = await apiClient.dio.get(ApiConstants.lookupByQr,
          queryParameters: {'token': cart.redemptionToken});
      final orderId = res.data['id'].toString();
      return await _confirmOrder(
        orderId,
        paymentType,
        orderType: cart.orderType,
        cart: cart,
        allowNegativeStock: allowNegativeStock,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        staffId: staffId,
        glovoOrderId: glovoOrderId,
        giftRecipient: giftRecipient,
      );
    } on DioException catch (e) {
      apiClient.logError('Process QR order error', e);
      unawaited(PosMonitoringService.instance.recordEvent(
        level: 'error',
        eventType: 'payment_failed',
        message: apiClient.describeError(e,
            fallback: 'Unable to process the mobile order right now.'),
        metadata: {'redemption_token_present': cart.redemptionToken != null},
      ));
      return _checkoutResultFromDio(e);
    } catch (e) {
      apiClient.logError('Process QR order error', e);
      unawaited(PosMonitoringService.instance.recordEvent(
        level: 'error',
        eventType: 'payment_failed',
        message: apiClient.describeError(
          e,
          fallback: 'Unable to process the mobile order right now.',
        ),
      ));
      return CheckoutResult(
        error: apiClient.describeError(
          e,
          fallback: 'Unable to process the mobile order right now.',
        ),
      );
    }
  }

  Future<CheckoutResult> confirmExistingOrder(
    String orderId,
    PaymentType paymentType, {
    CartState? cart,
    OrderType? orderType,
    bool allowNegativeStock = false,
    double? amountGiven,
    double? changeReturned,
    String? staffId,
    double? staffDiscountPercent,
    String? glovoOrderId,
    String? giftRecipient,
  }) {
    if (ref.read(testModeProvider).isActive && cart != null) {
      final localOrderType = orderType ?? cart.orderType;
      final effectivePaymentType =
          _paymentTypeForOrder(localOrderType, paymentType);
      final ticketNumber =
          'TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _afterConfirmedOrder(
        orderId: orderId,
        paymentType: effectivePaymentType,
        orderType: localOrderType,
        cart: cart,
        ticketNumber: ticketNumber,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        giftRecipient: giftRecipient,
      );
      return Future.value(
        CheckoutResult(orderId: orderId, ticketNumber: ticketNumber),
      );
    }
    return _confirmOrder(
      orderId,
      paymentType,
      orderType: orderType ?? cart?.orderType,
      cart: cart,
      allowNegativeStock: allowNegativeStock,
      amountGiven: amountGiven,
      changeReturned: changeReturned,
      staffId: staffId,
      staffDiscountPercent: staffDiscountPercent,
      glovoOrderId: glovoOrderId,
      giftRecipient: giftRecipient,
    );
  }

  Future<void> cancelPendingOrder(String orderId, String reason) async {
    if (ref.read(testModeProvider).isActive) {
      _markOrderCancelled(orderId, reason);
      return;
    }
    try {
      await apiClient.dio.post(
        '${ApiConstants.orders}$orderId/cancel_order/',
        data: {'cancellation_reason': reason},
      );
    } catch (e) {
      apiClient.logError('Cancel pending order error', e);
    }
  }

  Future<Order> lookupQrOrder(String token) async {
    try {
      final res = await apiClient.dio.get(
        ApiConstants.lookupByQr,
        queryParameters: {'token': token},
      );
      return Order.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      apiClient.logError('Lookup QR order error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to load the QR order right now.',
      );
    } catch (e) {
      apiClient.logError('Lookup QR order error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to load the QR order right now.',
      );
    }
  }

  Future<void> cancelOrder(String id, String reason) async {
    if (ref.read(testModeProvider).isActive) {
      _markOrderCancelled(id, reason);
      return;
    }
    try {
      await apiClient.dio
          .post('${ApiConstants.orders}$id/cancel_order/', data: {
        'cancellation_reason': reason,
      });
      _markOrderCancelled(id, reason);
      unawaited(fetchTodayOrders(showLoading: false, force: true));
    } catch (e) {
      apiClient.logError('Cancel order error', e);
    }
  }

  Future<Order> cancelOrderItem({
    required String orderId,
    required String itemId,
    required String reason,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      return _cancelOrderItemLocally(
        orderId: orderId,
        itemId: itemId,
        reason: reason,
      );
    }

    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.orders}$orderId${ApiConstants.cancelItem}',
        data: {
          'order_item_id': itemId,
          'cancellation_reason': reason,
        },
      );
      final responseData = _asMap(response.data);
      final orderData = _asMap(responseData?['order']);
      if (orderData == null) {
        throw 'The server did not return the updated order.';
      }

      final updatedOrder = Order.fromJson(orderData);
      _upsertLocalOrder(updatedOrder);
      unawaited(fetchTodayOrders(showLoading: false, force: true));

      final auth = ref.read(authProvider);
      if (auth.permissions['can_access_stock'] == true ||
          auth.permissions['can_close_session'] == true) {
        unawaited(ref.read(stockProvider.notifier).fetchStock(
              silent: true,
              force: true,
            ));
      }
      return updatedOrder;
    } on DioException catch (e) {
      apiClient.logError('Cancel order item error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to cancel this item right now.',
      );
    } catch (e) {
      apiClient.logError('Cancel order item error', e);
      throw apiClient.describeError(
        e,
        fallback: 'Unable to cancel this item right now.',
      );
    }
  }

  Order _cancelOrderItemLocally({
    required String orderId,
    required String itemId,
    required String reason,
  }) {
    final current = state.asData?.value ?? const <Order>[];
    final existingIndex = current.indexWhere((order) => order.id == orderId);
    if (existingIndex == -1) {
      throw 'Order not found.';
    }

    final existing = current[existingIndex];
    final itemIndex =
        existing.items.indexWhere((item) => item.lineId == itemId);
    if (itemIndex == -1) {
      throw 'Order item not found.';
    }

    final item = existing.items[itemIndex];
    final remainingItems = existing.items
        .where(
            (entry) => entry.lineId != itemId && entry.parentLineId != itemId)
        .map((entry) => entry.copyWith())
        .toList();
    if (remainingItems.where((entry) => !entry.isDealComponent).isEmpty) {
      throw 'Use Cancel Order when removing the last item.';
    }

    final nextTotal = existing.total - item.total;
    final updatedOrder = existing.copyWith(
      items: remainingItems,
      totalAmount: nextTotal > 0 ? nextTotal : 0,
      cancellationReason: [
        existing.cancellationReason?.trim(),
        'Item cancelled: ${item.quantity} x ${item.displayName} - $reason',
      ].where((part) => part != null && part.isNotEmpty).join('\n'),
    );

    _upsertLocalOrder(updatedOrder);
    ref.read(stockProvider.notifier).restoreSaleCart(
          CartState(
            items: [item.copyWith()],
            orderType: existing.orderType,
            paymentType: existing.paymentType,
          ),
        );
    return updatedOrder;
  }

  void _upsertLocalOrder(Order order) {
    final current = state.asData?.value ?? const <Order>[];
    final next = [
      order,
      ...current.where((existing) => existing.id != order.id),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _lastFetchedAt = DateTime.now();
    state = AsyncValue.data(next);
    unawaited(_offlineQueueStore.rememberTicketNumbers([order.ticketNumber]));
  }

  void _replaceLocalOfflineOrder({
    required String localOrderId,
    required Order syncedOrder,
  }) {
    final current = state.asData?.value ?? const <Order>[];
    final withoutLocal = current
        .where(
            (order) => order.id != localOrderId && order.id != syncedOrder.id)
        .toList();
    final next = [syncedOrder, ...withoutLocal]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _lastFetchedAt = DateTime.now();
    state = AsyncValue.data(next);
    unawaited(
      _offlineQueueStore.rememberTicketNumbers([syncedOrder.ticketNumber]),
    );
  }

  Future<Order?> _fetchOrderById(String orderId) async {
    final response = await apiClient.dio.get('${ApiConstants.orders}$orderId/');
    final data = _asMap(response.data);
    return data == null ? null : Order.fromJson(data);
  }

  Future<CheckoutResult> _queueOfflineCartOrder({
    required String clientOrderId,
    required String? serverOrderId,
    required CartState cart,
    required PaymentType paymentType,
    double? amountGiven,
    double? changeReturned,
    String? staffId,
    double? staffDiscountPercent,
    String? glovoOrderId,
    String? giftRecipient,
    required String cause,
  }) async {
    final effectivePaymentType =
        _paymentTypeForOrder(cart.orderType, paymentType);
    final now = DateTime.now();
    final localOrderId = 'offline-$clientOrderId';
    final ticketNumber = await _reserveNextTicketNumber(now);
    final localOrder = _confirmedOrderFromCart(
      orderId: localOrderId,
      cart: cart,
      paymentType: effectivePaymentType,
      orderType: cart.orderType,
      ticketNumber: ticketNumber,
      amountGiven: amountGiven,
      changeReturned: changeReturned,
      giftRecipient: giftRecipient,
    );

    final queuedOrder = OfflineQueuedOrder(
      clientOrderId: clientOrderId,
      localOrderId: localOrderId,
      serverOrderId: serverOrderId,
      queuedAt: now,
      createPayload: _createOrderPayload(
        clientOrderId: clientOrderId,
        orderType: cart.orderType,
        paymentType: effectivePaymentType,
      ),
      itemPayloads: [
        for (final item in cart.items)
          item.toJson(
            localOrderId,
            includeItemDiscount: false,
            clientLineId: item.lineId,
          ),
      ],
      discountPayload: cart.discountAmount > 0
          ? {'discount_amount': cart.discountAmount.toStringAsFixed(3)}
          : null,
      confirmPayload: _confirmPaymentPayload(
        paymentType: effectivePaymentType,
        orderType: cart.orderType,
        allowNegativeStock: true,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        staffId: staffId,
        staffDiscountPercent: staffDiscountPercent,
        glovoOrderId: glovoOrderId,
        giftRecipient: giftRecipient,
        clientConfirmedAt: now,
        ticketNumber: ticketNumber,
      ),
      localOrderJson: localOrder.toLocalJson(),
    );

    await _offlineQueueStore.enqueue(queuedOrder);
    _afterConfirmedOrder(
      orderId: localOrderId,
      paymentType: effectivePaymentType,
      orderType: cart.orderType,
      cart: cart,
      ticketNumber: ticketNumber,
      confirmedOrder: localOrder,
      amountGiven: amountGiven,
      changeReturned: changeReturned,
      giftRecipient: giftRecipient,
      applyLocalStock: true,
      refreshRemote: false,
    );
    unawaited(PosMonitoringService.instance.recordEvent(
      level: 'warning',
      eventType: 'offline_order_queued',
      message: 'POS sale saved offline and queued for sync.',
      metadata: {
        'client_order_id': clientOrderId,
        'local_order_id': localOrderId,
        'server_order_id': serverOrderId,
        'cause': cause,
      },
    ));
    unawaited(syncOfflineOrders());
    return CheckoutResult(
      orderId: localOrderId,
      ticketNumber: ticketNumber,
      confirmedOrder: localOrder,
      queuedOffline: true,
    );
  }

  Future<void> syncOfflineOrders() async {
    if (_isSyncingOfflineOrders || ref.read(testModeProvider).isActive) return;
    _isSyncingOfflineOrders = true;
    try {
      final queue = await _offlineQueueStore.load();
      if (queue.isEmpty) {
        PosMonitoringService.instance.setUnsyncedOrdersCount(0);
        return;
      }

      final remaining = <OfflineQueuedOrder>[];
      for (var index = 0; index < queue.length; index++) {
        final queued = queue[index];
        try {
          final syncedOrder = await _syncQueuedOrder(queued);
          if (syncedOrder != null) {
            _replaceLocalOfflineOrder(
              localOrderId: queued.localOrderId,
              syncedOrder: syncedOrder,
            );
          }
          unawaited(PosMonitoringService.instance.recordEvent(
            level: 'info',
            eventType: 'offline_order_synced',
            message: 'Offline POS sale synced to backend.',
            metadata: {
              'client_order_id': queued.clientOrderId,
              'local_order_id': queued.localOrderId,
              'server_order_id': syncedOrder?.id,
            },
          ));
        } on DioException catch (error) {
          final updated = queued.copyWith(
            attempts: queued.attempts + 1,
            lastError: apiClient.describeError(
              error,
              fallback: 'Offline order sync failed.',
            ),
          );
          remaining.add(updated);
          remaining.addAll(queue.skip(index + 1));
          break;
        } catch (error) {
          remaining.add(queued.copyWith(
            attempts: queued.attempts + 1,
            lastError: apiClient.describeError(
              error,
              fallback: 'Offline order sync failed.',
            ),
          ));
          remaining.addAll(queue.skip(index + 1));
          break;
        }
      }

      await _offlineQueueStore.save(remaining);
      if (remaining.isEmpty) {
        unawaited(fetchTodayOrders(showLoading: false, force: true));
      }
    } finally {
      _isSyncingOfflineOrders = false;
    }
  }

  Future<Order?> _syncQueuedOrder(OfflineQueuedOrder queued) async {
    String? orderId = queued.serverOrderId;
    if (orderId != null && orderId.isNotEmpty) {
      final existing = await _fetchOrderById(orderId);
      if (existing != null && existing.status == OrderStatus.validated) {
        return existing;
      }
    }

    if (orderId == null || orderId.isEmpty) {
      final response = await apiClient.dio.post(
        ApiConstants.orders,
        data: queued.createPayload,
      );
      orderId = response.data['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw StateError('Backend did not return an order id.');
      }
      if (response.data['status'] == 'confirmed') {
        return _fetchOrderById(orderId);
      }
    }

    for (final payload in queued.itemPayloads) {
      await apiClient.dio.post(
        '${ApiConstants.orders}$orderId${ApiConstants.addItem}',
        data: {
          ...payload,
          'order': orderId,
        },
      );
    }

    final discountPayload = queued.discountPayload;
    if (discountPayload != null && discountPayload.isNotEmpty) {
      await apiClient.dio.patch(
        '${ApiConstants.orders}$orderId/',
        data: discountPayload,
      );
    }

    final response = await apiClient.dio.post(
      '${ApiConstants.orders}$orderId${ApiConstants.confirmPayment}',
      data: queued.confirmPayload,
    );
    final responseData = _asMap(response.data);
    final orderData = _asMap(responseData?['order']);
    if (orderData != null) {
      return Order.fromJson(orderData);
    }
    return _fetchOrderById(orderId);
  }

  void _markOrderCancelled(String id, String reason) {
    final current = state.asData?.value;
    if (current == null) return;
    Order? existing;
    for (final order in current) {
      if (order.id == id) {
        existing = order;
        break;
      }
    }
    if (ref.read(testModeProvider).isActive &&
        existing != null &&
        existing.status != OrderStatus.cancelled) {
      ref
          .read(stockProvider.notifier)
          .restoreSaleCart(_cartFromOrder(existing));
    }

    state = AsyncValue.data(
      current
          .map(
            (order) => order.id == id
                ? order.copyWith(
                    status: OrderStatus.cancelled,
                    cancellationReason: reason,
                  )
                : order,
          )
          .toList(),
    );
  }

  CartState _cartFromOrder(Order order) {
    return CartState(
      items: order.items.map((item) => item.copyWith()).toList(),
      orderType: order.orderType,
      paymentType: order.paymentType,
      redemptionToken: order.redemptionToken,
      customerId: order.customerId,
      customerName: order.customerName,
      customerNote: order.customerNote,
      ticketNumber: order.ticketNumber,
    );
  }

  Order _confirmedOrderFromCart({
    required String orderId,
    required CartState cart,
    required PaymentType paymentType,
    required OrderType orderType,
    required String? ticketNumber,
    double? amountGiven,
    double? changeReturned,
    String? giftRecipient,
  }) {
    return Order(
      id: orderId,
      ticketNumber: ticketNumber?.isNotEmpty == true
          ? ticketNumber!
          : (cart.ticketNumber?.isNotEmpty == true
              ? cart.ticketNumber!
              : 'W-${orderId.padLeft(4, '0')}'),
      createdAt: DateTime.now(),
      items: cart.items.map((item) => item.copyWith()).toList(),
      orderType: orderType,
      paymentType: paymentType,
      status: OrderStatus.validated,
      customerName: cart.customerName,
      customerId: cart.customerId,
      customerNote: cart.customerNote,
      giftRecipient: giftRecipient,
      isQrOrder: cart.isQrOrder,
      redemptionToken: cart.redemptionToken,
      totalAmount: cart.payableTotalFor(
        paymentType,
        staffDiscountPercent: _staffDiscountPercent(),
      ),
      discountAmount: cart.discountAmountFor(
        paymentType,
        staffDiscountPercent: _staffDiscountPercent(),
      ),
      amountGiven: amountGiven ?? 0,
      changeReturned: changeReturned ?? 0,
    );
  }

  Order? _normalizeConfirmedOrderPricing(
    Order? order, {
    required CartState? cart,
    required PaymentType paymentType,
    double? amountGiven,
    double? changeReturned,
    String? giftRecipient,
  }) {
    if (order == null || cart == null) return order;
    final shouldUsePosDiscountPricing =
        paymentType == PaymentType.staff || paymentType == PaymentType.gift;
    if (!shouldUsePosDiscountPricing) return order;

    final staffDiscountPercent = _staffDiscountPercent();
    return order.copyWith(
      paymentType: paymentType,
      totalAmount: cart.payableTotalFor(
        paymentType,
        staffDiscountPercent: staffDiscountPercent,
      ),
      discountAmount: cart.discountAmountFor(
        paymentType,
        staffDiscountPercent: staffDiscountPercent,
      ),
      amountGiven: amountGiven ?? order.amountGiven,
      changeReturned: changeReturned ?? order.changeReturned,
      giftRecipient: giftRecipient,
    );
  }

  void _afterConfirmedOrder({
    required String orderId,
    required PaymentType paymentType,
    required OrderType? orderType,
    required CartState? cart,
    required String? ticketNumber,
    Order? confirmedOrder,
    double? amountGiven,
    double? changeReturned,
    String? giftRecipient,
    bool applyLocalStock = false,
    bool refreshRemote = true,
  }) {
    if (confirmedOrder != null) {
      _upsertLocalOrder(confirmedOrder);
    } else if (cart != null) {
      _upsertLocalOrder(
        _confirmedOrderFromCart(
          orderId: orderId,
          cart: cart,
          paymentType: paymentType,
          orderType: orderType ?? cart.orderType,
          ticketNumber: ticketNumber,
          amountGiven: amountGiven,
          changeReturned: changeReturned,
          giftRecipient: giftRecipient,
        ),
      );
    }

    if (cart != null &&
        (ref.read(testModeProvider).isActive || applyLocalStock)) {
      ref.read(stockProvider.notifier).applySaleCart(cart);
    }

    if (!refreshRemote) return;

    unawaited(fetchTodayOrders(showLoading: false, force: true));

    final auth = ref.read(authProvider);
    if (auth.permissions['can_access_stock'] == true ||
        auth.permissions['can_close_session'] == true) {
      unawaited(ref.read(stockProvider.notifier).fetchStock(
            silent: true,
            force: true,
          ));
    }
  }

  Future<CashDrawerOpenResult> openCashDrawer(String reason) async {
    if (ref.read(testModeProvider).isActive) {
      final printerResult =
          await ReceiptPrinterService.instance.openCashDrawer();
      return CashDrawerOpenResult(
        logSaved: true,
        printerResult: printerResult,
      );
    }
    final printerResult = await ReceiptPrinterService.instance.openCashDrawer();
    if (!printerResult.sentToAnyPrinter) {
      apiClient.logError(
          'Open cash drawer hardware error', printerResult.message);
      return CashDrawerOpenResult(
        logSaved: false,
        printerResult: printerResult,
      );
    }

    String? logError;
    try {
      await apiClient.dio.post(
        ApiConstants.drawerLogs,
        data: {
          'opening_type': 'manual',
          'reason': reason,
        },
      );
    } on DioException catch (e) {
      apiClient.logError('Open cash drawer log error', e);
      logError = apiClient.describeError(
        e,
        fallback: 'Cash drawer opening was not logged.',
      );
    } catch (e) {
      apiClient.logError('Open cash drawer log error', e);
      logError = apiClient.describeError(
        e,
        fallback: 'Cash drawer opening was not logged.',
      );
    }

    return CashDrawerOpenResult(
      logSaved: logError == null,
      printerResult: printerResult,
      error: logError,
    );
  }

  Future<CashDrawerOpenResult> logKeyOpening(String reason) async {
    if (ref.read(testModeProvider).isActive) {
      return const CashDrawerOpenResult(logSaved: true);
    }
    try {
      await apiClient.dio.post(
        ApiConstants.drawerLogs,
        data: {
          'opening_type': 'key',
          'reason': reason,
        },
      );
      return const CashDrawerOpenResult(logSaved: true);
    } on DioException catch (e) {
      apiClient.logError('Log key opening error', e);
      return CashDrawerOpenResult(
        logSaved: false,
        error: apiClient.describeError(
          e,
          fallback: 'Key opening was not logged.',
        ),
      );
    } catch (e) {
      apiClient.logError('Log key opening error', e);
      return CashDrawerOpenResult(
        logSaved: false,
        error: apiClient.describeError(
          e,
          fallback: 'Key opening was not logged.',
        ),
      );
    }
  }

  Future<CashDrawerOpenResult> logOrderDrawerOpening({
    required String ticketNumber,
    String? orderId,
  }) async {
    if (ref.read(testModeProvider).isActive) {
      return const CashDrawerOpenResult(logSaved: true);
    }

    final cleanTicket = ticketNumber.trim();
    final cleanOrderId = orderId?.trim();
    final hasTicket = cleanTicket.isNotEmpty;
    final hasOrderId = cleanOrderId != null && cleanOrderId.isNotEmpty;
    final reason = hasTicket && hasOrderId
        ? 'Cash payment drawer opening for ticket $cleanTicket (order $cleanOrderId).'
        : hasTicket
            ? 'Cash payment drawer opening for ticket $cleanTicket.'
            : hasOrderId
                ? 'Cash payment drawer opening for order $cleanOrderId.'
                : 'Cash payment drawer opening.';

    try {
      await apiClient.dio.post(
        ApiConstants.drawerLogs,
        data: {
          'opening_type': 'order',
          'reason': reason,
        },
      );
      return const CashDrawerOpenResult(logSaved: true);
    } on DioException catch (e) {
      apiClient.logError('Log cash order drawer opening error', e);
      return CashDrawerOpenResult(
        logSaved: false,
        error: apiClient.describeError(
          e,
          fallback: 'Cash order drawer opening was not logged.',
        ),
      );
    } catch (e) {
      apiClient.logError('Log cash order drawer opening error', e);
      return CashDrawerOpenResult(
        logSaved: false,
        error: apiClient.describeError(
          e,
          fallback: 'Cash order drawer opening was not logged.',
        ),
      );
    }
  }

  void enterTestMode() {
    _lastFetchedAt = DateTime.now();
    state = const AsyncValue.data([]);
  }

  void exitTestMode() {
    _lastFetchedAt = null;
    state = const AsyncValue.loading();
    unawaited(fetchTodayOrders(force: true));
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, AsyncValue<List<Order>>>((ref) {
  return OrdersNotifier(ref);
});

// ============================================================
// STOCK PROVIDER
// ============================================================
