part of '../screens/create_purchase_screen.dart';

class _PurchaseInvoiceQrDialog extends StatefulWidget {
  final PurchaseInvoiceUploadSession initialSession;
  final PurchasesNotifier purchasesNotifier;
  final ValueChanged<PurchaseInvoiceUploadSession> onUploaded;

  const _PurchaseInvoiceQrDialog({
    required this.initialSession,
    required this.purchasesNotifier,
    required this.onUploaded,
  });

  @override
  State<_PurchaseInvoiceQrDialog> createState() =>
      _PurchaseInvoiceQrDialogState();
}

class _PurchaseInvoiceQrDialogState extends State<_PurchaseInvoiceQrDialog> {
  late PurchaseInvoiceUploadSession _session;
  Timer? _pollTimer;
  bool _isRefreshing = false;
  bool _notifiedUploaded = false;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (_session.isUploaded || _session.isExpired) return;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshStatus(),
    );
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing || _session.isUploaded) return;
    setState(() => _isRefreshing = true);
    try {
      final latest = await widget.purchasesNotifier.fetchInvoiceUploadSession(
        purchaseId: _session.purchaseId,
        token: _session.token,
      );
      if (!mounted) return;
      setState(() => _session = latest);
      if (latest.isUploaded && !_notifiedUploaded) {
        _notifiedUploaded = true;
        _pollTimer?.cancel();
        widget.onUploaded(latest);
      }
      if (latest.isExpired) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Keep the QR visible if a transient poll fails.
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _session.uploadUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload link copied.')),
    );
  }

  String _money(double value) => '${value.toStringAsFixed(3)} DT';

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 14 : 28,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                color: AppColors.blue,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Purchase Invoice QR',
                            style: AppTextStyles.h4
                                .copyWith(color: AppColors.white),
                          ),
                          Text(
                            'Purchase #${_session.purchaseId}'
                            '${_session.sessionDate == null ? '' : ' - ${_session.sessionDate}'}',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.white,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(layout.isCompact ? 18 : 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < 540;
                    final qrPanel = Container(
                      width: stack ? double.infinity : 252,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.neutral100),
                            ),
                            child: QrImageView(
                              data: _session.uploadUrl,
                              version: QrVersions.auto,
                              size: stack ? 220 : 200,
                              backgroundColor: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _session.isUploaded
                                ? 'Invoice received'
                                : 'Scan with phone',
                            style: AppTextStyles.titleSm.copyWith(
                              color: _session.isUploaded
                                  ? AppColors.success
                                  : AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    );

                    final detailsPanel = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.blueSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Purchase Total',
                                  style: AppTextStyles.label),
                              Text(
                                _money(_session.purchaseTotalAmount),
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InvoiceStatusBanner(
                          icon: _session.isUploaded
                              ? Icons.check_circle_rounded
                              : (_session.isExpired
                                  ? Icons.timer_off_rounded
                                  : Icons.phone_iphone_rounded),
                          title: _session.isUploaded
                              ? 'Upload complete'
                              : (_session.isExpired
                                  ? 'QR expired'
                                  : 'Waiting for phone upload'),
                          message: _session.isUploaded
                              ? (_session.originalFilename == null ||
                                      _session.originalFilename!.isEmpty
                                  ? 'The invoice is attached to this purchase.'
                                  : _session.originalFilename!)
                              : (_session.isExpired
                                  ? 'Generate a new QR code from the POS.'
                                  : 'The mobile page has camera and file upload buttons.'),
                          color: _session.isUploaded
                              ? AppColors.success
                              : (_session.isExpired
                                  ? AppColors.error
                                  : AppColors.blue),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyLink,
                                icon: const Icon(Icons.link_rounded),
                                label: const Text('Copy Link'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _session.isUploaded
                                    ? () => Navigator.pop(context)
                                    : (_isRefreshing ? null : _refreshStatus),
                                icon: _session.isUploaded
                                    ? const Icon(Icons.done_rounded)
                                    : (_isRefreshing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.white,
                                            ),
                                          )
                                        : const Icon(Icons.refresh_rounded)),
                                label: Text(
                                  _session.isUploaded ? 'Done' : 'Refresh',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    if (stack) {
                      return Column(
                        children: [
                          qrPanel,
                          const SizedBox(height: 18),
                          detailsPanel,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        qrPanel,
                        const SizedBox(width: 20),
                        Expanded(child: detailsPanel),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceStatusBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _InvoiceStatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSm.copyWith(color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceUpload extends StatelessWidget {
  final bool isUploaded;
  final bool isLoading;
  final String? fileName;
  final bool hasError;
  final VoidCallback? onTap;

  const _InvoiceUpload({
    required this.isUploaded,
    required this.isLoading,
    required this.fileName,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isUploaded
              ? AppColors.success.withValues(alpha: 0.05)
              : (hasError
                  ? AppColors.error.withValues(alpha: 0.05)
                  : AppColors.neutral50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded
                ? AppColors.success
                : (hasError ? AppColors.error : AppColors.border),
            width: isUploaded || hasError ? 2 : 1,
            style: isUploaded ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: isUploaded ? _buildUploadedState() : _buildUploadPlaceholder(),
      ),
    );
  }

  Widget _buildUploadedState() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: AppColors.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Attached',
                    style:
                        AppTextStyles.title.copyWith(color: AppColors.success)),
                const SizedBox(height: 4),
                Text(
                  fileName == null || fileName!.isEmpty
                      ? 'Invoice uploaded from phone'
                      : fileName!,
                  style: AppTextStyles.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text('Tap to view QR status',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.success)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
        else
          Icon(
            Icons.qr_code_2_rounded,
            size: 40,
            color: hasError ? AppColors.error : AppColors.blue,
          ),
        const SizedBox(height: 12),
        Text(
          isLoading ? 'Creating QR code...' : 'Scan QR to upload invoice',
          style: AppTextStyles.title.copyWith(
            color: hasError ? AppColors.error : AppColors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Photo required for confirmation',
          style: AppTextStyles.bodySm.copyWith(
            color: hasError ? AppColors.error : AppColors.neutral500,
          ),
        ),
      ],
    );
  }
}
