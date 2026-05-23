part of '../screens/sales_screen.dart';

class _TestWebcamQrDialog extends StatefulWidget {
  const _TestWebcamQrDialog();

  @override
  State<_TestWebcamQrDialog> createState() => _TestWebcamQrDialogState();
}

class _TestWebcamQrDialogState extends State<_TestWebcamQrDialog> {
  late final MobileScannerController _controller;
  bool _handledResult = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handledResult) return;

    String? token;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) {
        token = rawValue;
        break;
      }
    }

    if (token == null) return;
    _handledResult = true;
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Dialog(
      insetPadding: EdgeInsets.all(layout.pagePadding),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: EdgeInsets.all(layout.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Test Webcam QR Scan', style: AppTextStyles.h3),
                        const SizedBox(height: 2),
                        Text(
                          'Test only: scan a basket or deal QR with the PC webcam.',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.yellow.withValues(alpha: 0.40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The normal sales screen still listens silently for QR-scanner keyboard input. This dialog is only a temporary webcam helper for testing.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        fit: BoxFit.cover,
                        onDetect: _handleDetection,
                        errorBuilder: (context, error, child) {
                          return Container(
                            color: AppColors.neutral900,
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Camera unavailable: ${error.errorDetails?.message ?? error.toString()}',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.blue.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: layout.isCompact ? 210 : 280,
                          height: layout.isCompact ? 210 : 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.yellow,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neutral900.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Hold the QR inside the frame. Once it is detected, the order is loaded into the POS automatically.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard_return_rounded),
                  label: const Text('Back to POS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
