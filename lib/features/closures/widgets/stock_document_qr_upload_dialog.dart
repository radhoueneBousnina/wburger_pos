part of '../screens/session_closure_screen.dart';

class _StockDocumentQrUploadDialog extends StatefulWidget {
  final StockDocumentUploadSession initialSession;
  final PosSessionService sessionService;
  final ValueChanged<StockDocumentUploadSession> onUploaded;

  const _StockDocumentQrUploadDialog({
    required this.initialSession,
    required this.sessionService,
    required this.onUploaded,
  });

  @override
  State<_StockDocumentQrUploadDialog> createState() =>
      _StockDocumentQrUploadDialogState();
}

class _StockDocumentQrUploadDialogState
    extends State<_StockDocumentQrUploadDialog> {
  static const Duration _pollInterval = Duration(milliseconds: 500);

  late StockDocumentUploadSession _session;
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
    unawaited(_refreshStatus());
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_refreshStatus()),
    );
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing || _session.isUploaded) return;
    _isRefreshing = true;
    try {
      final latest =
          await widget.sessionService.fetchStockDocumentUploadSession(
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
      _isRefreshing = false;
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _session.uploadUrl));
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 14 : 28,
        vertical: 24,
      ),
      backgroundColor: AppColors.panelFor(context),
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
                color: AppColors.modalHeaderFor(context),
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
                        Icons.fact_check_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signed Stock Document QR',
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
                        color: AppColors.elevatedSurfaceFor(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderFor(context)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.neutral200),
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
                                ? 'Document received'
                                : 'Scan with phone',
                            style: AppTextStyles.titleSm.copyWith(
                              color: _session.isUploaded
                                  ? AppColors.success
                                  : AppColors.accentFor(context),
                            ),
                          ),
                        ],
                      ),
                    );

                    final detailsPanel = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StockDocumentStatusBanner(
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
                                  ? 'The signed document is attached to this stock verification.'
                                  : _session.originalFilename!)
                              : (_session.isExpired
                                  ? 'Generate a new QR code from the POS.'
                                  : 'The mobile page has camera and file upload buttons.'),
                          color: _session.isUploaded
                              ? AppColors.success
                              : (_session.isExpired
                                  ? AppColors.error
                                  : AppColors.accentFor(context)),
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
                                    : _refreshStatus,
                                icon: _session.isUploaded
                                    ? const Icon(Icons.done_rounded)
                                    : const Icon(Icons.refresh_rounded),
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

class _StockDocumentStatusBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _StockDocumentStatusBanner({
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
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
