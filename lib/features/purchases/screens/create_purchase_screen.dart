import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/stock_models.dart';
import '../../../data/providers/app_providers.dart';

part '../widgets/purchase_line_widgets.dart';
part '../widgets/purchase_invoice_qr_dialog.dart';

class CreatePurchaseScreen extends ConsumerStatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  ConsumerState<CreatePurchaseScreen> createState() =>
      _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends ConsumerState<CreatePurchaseScreen> {
  final List<_PurchaseLineEntry> _lines = [];
  PurchaseInvoiceUploadSession? _invoiceUploadSession;
  bool _isCreatingInvoiceUpload = false;
  bool _submitted = false;
  bool _isSubmitting = false;

  void _addLine() {
    final stocksAsync = ref.read(stockProvider);
    final stocks = stocksAsync.value ?? [];
    if (stocks.isEmpty) return;
    setState(() {
      _clearInvoiceUploadSession();
      _lines.add(_PurchaseLineEntry(
        stockItem: stocks.first,
        quantityCtrl: TextEditingController(text: '1'),
        priceCtrl: TextEditingController(
            text: stocks.first.purchasePrice.toStringAsFixed(3)),
      ));
    });
  }

  void _clearInvoiceUploadSession() {
    final uploadSession = _invoiceUploadSession;
    if (uploadSession != null &&
        uploadSession.purchaseId.isNotEmpty &&
        !_isSubmitting) {
      unawaited(
        ref
            .read(purchasesProvider.notifier)
            .discardPendingPurchase(uploadSession.purchaseId),
      );
    }
    _invoiceUploadSession = null;
  }

  void _goBack() {
    _clearInvoiceUploadSession();
    context.go(AppRoutes.purchases);
  }

  void _removeLine(int i) => setState(() {
        _lines.removeAt(i);
        _clearInvoiceUploadSession();
      });

  double get _total => _lines.fold(0, (s, l) {
        final qty = double.tryParse(l.quantityCtrl.text) ?? 0;
        final price = double.tryParse(l.priceCtrl.text) ?? 0;
        return s + qty * price;
      });

  bool get _invoiceReady =>
      ref.read(testModeProvider).isActive ||
      _invoiceUploadSession?.isUploaded == true;

  List<Map<String, dynamic>> _purchaseLinesPayload() {
    return _lines
        .map((l) => {
              'stock_item': l.stockItem.id,
              'quantity': (double.tryParse(l.quantityCtrl.text) ?? 0)
                  .toStringAsFixed(3),
              'unit_price':
                  (double.tryParse(l.priceCtrl.text) ?? 0).toStringAsFixed(3),
            })
        .toList();
  }

  Future<void> _confirmPurchase() async {
    setState(() => _submitted = true);

    if (_isSubmitting) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one stock item.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final testMode = ref.read(testModeProvider);
    if (!_invoiceReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan the invoice QR and upload the supplier invoice.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final lines = _purchaseLinesPayload();

    setState(() => _isSubmitting = true);
    try {
      if (testMode.isActive) {
        await ref.read(purchasesProvider.notifier).submitPurchase(
              lines: lines,
              invoiceBytes: Uint8List(0),
              invoiceFileName: 'training-invoice.jpg',
            );
      } else {
        final uploadSession = _invoiceUploadSession;
        if (uploadSession == null || uploadSession.purchaseId.isEmpty) return;
        await ref.read(purchasesProvider.notifier).confirmUploadedPurchase(
              purchaseId: uploadSession.purchaseId,
              lines: lines,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(testMode.isActive
              ? 'Training purchase recorded locally'
              : 'Purchase recorded and confirmed successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppRoutes.purchases);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save purchase: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showInvoiceQrUploadFlow() async {
    if (ref.read(testModeProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice upload is skipped in training mode.'),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    setState(() => _submitted = true);

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add purchase items before creating the QR.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final existingUploadSession = _invoiceUploadSession;
    final purchasesNotifier = ref.read(purchasesProvider.notifier);
    if (existingUploadSession != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: existingUploadSession.isUploaded,
        builder: (_) => _PurchaseInvoiceQrDialog(
          initialSession: existingUploadSession,
          purchasesNotifier: purchasesNotifier,
          onUploaded: (latest) {
            if (!mounted) return;
            setState(() => _invoiceUploadSession = latest);
          },
        ),
      );
      return;
    }

    setState(() => _isCreatingInvoiceUpload = true);

    try {
      final uploadSession = await purchasesNotifier.createInvoiceUploadSession(
        lines: _purchaseLinesPayload(),
      );

      if (!mounted) return;
      setState(() {
        _invoiceUploadSession = uploadSession;
        _isCreatingInvoiceUpload = false;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: uploadSession.isUploaded,
        builder: (_) => _PurchaseInvoiceQrDialog(
          initialSession: uploadSession,
          purchasesNotifier: purchasesNotifier,
          onUploaded: (latest) {
            if (!mounted) return;
            setState(() => _invoiceUploadSession = latest);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCreatingInvoiceUpload = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final stocksAsync = ref.watch(stockProvider);
    final testMode = ref.watch(testModeProvider);

    return stocksAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) =>
          Scaffold(body: Center(child: Text('Error loading stock $e'))),
      data: (stocks) => Scaffold(
        backgroundColor: AppColors.pageBackgroundFor(context),
        appBar: AppBar(
          backgroundColor: AppColors.surfaceFor(context),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.blue),
            onPressed: _goBack,
          ),
          title: Text(
            testMode.isActive ? 'New Training Purchase' : 'New Purchase',
            style: AppTextStyles.h4.copyWith(
              color:
                  testMode.isActive ? AppColors.white : AppColors.textPrimary,
            ),
          ),
          actions: [
            if (layout.stackPanels)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Total: ${_total.toStringAsFixed(3)} DT',
                    style: AppTextStyles.title.copyWith(color: AppColors.blue),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            const Divider(height: 1),
            Expanded(
              child: layout.stackPanels
                  ? _buildStackedLayout(stocks, layout)
                  : _buildWideLayout(stocks, layout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(List<StockItem> stocks, PosLayout layout) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel: Items
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(layout.pagePadding),
            child: _buildItemsSection(stocks, layout),
          ),
        ),
        // Right Panel: Summary & Invoice
        Container(
          width: layout.cartPanelWidth,
          decoration: BoxDecoration(
            color: AppColors.surfaceFor(context),
            border: Border(
              left: BorderSide(color: AppColors.borderFor(context)),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(layout.pagePadding),
                  child: _buildSummarySection(layout),
                ),
              ),
              _buildActionsFooter(layout),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackedLayout(List<StockItem> stocks, PosLayout layout) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(layout.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItemsSection(stocks, layout),
          const SizedBox(height: 32),
          _buildSummarySection(layout),
          const SizedBox(height: 32),
          _buildActionsFooter(layout),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<StockItem> stocks, PosLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Purchase Items',
          subtitle: 'Select stock items and set quantities',
          trailing: OutlinedButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Item'),
          ),
        ),
        const SizedBox(height: 20),
        if (_lines.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: _lines.asMap().entries.map((e) {
              return _PurchaseLineRow(
                entry: e.value,
                stocks: stocks,
                onRemove: () => _removeLine(e.key),
                onChanged: () => setState(() {
                  _clearInvoiceUploadSession();
                }),
                onStockChanged: (stock) {
                  setState(() {
                    _clearInvoiceUploadSession();
                    _lines[e.key].stockItem = stock;
                    _lines[e.key].priceCtrl.text =
                        stock.purchasePrice.toStringAsFixed(3);
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSummarySection(PosLayout layout) {
    final testMode = ref.watch(testModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Summary',
          subtitle: 'Review total and attach invoice',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(layout.cardRadius),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Total Items', value: '${_lines.length}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grand Total', style: AppTextStyles.title),
                  Text(
                    '${_total.toStringAsFixed(3)} DT',
                    style: AppTextStyles.h3.copyWith(color: AppColors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _SectionHeader(
          title: 'Invoice Photo',
          subtitle: testMode.isActive
              ? 'Skipped because this purchase is temporary'
              : 'Required for confirmation',
        ),
        const SizedBox(height: 16),
        _InvoiceUpload(
          isUploaded: _invoiceReady,
          isLoading: _isCreatingInvoiceUpload,
          fileName: _invoiceUploadSession?.originalFilename,
          hasError: _submitted && !_invoiceReady,
          onTap: _isCreatingInvoiceUpload ? null : _showInvoiceQrUploadFlow,
        ),
      ],
    );
  }

  Widget _buildActionsFooter(PosLayout layout) {
    final testMode = ref.watch(testModeProvider);
    return Container(
      padding: EdgeInsets.all(layout.pagePadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          if (layout.stackPanels)
            Expanded(
              child: OutlinedButton(
                onPressed: _goBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
          if (layout.stackPanels) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _confirmPurchase,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_isSubmitting
                  ? 'Saving...'
                  : testMode.isActive
                      ? 'Confirm Training Purchase'
                      : 'Confirm Purchase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final testMode = ref.watch(testModeProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderFor(context),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color:
                testMode.isActive ? AppColors.neutral500 : AppColors.neutral300,
          ),
          const SizedBox(height: 16),
          Text('No items added yet',
              style: AppTextStyles.title
                  .copyWith(color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          Text('Click "Add Item" to start your purchase',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondaryFor(context))),
        ],
      ),
    );
  }
}
