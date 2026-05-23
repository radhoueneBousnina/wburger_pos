// ignore_for_file: unused_element

part of '../screens/session_closure_screen.dart';

class _TpeQrUploadDialog extends StatefulWidget {
  final TpeReceiptUploadSession initialSession;
  final PosSessionService sessionService;
  final ValueChanged<TpeReceiptUploadSession> onUploaded;

  const _TpeQrUploadDialog({
    required this.initialSession,
    required this.sessionService,
    required this.onUploaded,
  });

  @override
  State<_TpeQrUploadDialog> createState() => _TpeQrUploadDialogState();
}

class _TpeQrUploadDialogState extends State<_TpeQrUploadDialog> {
  late TpeReceiptUploadSession _session;
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
      final latest = await widget.sessionService.fetchTpeReceiptUploadSession(
        sessionId: _session.sessionId,
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
    final differenceColor = _session.differenceAmount.abs() > 0.001
        ? AppColors.error
        : AppColors.success;

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
                            'TPE Receipt QR',
                            style: AppTextStyles.h4
                                .copyWith(color: AppColors.white),
                          ),
                          Text(
                            'Session #${_session.sessionId} - ${_session.sessionDate}',
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
                                ? 'Receipt received'
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
                        Row(
                          children: [
                            Expanded(
                              child: _TpeAmountTile(
                                label: 'System Card',
                                value: _money(_session.systemCardAmount),
                                color: AppColors.blue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _TpeAmountTile(
                                label: 'Actual Card',
                                value: _money(_session.actualCardAmount),
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _TpeStatusBanner(
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
                                  ? 'The receipt is attached to this session.'
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
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: differenceColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: differenceColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Difference', style: AppTextStyles.label),
                              Text(
                                _money(_session.differenceAmount),
                                style: AppTextStyles.title.copyWith(
                                  color: differenceColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
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

class _TpeAmountTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TpeAmountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelSm),
          const SizedBox(height: 7),
          Text(
            value,
            style: AppTextStyles.title.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TpeStatusBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _TpeStatusBanner({
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

class _UploadBox extends StatelessWidget {
  final bool isUploaded;
  final bool isLoading;
  final String? fileName;
  final bool hasError;
  final String label;
  final VoidCallback? onTap;

  const _UploadBox(
      {required this.isUploaded,
      required this.isLoading,
      required this.fileName,
      required this.hasError,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: layout.touchTarget + 16,
          decoration: BoxDecoration(
            color: isUploaded
                ? AppColors.successLight
                : (hasError ? AppColors.errorLight : AppColors.neutral50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUploaded
                  ? AppColors.success
                  : (hasError ? AppColors.error : AppColors.border),
              width: hasError || isUploaded ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else if (isUploaded)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                )
              else
                Icon(
                  Icons.qr_code_2_rounded,
                  color: hasError ? AppColors.error : AppColors.blue,
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isUploaded
                      ? (fileName == null || fileName!.isEmpty
                          ? 'TPE receipt uploaded'
                          : fileName!)
                      : (isLoading ? 'Creating QR code...' : label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm.copyWith(
                    color: isUploaded
                        ? AppColors.success
                        : (hasError ? AppColors.error : AppColors.blue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
