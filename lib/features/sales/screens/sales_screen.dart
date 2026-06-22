import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/services/customer_display_service.dart';
import '../../../core/services/receipt_printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../data/models/order_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../shared/widgets/app_image.dart';
import '../../../shared/widgets/brand_patterns.dart';
import '../../../shared/widgets/payment_modal.dart';
import '../../../shared/widgets/top_bar.dart';
import '../utils/qr_order_token.dart';

part '../widgets/cart_panel.dart';
part '../widgets/cart_item_tile.dart';
part '../widgets/products_panel.dart';
part '../widgets/sales_screen_actions.dart';
part '../widgets/success_overlay.dart';
part '../widgets/test_webcam_qr_dialog.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  static const bool _enableTestWebcamScanner = false;
  static const Duration _scannerCharacterGap = Duration(milliseconds: 350);
  static const Duration _scannerIdleFlushDelay = Duration(milliseconds: 180);
  static const Duration _mobileOrderPollInterval = Duration(seconds: 3);
  static const int _scannerBufferMaxLength = 512;

  final _searchCtrl = TextEditingController();
  final _salesFocusNode = FocusNode(debugLabel: 'sales-screen-focus');
  final StringBuffer _scanBuffer = StringBuffer();
  Timer? _scanIdleTimer;
  Timer? _mobileOrderPollTimer;
  DateTime? _lastScanCharacterAt;
  bool _showSuccess = false;
  bool _isProcessingQr = false;
  bool _isCheckingMobileOrder = false;
  String? _lastTicket;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleScannerHardwareKey);
    _refocusSalesScanner();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleScannerHardwareKey);
    _scanIdleTimer?.cancel();
    _mobileOrderPollTimer?.cancel();
    _searchCtrl.dispose();
    _salesFocusNode.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
    if (value.isNotEmpty) {
      ref.read(selectedCategoryProvider.notifier).state = null;
    }
  }

  bool _looksLikeQrToken(String value) => extractQrOrderToken(value) != null;

  void _resetScanBuffer() {
    _scanIdleTimer?.cancel();
    _scanIdleTimer = null;
    _scanBuffer.clear();
    _lastScanCharacterAt = null;
  }

  void _refocusSalesScanner() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_salesFocusNode.canRequestFocus) return;
      _salesFocusNode.requestFocus();
    });
  }

  bool _canAcceptScannerInput() {
    if (!mounted || _isProcessingQr) return false;
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  bool _handleScannerHardwareKey(KeyEvent event) {
    if (!_canAcceptScannerInput()) return false;
    if (event is! KeyDownEvent) return false;

    if (_isScannerTerminator(event)) {
      return _flushScannerBuffer();
    }

    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return false;
    }

    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        character.codeUnits.any((unit) => unit < 0x20)) {
      return false;
    }

    final now = DateTime.now();
    if (_lastScanCharacterAt != null &&
        now.difference(_lastScanCharacterAt!) > _scannerCharacterGap) {
      _resetScanBuffer();
    }

    if (_scanBuffer.length + character.length > _scannerBufferMaxLength) {
      _resetScanBuffer();
    }

    _scanBuffer.write(character);
    _lastScanCharacterAt = now;
    _scheduleScannerIdleFlush();
    return false;
  }

  bool _isScannerTerminator(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab ||
        event.character == '\n' ||
        event.character == '\r' ||
        event.character == '\t';
  }

  void _scheduleScannerIdleFlush() {
    _scanIdleTimer?.cancel();
    _scanIdleTimer = Timer(_scannerIdleFlushDelay, () {
      if (!_canAcceptScannerInput()) {
        _resetScanBuffer();
        return;
      }
      _flushScannerBuffer();
    });
  }

  bool _flushScannerBuffer() {
    final scannedValue = _scanBuffer.toString();
    _resetScanBuffer();
    if (scannedValue.trim().isEmpty) return false;
    return _queueQrImportFromPayload(scannedValue, fromScanner: true);
  }

  bool _queueQrImportFromPayload(
    String value, {
    bool fromScanner = false,
  }) {
    final token = extractQrOrderToken(value);
    if (token == null) {
      if (fromScanner && _looksLikeOrderQrPayload(value)) {
        _showInvalidQrScanFeedback();
      }
      return false;
    }

    _searchCtrl.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedCategoryProvider.notifier).state = null;
    unawaited(_importQrOrder(token));
    return true;
  }

  bool _looksLikeOrderQrPayload(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.length < 8) return false;
    return normalized.contains('wburger') ||
        normalized.contains('w-burger') ||
        normalized.contains('order') ||
        normalized.contains('qr') ||
        normalized.contains('token=');
  }

  void _showInvalidQrScanFeedback() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This QR code is not a W Burger mobile order.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _onCategorySelected(String? id) {
    ref.read(selectedCategoryProvider.notifier).state = id;
    ref.read(searchQueryProvider.notifier).state = '';
    _searchCtrl.clear();
  }

  void _handleSearchSubmitted(String value) {
    final trimmedValue = value.trim();
    if (_looksLikeQrToken(trimmedValue)) {
      _queueQrImportFromPayload(trimmedValue);
    }
  }

  Future<bool> _confirmReplaceCurrentOrder() async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace Current Order?'),
        content: const Text(
          'A new mobile app order was scanned. Replace the current order in the cart?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.fromHeight(context.posLayout.touchTarget),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Current'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(context.posLayout.touchTarget),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return replace ?? false;
  }

  void _startMobileOrderMonitor(String token) {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;
    _mobileOrderPollTimer?.cancel();
    _mobileOrderPollTimer = Timer.periodic(
      _mobileOrderPollInterval,
      (_) => unawaited(_checkImportedMobileOrder()),
    );
  }

  void _stopMobileOrderMonitor() {
    _mobileOrderPollTimer?.cancel();
    _mobileOrderPollTimer = null;
  }

  Future<void> _checkImportedMobileOrder() async {
    if (_isCheckingMobileOrder || _isProcessingQr || !mounted) return;

    final cart = ref.read(cartProvider);
    final token = cart.redemptionToken?.trim();
    if (token == null || token.isEmpty) {
      _stopMobileOrderMonitor();
      return;
    }

    _isCheckingMobileOrder = true;
    try {
      final qrOrder = await ref.read(ordersProvider.notifier).lookupQrOrder(
            token,
          );
      if (qrOrder.status == OrderStatus.cancelled) {
        _handleMobileOrderCancelled(
          token,
          reason: qrOrder.cancellationReason,
        );
      }
    } catch (error) {
      if (_looksLikeCancelledMobileOrder(error)) {
        _handleMobileOrderCancelled(token);
      } else if (kDebugMode) {
        debugPrint('Mobile order status refresh failed: $error');
      }
    } finally {
      _isCheckingMobileOrder = false;
    }
  }

  bool _looksLikeCancelledMobileOrder(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('cancelled') || value.contains('canceled');
  }

  void _handleMobileOrderCancelled(String token, {String? reason}) {
    _showMobileOrderCancelled(token, reason: reason, requireLoadedCart: true);
  }

  void _showMobileOrderCancelled(
    String token, {
    String? reason,
    required bool requireLoadedCart,
  }) {
    if (!mounted) return;

    final currentCart = ref.read(cartProvider);
    final cartToken = currentCart.redemptionToken?.trim();
    final cancelledToken = token.trim();
    if (requireLoadedCart && cartToken != cancelledToken) return;

    if (cartToken == cancelledToken) {
      _stopMobileOrderMonitor();
      ref.read(cartProvider.notifier).clear();
      _searchCtrl.clear();
      ref.read(searchQueryProvider.notifier).state = '';
      ref.read(selectedCategoryProvider.notifier).state = null;
    }
    unawaited(ref.read(ordersProvider.notifier).fetchTodayOrders(
          showLoading: false,
          force: true,
        ));

    final cleanReason = reason?.trim();
    final message = cleanReason == null || cleanReason.isEmpty
        ? 'Mobile order was cancelled by the customer.'
        : 'Mobile order was cancelled by the customer: $cleanReason';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _importQrOrder(String token) async {
    final trimmedToken = token.trim();
    if (_isProcessingQr || trimmedToken.isEmpty) return;

    final currentCart = ref.read(cartProvider);
    if (currentCart.items.isNotEmpty &&
        currentCart.redemptionToken != trimmedToken) {
      final shouldReplace = await _confirmReplaceCurrentOrder();
      if (!shouldReplace) return;
    }

    setState(() => _isProcessingQr = true);

    try {
      final qrOrder =
          await ref.read(ordersProvider.notifier).lookupQrOrder(trimmedToken);
      if (qrOrder.status == OrderStatus.cancelled) {
        _showMobileOrderCancelled(
          trimmedToken,
          reason: qrOrder.cancellationReason,
          requireLoadedCart: false,
        );
        return;
      }
      ref.read(cartProvider.notifier).loadFromQrOrder(qrOrder);
      _startMobileOrderMonitor(trimmedToken);
      _searchCtrl.clear();
      ref.read(searchQueryProvider.notifier).state = '';
      ref.read(selectedCategoryProvider.notifier).state = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      _resetScanBuffer();
      if (mounted) {
        setState(() => _isProcessingQr = false);
        _refocusSalesScanner();
      }
    }
  }

  Future<void> _openTestWebcamScanner() async {
    final scannedToken = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _TestWebcamQrDialog(),
    );

    if (!mounted) return;
    _refocusSalesScanner();
    if (scannedToken == null || scannedToken.trim().isEmpty) return;

    final token = extractQrOrderToken(scannedToken);
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR code is not a W Burger mobile order.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await _importQrOrder(token);
  }

  Future<void> _printSampleReceipt() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ReceiptPrinterService.instance.connectWebPrinter();
      final result = await ReceiptPrinterService.instance.printSampleReceipt();
      if (!mounted) return;
      if (result.isSuccess) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sample ticket print failed: ${result.message}'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Sample ticket printing error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Sample ticket print failed. Check printer connection and try again.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<bool> _confirmStockOverride(
      List<StockOverrideWarning> warnings) async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.panelFor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.posLayout.dialogWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stock override required',
                        style:
                            AppTextStyles.h4.copyWith(color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Some items will go below zero if this sale is confirmed.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.elevatedSurfaceFor(context),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: AppColors.borderFor(context)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: warnings.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 24,
                              color: AppColors.borderFor(context),
                            ),
                            itemBuilder: (context, index) {
                              final warning = warnings[index];
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      warning.stockItemName,
                                      style: AppTextStyles.title.copyWith(
                                        color:
                                            AppColors.textPrimaryFor(context),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    warning.projectedQty.toString(),
                                    style: AppTextStyles.h4
                                        .copyWith(color: AppColors.error),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              Size.fromHeight(context.posLayout.touchTarget),
                        ),
                        child: const Text('Cancel Sale'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: AppColors.white,
                          minimumSize:
                              Size.fromHeight(context.posLayout.touchTarget),
                        ),
                        child: const Text('Confirm Anyway'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return shouldContinue ?? false;
  }

  void _showPrintResult(ReceiptPrintResult printResult) {
    if (!mounted) return;
    if (printResult.isSuccess) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(printResult.message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _printTicketInBackground(ReceiptData receiptData) {
    unawaited(() async {
      try {
        final shouldOpenDrawer = ReceiptPrinterService.instance
            .shouldOpenDrawerForReceipt(receiptData);
        unawaited(CustomerDisplayService.instance.showZeroes());
        final result = await ReceiptPrinterService.instance.printReceipt(
          receiptData,
          openDrawer: shouldOpenDrawer,
          allowBrowserFallback: false,
        );
        if (shouldOpenDrawer && result.sentToAnyPrinter) {
          final logResult =
              await ref.read(ordersProvider.notifier).logOrderDrawerOpening(
                    ticketNumber: receiptData.ticketNumber,
                    orderId: receiptData.orderId,
                  );
          if (!logResult.logSaved && kDebugMode) {
            debugPrint('Cash order drawer log failed: ${logResult.message}');
          }
          if (!logResult.logSaved && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(logResult.message),
                backgroundColor: AppColors.warning,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
        _showPrintResult(result);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Receipt printing error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        _showPrintResult(
          const ReceiptPrintResult(
            printerCount: 0,
            printedCount: 0,
            error:
                'Receipt printing failed. Check printer connection and try again.',
          ),
        );
      }
    }());
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;
    await ref.read(posSettingsProvider.notifier).fetchSettings(
          silent: false,
          force: true,
        );
    if (!mounted) return;
    final settingsState = ref.read(posSettingsProvider);
    if (settingsState.hasError || settingsState.valueOrNull == null) {
      final message = settingsState.error?.toString() ??
          'Unable to load POS settings from the server.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    final isDealRedemption =
        cart.isQrOrder && cart.paymentType == PaymentType.deal;

    PaymentModal.show(
      context,
      total: cart.subtotal,
      staffDiscountBaseTotal: cart.originalSubtotal,
      initialOrderType: cart.orderType,
      initialPaymentType: cart.paymentType,
      lockOrderType: isDealRedemption,
      lockPaymentType: isDealRedemption,
      title: isDealRedemption ? 'Confirm Deal Redemption' : 'Process Payment',
      confirmLabel: isDealRedemption ? 'Confirm Redemption' : 'Confirm Payment',
      customerName: cart.customerName,
      customerNote: cart.customerNote,
      referenceLabel: cart.ticketNumber,
      onConfirm: (
        paymentType,
        orderType, {
        amountGiven,
        changeReturned,
        staffId,
        glovoOrderId,
        giftRecipient,
        payableTotal,
        discountAmount,
        staffDiscountPercent,
      }) async {
        final orderNotifier = ref.read(ordersProvider.notifier);
        final confirmedPaymentType =
            isDealRedemption ? PaymentType.deal : paymentType;
        final effectiveStaffDiscountPercent = staffDiscountPercent ??
            ref.read(posSettingsProvider).valueOrNull?.staffDiscountPercent ??
            0;
        final effectiveCart = cart.copyWith(
          orderType: orderType,
          paymentType: confirmedPaymentType,
        );
        final effectiveDiscountAmount = discountAmount ??
            effectiveCart.discountAmountFor(
              confirmedPaymentType,
              staffDiscountPercent: effectiveStaffDiscountPercent,
            );
        final effectivePayableTotal = payableTotal ??
            effectiveCart.payableTotalFor(
              confirmedPaymentType,
              staffDiscountPercent: effectiveStaffDiscountPercent,
            );
        CheckoutResult result = cart.redemptionToken != null
            ? await orderNotifier.processQrRedemption(
                effectiveCart,
                confirmedPaymentType,
                amountGiven: amountGiven,
                changeReturned: changeReturned,
                staffId: staffId,
                glovoOrderId: glovoOrderId,
                giftRecipient: giftRecipient,
              )
            : await orderNotifier.processCartOrder(
                effectiveCart,
                confirmedPaymentType,
                amountGiven: amountGiven,
                changeReturned: changeReturned,
                staffId: staffId,
                glovoOrderId: glovoOrderId,
                giftRecipient: giftRecipient,
              );

        if (result.requiresStockOverride) {
          final shouldOverride = await _confirmStockOverride(result.warnings);
          if (shouldOverride && result.orderId != null) {
            result = cart.redemptionToken != null
                ? await orderNotifier.processQrRedemption(
                    effectiveCart,
                    confirmedPaymentType,
                    allowNegativeStock: true,
                    amountGiven: amountGiven,
                    changeReturned: changeReturned,
                    staffId: staffId,
                    glovoOrderId: glovoOrderId,
                    giftRecipient: giftRecipient,
                  )
                : await orderNotifier.confirmExistingOrder(
                    result.orderId!,
                    confirmedPaymentType,
                    cart: effectiveCart,
                    orderType: orderType,
                    allowNegativeStock: true,
                    amountGiven: amountGiven,
                    changeReturned: changeReturned,
                    staffId: staffId,
                    glovoOrderId: glovoOrderId,
                    giftRecipient: giftRecipient,
                  );
          } else {
            if (cart.redemptionToken == null && result.orderId != null) {
              await orderNotifier.cancelPendingOrder(
                result.orderId!,
                'Stock override declined at POS',
              );
            }
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sale was not confirmed.')),
            );
            return;
          }
        }

        if (!result.isSuccess) {
          throw Exception(result.error ?? 'Unable to process order');
        }

        final confirmedOrder = result.confirmedOrder;
        final ticket =
            confirmedOrder != null && confirmedOrder.ticketNumber.isNotEmpty
                ? confirmedOrder.ticketNumber
                : result.ticketNumber ?? 'ORDER';
        final receiptData = confirmedOrder != null &&
                confirmedPaymentType != PaymentType.staff &&
                confirmedPaymentType != PaymentType.gift
            ? ReceiptData.fromOrder(
                confirmedOrder,
                cashierName: ref.read(authProvider).username,
              )
            : ReceiptData(
                ticketNumber: ticket,
                orderId: result.orderId,
                soldAt: DateTime.now(),
                lines: ReceiptLine.fromCartItems(effectiveCart.items),
                orderType: orderType,
                paymentType: confirmedPaymentType,
                sourceLabel:
                    effectiveCart.isQrOrder ? 'Mobile QR order' : 'POS sale',
                customerName: effectiveCart.customerName,
                customerNote: effectiveCart.customerNote,
                subtotal: effectiveCart.originalSubtotal,
                discountAmount: effectiveDiscountAmount,
                totalAmount: effectivePayableTotal,
                amountGiven: amountGiven,
                changeReturned: changeReturned,
              );
        _printTicketInBackground(receiptData);

        setState(() {
          _lastTicket = ticket;
          _showSuccess = true;
        });

        // Clear cart after showing success to avoid any UI flickering
        _stopMobileOrderMonitor();
        ref.read(cartProvider.notifier).clear();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showSuccess = false);
        });
      },
    ).whenComplete(_refocusSalesScanner);
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final testMode = ref.watch(testModeProvider);
    final showSalesMenuButton = layout.width < 1700;

    return Focus(
      focusNode: _salesFocusNode,
      autofocus: true,
      child: ColoredBox(
        color:
            testMode.isActive ? AppColors.trainingBackground : AppColors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: layout.stackPanels
                  ? Column(
                      children: [
                        TopBar(showMenuButton: showSalesMenuButton),
                        Expanded(
                          flex: 7,
                          child: _ProductsPanel(
                            searchCtrl: _searchCtrl,
                            onSearch: _onSearch,
                            onSearchSubmitted: _handleSearchSubmitted,
                            onCategorySelected: _onCategorySelected,
                          ),
                        ),
                        SizedBox(
                            height: math.min(420, layout.height * 0.42),
                            child: _CartPanel(onCheckout: _checkout)),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TopBar(showMenuButton: showSalesMenuButton),
                              Expanded(
                                child: _ProductsPanel(
                                  searchCtrl: _searchCtrl,
                                  onSearch: _onSearch,
                                  onSearchSubmitted: _handleSearchSubmitted,
                                  onCategorySelected: _onCategorySelected,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                            width: layout.cartPanelWidth,
                            child: _CartPanel(onCheckout: _checkout)),
                      ],
                    ),
            ),
            if (_enableTestWebcamScanner)
              Positioned(
                right: 18,
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'sample-ticket',
                      onPressed: _printSampleReceipt,
                      tooltip: 'Print sample ticket',
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                      child: const Icon(Icons.print_rounded),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'test-qr',
                      onPressed: _openTestWebcamScanner,
                      tooltip: 'Test webcam QR scanner',
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.blue,
                      child: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
              ),
            if (_isProcessingQr)
              const Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_showSuccess && _lastTicket != null)
              _SuccessOverlay(
                ticketNumber: _lastTicket!,
              ),
          ],
        ),
      ),
    );
  }
}
