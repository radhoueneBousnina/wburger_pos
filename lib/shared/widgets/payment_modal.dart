import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/pos_layout.dart';
import '../../data/models/order_models.dart';
import '../../data/providers/app_providers.dart';

part 'payment_modal/payment_modal_controls.dart';
part 'payment_modal/payment_modal_layout.dart';

class PaymentModal extends ConsumerStatefulWidget {
  final double total;
  final FutureOr<void> Function(
    PaymentType,
    OrderType, {
    double? amountGiven,
    double? changeReturned,
    String? staffId,
  }) onConfirm;
  final OrderType initialOrderType;
  final PaymentType? initialPaymentType;
  final bool lockOrderType;
  final bool lockPaymentType;
  final String title;
  final String confirmLabel;
  final String? customerName;
  final String? customerNote;
  final String? referenceLabel;

  const PaymentModal({
    super.key,
    required this.total,
    required this.onConfirm,
    this.initialOrderType = OrderType.dineIn,
    this.initialPaymentType,
    this.lockOrderType = false,
    this.lockPaymentType = false,
    this.title = 'Process Payment',
    this.confirmLabel = 'Confirm Payment',
    this.customerName,
    this.customerNote,
    this.referenceLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required double total,
    required FutureOr<void> Function(
      PaymentType,
      OrderType, {
      double? amountGiven,
      double? changeReturned,
      String? staffId,
    }) onConfirm,
    OrderType initialOrderType = OrderType.dineIn,
    PaymentType? initialPaymentType,
    bool lockOrderType = false,
    bool lockPaymentType = false,
    String title = 'Process Payment',
    String confirmLabel = 'Confirm Payment',
    String? customerName,
    String? customerNote,
    String? referenceLabel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentModal(
        total: total,
        onConfirm: onConfirm,
        initialOrderType: initialOrderType,
        initialPaymentType: initialPaymentType,
        lockOrderType: lockOrderType,
        lockPaymentType: lockPaymentType,
        title: title,
        confirmLabel: confirmLabel,
        customerName: customerName,
        customerNote: customerNote,
        referenceLabel: referenceLabel,
      ),
    );
  }

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal> {
  PaymentType? _selectedType;
  late OrderType _orderType;
  bool _isSubmitting = false;
  final TextEditingController _cashGivenController = TextEditingController();
  final TextEditingController _staffSearchController = TextEditingController();
  final FocusNode _cashFocusNode = FocusNode();
  String? _selectedStaffId;

  @override
  void initState() {
    super.initState();
    _orderType = widget.initialOrderType;
    _selectedType = widget.initialPaymentType;
    _cashFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    if (_selectedType == PaymentType.cash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cashFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _cashGivenController.dispose();
    _staffSearchController.dispose();
    _cashFocusNode.dispose();
    super.dispose();
  }

  double get _cashGiven =>
      double.tryParse(_cashGivenController.text.trim()) ?? 0;
  double get _changeReturned =>
      _cashGiven > widget.total ? _cashGiven - widget.total : 0;

  List<PaymentType> get _availablePaymentTypes {
    final isDeal = widget.initialPaymentType == PaymentType.deal ||
        _selectedType == PaymentType.deal;
    if (isDeal) {
      return const [PaymentType.deal];
    }
    final options = <PaymentType>[
      PaymentType.cash,
      PaymentType.card,
      PaymentType.staff,
      PaymentType.other,
    ];
    return options;
  }

  Future<void> _handleConfirm() async {
    if (_selectedType == null || _isSubmitting) return;
    final selectedType = _selectedType!;
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (selectedType == PaymentType.cash &&
        (_cashGivenController.text.trim().isEmpty ||
            _cashGiven < widget.total)) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Enter enough cash before confirming.')),
      );
      return;
    }

    if (selectedType == PaymentType.staff && _selectedStaffId == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Choose the staff member for this sale.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirm(
        selectedType,
        _orderType,
        amountGiven: selectedType == PaymentType.cash ? _cashGiven : null,
        changeReturned:
            selectedType == PaymentType.cash ? _changeReturned : null,
        staffId: selectedType == PaymentType.staff ? _selectedStaffId : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _fillExactAmount() {
    _cashGivenController.text = widget.total.toStringAsFixed(3);
    _cashGivenController.selection = TextSelection.collapsed(
      offset: _cashGivenController.text.length,
    );
    setState(() {});
  }

  void _selectPaymentType(PaymentType type) {
    setState(() => _selectedType = type);
    if (type == PaymentType.cash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cashFocusNode.requestFocus();
      });
    } else {
      _cashFocusNode.unfocus();
    }
  }

  void _insertCashCharacter(String value) {
    final text = _cashGivenController.text;
    final selection = _cashGivenController.selection;
    final useCaret = selection.isValid && selection.isCollapsed;
    final start = useCaret ? selection.start : text.length;
    final end = useCaret ? selection.end : text.length;

    if (value == '.' && text.contains('.') && start == end) return;

    final nextText = text.replaceRange(start, end, value);
    if (nextText.split('.').length > 2) return;
    if (!RegExp(r'^\d*\.?\d{0,3}$').hasMatch(nextText)) return;

    _cashGivenController
      ..text = nextText
      ..selection = TextSelection.collapsed(offset: start + value.length);
    _focusCashFieldAtEndIfNeeded();
    setState(() {});
  }

  void _deleteCashCharacter() {
    final text = _cashGivenController.text;
    final selection = _cashGivenController.selection;
    if (text.isEmpty) return;

    final useCaret = selection.isValid && selection.isCollapsed;
    final start = useCaret ? selection.start : text.length;
    if (start > 0) {
      _cashGivenController
        ..text = text.replaceRange(start - 1, start, '')
        ..selection = TextSelection.collapsed(offset: start - 1);
    }
    _focusCashFieldAtEndIfNeeded();
    setState(() {});
  }

  void _clearCashAmount() {
    _cashGivenController.clear();
    _focusCashFieldAtEndIfNeeded();
    setState(() {});
  }

  void _focusCashFieldAtEndIfNeeded() {
    if (!_cashFocusNode.hasFocus) {
      _cashFocusNode.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final length = _cashGivenController.text.length;
      if (_cashGivenController.selection.isValid &&
          _cashGivenController.selection.isCollapsed &&
          _cashGivenController.selection.end == length) {
        return;
      }
      _cashGivenController.selection = TextSelection.collapsed(offset: length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final compact = layout.width < 760;
    final cashWideLayout =
        _selectedType == PaymentType.cash && layout.width >= 980;

    return Dialog(
      insetPadding: EdgeInsets.all(layout.pagePadding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: cashWideLayout ? 1040 : layout.dialogWidth,
          maxHeight: layout.height - layout.pagePadding * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.yellow),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.h4.copyWith(color: AppColors.white),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.close_rounded, color: AppColors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: cashWideLayout
                  ? Padding(
                      padding: EdgeInsets.all(layout.pagePadding),
                      child: _buildCashWideContent(),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(layout.pagePadding),
                      child: _buildStackedContent(),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(layout.pagePadding, 0,
                  layout.pagePadding, layout.pagePadding),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(layout.touchTarget),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedType == null || _isSubmitting
                          ? null
                          : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(layout.touchTarget),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(_isSubmitting
                          ? 'Processing...'
                          : widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedContent() {
    final children = <Widget>[
      if (_hasCustomerOrderInfo) _buildCustomerOrderSection(),
      _buildOrderTypeSection(),
      _buildPaymentMethodSection(),
      if (_selectedType == PaymentType.cash) _buildCashDetailsSection(),
      if (_selectedType == PaymentType.staff) _buildStaffSection(),
      _buildTotalCard(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.expand((w) => [w, const SizedBox(height: 14)]).toList()
        ..removeLast(),
    );
  }

  Widget _buildCashWideContent() {
    final leftChildren = <Widget>[
      if (_hasCustomerOrderInfo) _buildCustomerOrderSection(dense: true),
      _buildOrderTypeSection(dense: true, compactChoices: true),
      _buildPaymentMethodSection(dense: true, compactChoices: true),
      _buildTotalCard(compact: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 9,
              child: SizedBox(
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  child: Column(
                    children: leftChildren
                        .expand((w) => [w, const SizedBox(height: 10)])
                        .toList()
                      ..removeLast(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 10,
              child: SizedBox(
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  child: _buildCashDetailsSection(
                    dense: true,
                    forceStackedKeypad: false,
                    keypadWidth: 260,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _hasCustomerOrderInfo =>
      widget.customerName?.isNotEmpty == true ||
      widget.customerNote?.isNotEmpty == true ||
      widget.referenceLabel?.isNotEmpty == true;

  Widget _buildCustomerOrderSection({bool dense = false}) {
    return _PaymentSectionCard(
      title: 'Customer Order',
      dense: dense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.customerName?.isNotEmpty == true)
            Text(
              widget.customerName!,
              style: AppTextStyles.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (widget.referenceLabel?.isNotEmpty == true)
            Text(
              'Ticket ${displayTicketNumberFrom(widget.referenceLabel!)}',
              style: AppTextStyles.bodySm,
            ),
          if (widget.customerNote?.isNotEmpty == true)
            Text(
              widget.customerNote!,
              style: AppTextStyles.bodySm,
              maxLines: dense ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeSection({
    bool dense = false,
    bool compactChoices = false,
  }) {
    return _PaymentSectionCard(
      title: 'Order Type',
      dense: dense,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _PaymentChoiceTile(
            label: 'Dine In',
            icon: Icons.restaurant_rounded,
            selected: _orderType == OrderType.dineIn,
            enabled: !widget.lockOrderType,
            compact: compactChoices,
            onTap: () => setState(() => _orderType = OrderType.dineIn),
          ),
          _PaymentChoiceTile(
            label: 'Takeaway',
            icon: Icons.shopping_bag_rounded,
            selected: _orderType == OrderType.takeaway,
            enabled: !widget.lockOrderType,
            compact: compactChoices,
            onTap: () => setState(() => _orderType = OrderType.takeaway),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection({
    bool dense = false,
    bool compactChoices = false,
  }) {
    return _PaymentSectionCard(
      title: 'Payment Method',
      dense: dense,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final type in _availablePaymentTypes)
            _PaymentChoiceTile(
              label: _paymentLabel(type),
              icon: _paymentIcon(type),
              selected: _selectedType == type,
              enabled: !widget.lockPaymentType,
              compact: compactChoices,
              onTap: () => _selectPaymentType(type),
            ),
        ],
      ),
    );
  }

  Widget _buildCashDetailsSection({
    bool dense = false,
    bool forceStackedKeypad = true,
    double keypadWidth = 240,
  }) {
    return _PaymentSectionCard(
      title: 'Cash Details',
      dense: dense,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = !forceStackedKeypad && constraints.maxWidth >= 430;
          final form = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _cashGivenController,
                focusNode: _cashFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) {
                      final valid =
                          RegExp(r'^\d*\.?\d{0,3}$').hasMatch(newValue.text);
                      return valid ? newValue : oldValue;
                    },
                  ),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Amount received',
                  suffixText: 'DT',
                  prefixIcon: const Icon(Icons.payments_rounded),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              SizedBox(height: dense ? 10 : 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _fillExactAmount,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Exact Amount'),
                  ),
                  _PaymentInfoPill(
                    icon: Icons.keyboard_return_rounded,
                    text: 'Change: ${_changeReturned.toStringAsFixed(3)} DT',
                    color: AppColors.success,
                  ),
                ],
              ),
            ],
          );
          final keypad = _CashNumberPad(
            dense: dense,
            onDigit: _insertCashCharacter,
            onDelete: _deleteCashCharacter,
            onClear: _clearCashAmount,
          );
          if (!wide) {
            return Column(
              children: [
                form,
                SizedBox(height: dense ? 10 : 14),
                keypad,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: form),
              const SizedBox(width: 14),
              SizedBox(width: keypadWidth, child: keypad),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaffSection() {
    return _PaymentSectionCard(
      title: 'Staff Member',
      child: _StaffPicker(
        selectedStaffId: _selectedStaffId,
        searchController: _staffSearchController,
        onChanged: (id) => setState(() => _selectedStaffId = id),
      ),
    );
  }

  Widget _buildTotalCard({bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Total: ${widget.total.toStringAsFixed(3)} DT',
        style: (compact ? AppTextStyles.h4 : AppTextStyles.h3)
            .copyWith(color: AppColors.blue),
      ),
    );
  }
}

String _paymentLabel(PaymentType type) {
  switch (type) {
    case PaymentType.cash:
      return 'Cash';
    case PaymentType.card:
      return 'Card';
    case PaymentType.staff:
      return 'Staff';
    case PaymentType.other:
      return 'Other';
    case PaymentType.points:
      return 'Points';
    case PaymentType.deal:
      return 'Deal';
  }
}

IconData _paymentIcon(PaymentType type) {
  switch (type) {
    case PaymentType.cash:
      return Icons.payments_rounded;
    case PaymentType.card:
      return Icons.credit_card_rounded;
    case PaymentType.staff:
      return Icons.badge_rounded;
    case PaymentType.other:
      return Icons.more_horiz_rounded;
    case PaymentType.points:
      return Icons.stars_rounded;
    case PaymentType.deal:
      return Icons.local_offer_rounded;
  }
}
