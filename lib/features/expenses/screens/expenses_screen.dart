import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../data/providers/app_providers.dart';

const _types = <String, String>{
  'salaries': 'Salaries',
  'electricity': 'Electricity',
  'water': 'Water',
  'accountability': 'Accountability',
  'taxes': 'Taxes',
  'suppliers': 'Suppliers',
  'cleaning': 'Cleaning',
  'other': 'Other',
};

class _Expense {
  final int id;
  final String title, description, type, amount;
  final DateTime createdAt;
  const _Expense(this.id, this.title, this.description, this.type, this.amount,
      this.createdAt);

  factory _Expense.fromJson(Map<String, dynamic> json) => _Expense(
        (json['id'] as num).toInt(),
        json['title']?.toString() ?? '',
        json['description']?.toString() ?? '',
        json['type']?.toString() ?? 'other',
        json['amount']?.toString() ?? '0.000',
        DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _client = ApiClient();
  List<_Expense> _rows = [];
  String _period = 'this_month';
  String? _type;
  DateTimeRange? _range;
  int _page = 1, _count = 0;
  String _total = '0.000';
  bool _loading = false;
  String? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(testModeProvider).isActive) _load();
    });
  }

  Map<String, dynamic> get _query {
    final params = <String, dynamic>{
      'page': _page,
      'page_size': 50,
      'period': _period
    };
    if (_period == 'custom' && _range != null) {
      params['start_date'] = DateFormat('yyyy-MM-dd').format(_range!.start);
      params['end_date'] = DateFormat('yyyy-MM-dd').format(_range!.end);
    }
    if (_type != null) params['type'] = _type;
    return params;
  }

  Future<void> _load() async {
    if (ref.read(testModeProvider).isActive ||
        (_period == 'custom' && _range == null)) {
      return;
    }
    final requestSerial = ++_requestSerial;
    final query = _query;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _client.dio.get(ApiConstants.expenses, queryParameters: query),
        _client.dio
            .get('${ApiConstants.expenses}summary/', queryParameters: query),
      ]);
      if (!mounted || requestSerial != _requestSerial) return;
      final list = Map<String, dynamic>.from(results[0].data as Map);
      final summary = Map<String, dynamic>.from(results[1].data as Map);
      setState(() {
        _rows = (list['results'] as List? ?? const [])
            .map((item) =>
                _Expense.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        _count = (list['count'] as num?)?.toInt() ?? 0;
        _total = summary['total_amount']?.toString() ?? '0.000';
      });
    } catch (error) {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _error = _client.describeError(error));
      }
    } finally {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectRange() async {
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _range);
    if (!mounted) return;
    if (picked == null) {
      setState(() {});
      return;
    }
    setState(() {
      _period = 'custom';
      _range = picked;
      _page = 1;
    });
    await _load();
  }

  Future<void> _edit(_Expense? expense) async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController(text: expense?.title ?? '');
    final description = TextEditingController(text: expense?.description ?? '');
    final amount = TextEditingController(text: expense?.amount ?? '');
    var type = expense?.type ?? 'other';
    var saving = false;
    try {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
                builder: (dialogContext, update) => AlertDialog(
                  backgroundColor: AppColors.panelFor(dialogContext),
                  title: Text(expense == null ? 'New Expense' : 'Edit Expense'),
                  content: SizedBox(
                      width: 460,
                      child: SingleChildScrollView(
                          child: Form(
                        key: key,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              controller: title,
                              maxLength: 200,
                              decoration:
                                  const InputDecoration(labelText: 'Title *'),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Title is required'
                                      : null),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                              initialValue: type,
                              decoration:
                                  const InputDecoration(labelText: 'Type *'),
                              items: _types.entries
                                  .map((entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value)))
                                  .toList(),
                              onChanged: (value) =>
                                  update(() => type = value ?? 'other')),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Amount (TND) *'),
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (!RegExp(r'^\d+(\.\d{1,3})?$')
                                        .hasMatch(text) ||
                                    (double.tryParse(text) ?? 0) <= 0) {
                                  return 'Enter a positive amount (max 3 decimals)';
                                }
                                return null;
                              }),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: description,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Description (optional)')),
                          if (expense != null) ...[
                            const SizedBox(height: 12),
                            Text(
                                'Created ${DateFormat('dd/MM/yyyy HH:mm').format(expense.createdAt)}',
                                style: AppTextStyles.bodySm),
                          ],
                          const SizedBox(height: 12),
                          Text(
                              'Do not duplicate supplier costs already recorded as purchases.',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.warning)),
                        ]),
                      ))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!key.currentState!.validate()) return;
                                if (ref.read(testModeProvider).isActive) {
                                  Navigator.pop(dialogContext);
                                  return;
                                }
                                update(() => saving = true);
                                try {
                                  final data = {
                                    'title': title.text.trim(),
                                    'description': description.text.trim(),
                                    'type': type,
                                    'amount': amount.text.trim()
                                  };
                                  if (expense == null) {
                                    await _client.dio.post(
                                        ApiConstants.expenses,
                                        data: data);
                                  } else {
                                    await _client.dio.patch(
                                        '${ApiConstants.expenses}${expense.id}/',
                                        data: data);
                                  }
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                  setState(() => _page = 1);
                                  await _load();
                                } catch (error) {
                                  if (!dialogContext.mounted || !mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              _client.describeError(error)),
                                          backgroundColor: AppColors.error));
                                  update(() => saving = false);
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save Expense')),
                  ],
                ),
              ));
    } finally {
      title.dispose();
      description.dispose();
      amount.dispose();
    }
  }

  Future<void> _delete(_Expense expense) async {
    if (ref.read(testModeProvider).isActive) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Delete expense?'),
              content: Text(
                  'Delete “${expense.title}”? This changes the statistics totals.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete')),
              ],
            ));
    if (accepted != true || !mounted) return;
    try {
      await _client.dio.delete('${ApiConstants.expenses}${expense.id}/');
      if (!mounted) return;
      if (_page > 1 && _rows.length == 1) _page--;
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _client.describeError(error));
    }
  }

  Widget _expenseCard(BuildContext context, _Expense expense) {
    final textColor = AppColors.textPrimaryFor(context);
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(expense.title,
          style: AppTextStyles.title.copyWith(color: textColor)),
      const SizedBox(height: 3),
      Text(
        '${_types[expense.type] ?? expense.type} • ${DateFormat('dd/MM/yyyy HH:mm').format(expense.createdAt)}',
        style: AppTextStyles.bodySm
            .copyWith(color: AppColors.textSecondaryFor(context)),
      ),
      if (expense.description.isNotEmpty)
        Text(expense.description,
            style: AppTextStyles.bodySm
                .copyWith(color: AppColors.textSecondaryFor(context))),
    ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${expense.amount} TND',
          style: AppTextStyles.titleSm.copyWith(color: textColor)),
      IconButton(
          onPressed: () => _edit(expense),
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Edit'),
      IconButton(
          onPressed: () => _delete(expense),
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Delete'),
    ]);
    return Card(
      color: AppColors.panelFor(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actions),
                ]);
          }
          return Row(children: [
            Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.blueSurface,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.blue)),
            const SizedBox(width: 12),
            Expanded(child: details),
            const SizedBox(width: 8),
            actions,
          ]);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final textColor = AppColors.textPrimaryFor(context);
    if (ref.watch(testModeProvider).isActive) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  'Other expenses are unavailable in training mode. No real finance data can be changed.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(color: textColor))));
    }
    return Column(children: [
      Container(
          padding: EdgeInsets.all(layout.pagePadding),
          color: AppColors.surfaceFor(context),
          child: Row(children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.accentFor(context)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Other Expenses',
                    style: AppTextStyles.h4.copyWith(color: textColor))),
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh'),
            const SizedBox(width: 8),
            FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add')),
          ])),
      Expanded(
          child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  padding: EdgeInsets.all(layout.pagePadding),
                  children: [
                    Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.blueDark, AppColors.blue]),
                            borderRadius: BorderRadius.circular(16)),
                        child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              const Text('Filtered expense total',
                                  style: TextStyle(color: Colors.white70)),
                              Text('$_total TND',
                                  style: AppTextStyles.h2
                                      .copyWith(color: Colors.white)),
                              Text('$_count records',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ])),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      SizedBox(
                          width: 175,
                          child: DropdownButtonFormField<String>(
                              key: ValueKey(_period),
                              initialValue: _period,
                              decoration:
                                  const InputDecoration(labelText: 'Period'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'today', child: Text('Today')),
                                DropdownMenuItem(
                                    value: 'this_week',
                                    child: Text('This Week')),
                                DropdownMenuItem(
                                    value: 'this_month',
                                    child: Text('This Month')),
                                DropdownMenuItem(
                                    value: 'this_year',
                                    child: Text('This Year')),
                                DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Custom Range')),
                              ],
                              onChanged: (value) async {
                                if (value == 'custom') {
                                  await _selectRange();
                                  return;
                                }
                                if (value == null) return;
                                setState(() {
                                  _period = value;
                                  _page = 1;
                                });
                                await _load();
                              })),
                      SizedBox(
                          width: 175,
                          child: DropdownButtonFormField<String>(
                              initialValue: _type ?? '',
                              decoration:
                                  const InputDecoration(labelText: 'Type'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All Types')),
                                ..._types.entries.map((entry) =>
                                    DropdownMenuItem(
                                        value: entry.key,
                                        child: Text(entry.value)))
                              ],
                              onChanged: (value) async {
                                setState(() {
                                  _type = value == null || value.isEmpty
                                      ? null
                                      : value;
                                  _page = 1;
                                });
                                await _load();
                              })),
                      if (_period == 'custom')
                        OutlinedButton.icon(
                            onPressed: _selectRange,
                            icon: const Icon(Icons.date_range_rounded),
                            label: Text(_range == null
                                ? 'Choose dates'
                                : '${DateFormat('dd/MM/yy').format(_range!.start)} – ${DateFormat('dd/MM/yy').format(_range!.end)}')),
                    ]),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.error))),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(28),
                              child: CircularProgressIndicator()))
                    else if (_rows.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                              child: Text('No expenses for this period.',
                                  style: AppTextStyles.body
                                      .copyWith(color: textColor))))
                    else
                      ..._rows.map((expense) => _expenseCard(context, expense)),
                    if (!_loading && _count > 50)
                      Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                    onPressed: _page > 1
                                        ? () {
                                            setState(() => _page--);
                                            _load();
                                          }
                                        : null,
                                    child: const Text('Previous')),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: Text(
                                        '$_page / ${(_count + 49) ~/ 50}',
                                        style: AppTextStyles.body)),
                                OutlinedButton(
                                    onPressed: _page * 50 < _count
                                        ? () {
                                            setState(() => _page++);
                                            _load();
                                          }
                                        : null,
                                    child: const Text('Next')),
                              ])),
                    const SizedBox(height: 16),
                  ]))),
    ]);
  }
}
