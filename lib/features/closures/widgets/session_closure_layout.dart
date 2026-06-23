// ignore_for_file: invalid_use_of_protected_member

part of '../screens/session_closure_screen.dart';

extension _SessionClosureLayout on _SessionClosureScreenState {
  Widget _buildSessionClosureScreen(BuildContext context) {
    final layout = context.posLayout;
    final orders = ref.watch(ordersProvider).value ?? [];
    final total = orders
        .where((order) => order.status == OrderStatus.validated)
        .fold<double>(0, (sum, order) => sum + order.total);
    final stocksAsync = ref.watch(stockProvider);

    return Column(
      children: [
        Container(
          color: AppColors.surfaceFor(context),
          padding: EdgeInsets.all(layout.pagePadding),
          child: Row(
            children: [
              Text(
                'Session Closure',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
              const Spacer(),
              if (_isForcedClosure)
                Text('Forced closure',
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.warning)),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borderFor(context)),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(layout.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isForcedClosure) _buildForcedClosureNotice(context),
                _buildStepsHeader(),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _EodKpi(
                        label: 'Total Revenue',
                        value: '${total.toStringAsFixed(3)} DT',
                        color: AppColors.accentFor(context),
                        icon: Icons.trending_up_rounded),
                    _EodKpi(
                        label: 'Tickets',
                        value: '${orders.length}',
                        color: AppColors.success,
                        icon: Icons.receipt_rounded),
                    _EodKpi(
                        label: 'Avg. Basket',
                        value: orders.isEmpty
                            ? '- DT'
                            : '${(total / orders.length).toStringAsFixed(3)} DT',
                        color: AppColors.info,
                        icon: Icons.shopping_basket_rounded),
                  ],
                ),
                const SizedBox(height: 18),
                _currentStep == 0
                    ? _buildFinancialStep(context)
                    : stocksAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            Center(child: Text(error.toString())),
                        data: (stocks) {
                          _syncStockControllers(stocks);
                          return _buildStockStep(context, stocks);
                        },
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForcedClosureNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.isTraining(context)
            ? AppColors.warning.withValues(alpha: 0.14)
            : AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Text(
        'Previous session must be closed before continuing.${_previousSessionDate == null || _previousSessionDate!.isEmpty ? '' : ' Session date: $_previousSessionDate.'}',
        style: AppTextStyles.body.copyWith(color: AppColors.warning),
      ),
    );
  }

  Widget _buildStepsHeader() {
    return Row(
      children: [
        Expanded(
          child: _StepTab(
            label: 'Financial',
            icon: Icons.payments_rounded,
            selected: _currentStep == 0,
            done: _financialCompleted,
            onTap: () => setState(() => _currentStep = 0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StepTab(
            label: 'Stock',
            icon: Icons.inventory_2_rounded,
            selected: _currentStep == 1,
            done: false,
            enabled: _financialCompleted,
            onTap: _financialCompleted
                ? () => setState(() => _currentStep = 1)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialStep(BuildContext context) {
    final hasDisc = _hasFinancialDiscrepancy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.panelFor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Column(
            children: [
              const _TheoreticalActualHeader(),
              Divider(height: 24, color: AppColors.borderFor(context)),
              _ComparisonRow(
                  label: 'Cash',
                  theoryAmount: _theoreticalCash,
                  totalRevenue:
                      _theoreticalCash + _theoreticalCard + _theoreticalOther,
                  color: AppColors.success,
                  actualCtrl: _actualCashCtrl,
                  submitted: _submittedFinancial,
                  onChanged: () => setState(() {})),
              const SizedBox(height: 12),
              _ComparisonRow(
                  label: 'Card',
                  theoryAmount: _theoreticalCard,
                  totalRevenue:
                      _theoreticalCash + _theoreticalCard + _theoreticalOther,
                  color: AppColors.accentFor(context),
                  actualCtrl: _actualCardCtrl,
                  submitted: _submittedFinancial,
                  onChanged: () => setState(() => _tpeUploadSession = null)),
              const SizedBox(height: 12),
              _ComparisonRow(
                  label: 'Other',
                  theoryAmount: _theoreticalOther,
                  totalRevenue:
                      _theoreticalCash + _theoreticalCard + _theoreticalOther,
                  color: AppColors.neutral500,
                  actualCtrl: _actualOtherCtrl,
                  submitted: _submittedFinancial,
                  onChanged: () => setState(() {})),
              const SizedBox(height: 12),
              _ComparisonRow(
                  label: 'Fond de caisse',
                  theoryAmount: _theoreticalFloat,
                  totalRevenue: _theoreticalFloat,
                  color: AppColors.warning,
                  actualCtrl: _actualFloatCtrl,
                  submitted: _submittedFinancial,
                  onChanged: () => setState(() {})),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isCreatingTpeUpload ? null : _showTpeQrUploadFlow,
                icon: _isCreatingTpeUpload
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.qr_code_rounded),
                label: Text(_tpeReceiptReady
                    ? 'TPE Receipt Uploaded'
                    : 'Upload TPE Receipt'),
              ),
            ),
          ],
        ),
        if (_submittedFinancial && !_tpeReceiptReady)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('TPE receipt upload is required.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _financialNoteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: hasDisc ? 'Financial note required' : 'Financial note',
            errorText: _submittedFinancial &&
                    hasDisc &&
                    _financialNoteCtrl.text.trim().isEmpty
                ? 'Required when there is a discrepancy'
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitFinancialStep,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue to Stock Verification'),
          ),
        ),
      ],
    );
  }

  Widget _buildStockStep(BuildContext context, List<StockItem> stocks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.panelFor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Column(
            children: [
              for (final stock in stocks)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text(
                            stock.name,
                            style: AppTextStyles.titleSm.copyWith(
                              color: AppColors.textPrimaryFor(context),
                            ),
                          )),
                      Expanded(
                          child: Text(
                        '${stock.quantity.toStringAsFixed(3)} ${stock.unit}',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryFor(context),
                        ),
                      )),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _stockActualControllers[stock.id],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            _SessionClosureScreenState
                                ._stockQuantityInputFormatter,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Actual ${stock.unit}',
                            errorText: _submittedStock &&
                                    (_stockActualControllers[stock.id]
                                            ?.text
                                            .trim()
                                            .isEmpty ??
                                        true)
                                ? 'Required'
                                : null,
                          ),
                          onChanged: (_) => setState(
                            () => _stockDocumentUploadSession = null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _UploadBox(
          isUploaded: _stockDocumentReady,
          isLoading: _isCreatingStockDocumentUpload,
          fileName: _stockDocumentUploadSession?.originalFilename,
          hasError: _submittedStock && !_stockDocumentReady,
          label: 'Scan QR to upload signed stock document',
          uploadedLabel: 'Signed stock document uploaded',
          onTap: _isCreatingStockDocumentUpload
              ? null
              : () => _showStockDocumentQrUploadFlow(stocks),
        ),
        if (_submittedStock && !_stockDocumentReady)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Signed stock document upload is required.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _stockNoteCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText:
                _hasStockDiscrepancy ? 'Stock note required' : 'Stock note',
            errorText: _submittedStock &&
                    _hasStockDiscrepancy &&
                    _stockNoteCtrl.text.trim().isEmpty
                ? 'Required when there is a discrepancy'
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isClosingSession ? null : _submitStockStep,
                icon: _isClosingSession
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_rounded),
                label: Text(_isClosingSession ? 'Closing...' : 'Close Session'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
