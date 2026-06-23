import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../data/models/order_models.dart';
import '../../../data/models/stock_models.dart';
import '../../../data/providers/app_providers.dart';

part '../widgets/session_closure_layout.dart';
part '../widgets/session_closure_summary_widgets.dart';
part '../widgets/stock_document_qr_upload_dialog.dart';
part '../widgets/tpe_qr_upload_dialog.dart';

class SessionClosureScreen extends ConsumerStatefulWidget {
  const SessionClosureScreen({super.key});

  @override
  ConsumerState<SessionClosureScreen> createState() =>
      _SessionClosureScreenState();
}

class _SessionClosureScreenState extends ConsumerState<SessionClosureScreen> {
  static final TextInputFormatter _stockQuantityInputFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    final text = newValue.text;
    if (text.isEmpty || RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return newValue;
    }
    return oldValue;
  });

  int _currentStep = 0;
  bool _financialCompleted = false;
  bool _submittedFinancial = false;
  bool _submittedStock = false;
  bool _isClosingSession = false;
  bool _isCreatingTpeUpload = false;
  bool _isCreatingStockDocumentUpload = false;

  final _actualCashCtrl = TextEditingController();
  final _actualCardCtrl = TextEditingController();
  final _actualOtherCtrl = TextEditingController();
  final _actualFloatCtrl = TextEditingController();
  final _financialNoteCtrl = TextEditingController();
  final _stockNoteCtrl = TextEditingController();
  final Map<String, TextEditingController> _stockActualControllers = {};
  TpeReceiptUploadSession? _tpeUploadSession;
  StockDocumentUploadSession? _stockDocumentUploadSession;

  bool get _isForcedClosure =>
      GoRouterState.of(context).uri.queryParameters['forced'] == '1';
  String? get _previousSessionDate =>
      GoRouterState.of(context).uri.queryParameters['previous_date'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _actualCashCtrl.dispose();
    _actualCardCtrl.dispose();
    _actualOtherCtrl.dispose();
    _actualFloatCtrl.dispose();
    _financialNoteCtrl.dispose();
    _stockNoteCtrl.dispose();
    for (final c in _stockActualControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Order> get _validatedOrders => (ref.read(ordersProvider).value ?? [])
      .where((o) => o.status == OrderStatus.validated)
      .toList();

  double get _theoreticalCash => _validatedOrders
      .where((o) => o.paymentType == PaymentType.cash)
      .fold<double>(0, (s, o) => s + o.total);

  double get _theoreticalCard => _validatedOrders
      .where((o) => o.paymentType == PaymentType.card)
      .fold<double>(0, (s, o) => s + o.total);

  double get _theoreticalOther => _validatedOrders
      .where((o) =>
          o.paymentType != PaymentType.cash &&
          o.paymentType != PaymentType.card &&
          o.paymentType != PaymentType.glovo)
      .fold<double>(0, (s, o) => s + o.total);

  double get _theoreticalFloat =>
      ref
          .read(activeSessionStatusProvider)
          .valueOrNull
          ?.activeSessionOpeningFund ??
      0.0;

  bool get _hasFinancialDiscrepancy {
    final cashEntered = double.tryParse(_actualCashCtrl.text) ?? 0;
    final cardEntered = double.tryParse(_actualCardCtrl.text) ?? 0;
    final otherEntered = double.tryParse(_actualOtherCtrl.text) ?? 0;
    final floatEntered = double.tryParse(_actualFloatCtrl.text) ?? 0;
    return (cashEntered - _theoreticalCash).abs() > 0.001 ||
        (cardEntered - _theoreticalCard).abs() > 0.001 ||
        (otherEntered - _theoreticalOther).abs() > 0.001 ||
        (floatEntered - _theoreticalFloat).abs() > 0.001;
  }

  bool get _tpeReceiptReady => _tpeUploadSession?.isUploaded == true;

  bool get _stockDocumentReady =>
      _stockDocumentUploadSession?.isUploaded == true;

  bool get _hasStockDiscrepancy {
    final stocks = ref.read(stockProvider).value ?? [];
    for (final stock in stocks) {
      final actual =
          double.tryParse(_stockActualControllers[stock.id]?.text ?? '');
      if (actual == null) continue;
      if ((actual - stock.quantity).abs() > 0.2) return true;
    }
    return false;
  }

  bool get _allStockItemsEntered {
    final stocks = ref.read(stockProvider).value ?? [];
    if (stocks.isEmpty) return false;
    return stocks.every((stock) {
      final value = _stockActualControllers[stock.id]?.text.trim() ?? '';
      return value.isNotEmpty && double.tryParse(value) != null;
    });
  }

  List<Map<String, dynamic>> _stockVerificationItems(List<StockItem> stocks) {
    return stocks
        .map((stock) => {
              'stock_item': stock.id,
              'actual_quantity':
                  double.parse(_stockActualControllers[stock.id]!.text.trim())
                      .toStringAsFixed(3),
            })
        .toList();
  }

  void _submitFinancialStep() {
    setState(() => _submittedFinancial = true);
    if (_actualCashCtrl.text.isEmpty ||
        _actualCardCtrl.text.isEmpty ||
        _actualOtherCtrl.text.isEmpty ||
        _actualFloatCtrl.text.isEmpty) {
      return;
    }
    if (!_tpeReceiptReady) {
      return;
    }
    if (_hasFinancialDiscrepancy && _financialNoteCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _financialCompleted = true;
      _currentStep = 1;
    });
  }

  void _syncStockControllers(List<StockItem> stocks) {
    final stockIds = stocks.map((stock) => stock.id).toSet();
    final staleIds = _stockActualControllers.keys
        .where((id) => !stockIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _stockActualControllers.remove(id)?.dispose();
    }
    for (final stock in stocks) {
      _stockActualControllers.putIfAbsent(
          stock.id, () => TextEditingController());
    }
  }

  Future<void> _showTpeQrUploadFlow() async {
    final actualCard = double.tryParse(_actualCardCtrl.text.trim());
    if (actualCard == null) {
      setState(() => _submittedFinancial = true);
      return;
    }

    final sessionService = ref.read(posSessionServiceProvider);
    final existingUploadSession = _tpeUploadSession;
    if (existingUploadSession != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: existingUploadSession.isUploaded,
        builder: (_) => _TpeQrUploadDialog(
          initialSession: existingUploadSession,
          sessionService: sessionService,
          onUploaded: (latest) {
            if (!mounted) return;
            setState(() => _tpeUploadSession = latest);
          },
        ),
      );
      return;
    }

    setState(() => _isCreatingTpeUpload = true);
    try {
      final status = await sessionService.fetchStatus();
      final sessionId = status.activeSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw 'No active session is currently open.';
      }
      final uploadSession = await sessionService.createTpeReceiptUploadSession(
        sessionId: sessionId,
        systemCardAmount: _theoreticalCard,
        actualCardAmount: actualCard,
      );
      if (!mounted) return;
      setState(() => _tpeUploadSession = uploadSession);
      await showDialog<void>(
        context: context,
        barrierDismissible: uploadSession.isUploaded,
        builder: (_) => _TpeQrUploadDialog(
          initialSession: uploadSession,
          sessionService: sessionService,
          onUploaded: (latest) {
            if (!mounted) return;
            setState(() => _tpeUploadSession = latest);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sessionService.describeApiError(error,
              fallback: error.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingTpeUpload = false);
    }
  }

  Future<void> _showStockDocumentQrUploadFlow() async {
    final sessionService = ref.read(posSessionServiceProvider);
    final existingUploadSession = _stockDocumentUploadSession;
    if (existingUploadSession != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: existingUploadSession.isUploaded,
        builder: (_) => _StockDocumentQrUploadDialog(
          initialSession: existingUploadSession,
          sessionService: sessionService,
          onUploaded: (latest) {
            if (!mounted) return;
            setState(() => _stockDocumentUploadSession = latest);
          },
        ),
      );
      return;
    }

    setState(() => _isCreatingStockDocumentUpload = true);
    try {
      final status = await sessionService.fetchStatus();
      final sessionId = status.activeSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw 'No active session is currently open.';
      }
      final uploadSession = await sessionService
          .createStockDocumentUploadSession(sessionId: sessionId);
      if (!mounted) return;
      setState(() => _stockDocumentUploadSession = uploadSession);
      await showDialog<void>(
        context: context,
        barrierDismissible: uploadSession.isUploaded,
        builder: (_) => _StockDocumentQrUploadDialog(
          initialSession: uploadSession,
          sessionService: sessionService,
          onUploaded: (latest) {
            if (!mounted) return;
            setState(() => _stockDocumentUploadSession = latest);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sessionService.describeApiError(error,
              fallback: error.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingStockDocumentUpload = false);
    }
  }

  Future<void> _submitStockStep() async {
    setState(() => _submittedStock = true);
    if (!_allStockItemsEntered) return;
    if (!_stockDocumentReady) return;
    if (_hasStockDiscrepancy && _stockNoteCtrl.text.trim().isEmpty) return;

    final sessionService = ref.read(posSessionServiceProvider);
    final stocks = ref.read(stockProvider).value ?? [];
    final actualCash = double.tryParse(_actualCashCtrl.text) ?? 0;
    final actualCard = double.tryParse(_actualCardCtrl.text) ?? 0;
    final actualOther = double.tryParse(_actualOtherCtrl.text) ?? 0;
    final actualFund = double.tryParse(_actualFloatCtrl.text) ?? 0;
    final staffNote = [
      _financialNoteCtrl.text.trim(),
      _stockNoteCtrl.text.trim()
    ].where((note) => note.isNotEmpty).join('\n\n');

    setState(() => _isClosingSession = true);
    try {
      final status = await sessionService.fetchStatus();
      final sessionId = status.activeSessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw 'No active session is currently open.';
      }
      await sessionService.submitStockVerification(
        sessionId: sessionId,
        note: _stockNoteCtrl.text.trim(),
        stockDocumentUploadToken: _stockDocumentUploadSession?.token,
        items: _stockVerificationItems(stocks),
      );
      await sessionService.createCashClosure(
        sessionId: sessionId,
        actualCash: actualCash,
        actualCard: actualCard,
        actualOther: actualOther,
        actualFund: actualFund,
      );
      await sessionService.closeSession(sessionId, staffNote: staffNote);
      ref.invalidate(activeSessionStatusProvider);
      if (!mounted) return;
      if (_isForcedClosure) {
        await sessionService.openTodaySession();
        ref.invalidate(activeSessionStatusProvider);
        if (!mounted) return;
        context.go(AppRoutes.sales);
      } else {
        await ref.read(authProvider.notifier).logout();
        if (!mounted) return;
        context.go(AppRoutes.login);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isClosingSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sessionService.describeApiError(error,
              fallback: error.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ordersProvider);
    ref.watch(activeSessionStatusProvider);
    return _buildSessionClosureScreen(context);
  }
}
