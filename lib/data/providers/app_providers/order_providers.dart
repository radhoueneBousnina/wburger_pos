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

  const CheckoutResult({
    this.error,
    this.orderId,
    this.ticketNumber,
    this.confirmedOrder,
    this.warnings = const [],
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

// ============================================================
// ORDERS PROVIDER (Today's Sales)
// ============================================================

class OrdersNotifier extends StateNotifier<AsyncValue<List<Order>>> {
  final Ref ref;

  OrdersNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchTodayOrders();
  }

  bool _isFetchingTodayOrders = false;
  DateTime? _lastFetchedAt;

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
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
      if (!mounted) return;
      _lastFetchedAt = DateTime.now();
      state = AsyncValue.data(orders);
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
    String? glovoOrderId,
    String? giftRecipient,
  }) async {
    try {
      final effectivePaymentType = orderType == null
          ? paymentType
          : _paymentTypeForOrder(orderType, paymentType);
      final response = await apiClient.dio.post(
        '${ApiConstants.orders}$orderId${ApiConstants.confirmPayment}',
        data: {
          'payment_type': effectivePaymentType.name,
          if (orderType != null) 'service_type': _serviceTypePayload(orderType),
          if (glovoOrderId != null && glovoOrderId.trim().isNotEmpty)
            'glovo_order_id': glovoOrderId.trim(),
          if (allowNegativeStock) 'allow_negative_stock': true,
          if (amountGiven != null) 'amount_given': amountGiven,
          if (changeReturned != null) 'change_returned': changeReturned,
          if (staffId != null) 'staff_member': staffId,
          if (giftRecipient != null && giftRecipient.trim().isNotEmpty)
            'gift_recipient': giftRecipient.trim(),
        },
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
    try {
      final effectivePaymentType =
          _paymentTypeForOrder(cart.orderType, paymentType);
      // 1. Create order
      final res = await apiClient.dio.post(ApiConstants.orders, data: {
        'service_type': _serviceTypePayload(cart.orderType),
        'payment_type': effectivePaymentType.name,
      });
      orderId = res.data['id'].toString();

      // 2. Add items
      for (final item in cart.items) {
        await apiClient.dio.post(
            '${ApiConstants.orders}$orderId${ApiConstants.addItem}',
            data: item.toJson(orderId, includeItemDiscount: false));
      }

      if (cart.discountAmount > 0) {
        await apiClient.dio.patch(
          '${ApiConstants.orders}$orderId/',
          data: {'discount_amount': cart.discountAmount.toStringAsFixed(3)},
        );
      }

      // 3. Confirm payment
      return await _confirmOrder(
        orderId,
        effectivePaymentType,
        orderType: cart.orderType,
        cart: cart,
        amountGiven: amountGiven,
        changeReturned: changeReturned,
        staffId: staffId,
        glovoOrderId: glovoOrderId,
        giftRecipient: giftRecipient,
      );
    } on DioException catch (e) {
      apiClient.logError('Process order error', e);
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

    if (cart != null && ref.read(testModeProvider).isActive) {
      ref.read(stockProvider.notifier).applySaleCart(cart);
    }

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
    final reason = cleanTicket.isNotEmpty
        ? 'Cash payment drawer opening for ticket $cleanTicket.'
        : cleanOrderId != null && cleanOrderId.isNotEmpty
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
