import 'dart:typed_data';

class RawTicketPrinterBackendResult {
  final int printerCount;
  final int printedCount;
  final List<String> failedPrinters;
  final bool unsupportedPlatform;
  final String? error;
  final String? successMessage;

  const RawTicketPrinterBackendResult({
    required this.printerCount,
    required this.printedCount,
    this.failedPrinters = const [],
    this.unsupportedPlatform = false,
    this.error,
    this.successMessage,
  });
}

class RawCashDrawerStatusResult {
  final bool supported;
  final bool? isOpen;
  final bool? pin3High;
  final String? source;
  final String? error;

  const RawCashDrawerStatusResult({
    required this.supported,
    this.isOpen,
    this.pin3High,
    this.source,
    this.error,
  });
}

class RawTicketPrinterBackend {
  const RawTicketPrinterBackend();

  Future<RawTicketPrinterBackendResult> printTicket({
    required String jobName,
    required Uint8List bytes,
    int? paperWidthMm,
    String? previewText,
  }) async {
    return const RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      unsupportedPlatform: true,
    );
  }

  Future<bool> connectPrinter() async => true;

  Future<RawCashDrawerStatusResult> readCashDrawerStatus() async {
    return const RawCashDrawerStatusResult(
      supported: false,
      error: 'Cash drawer status detection is not available here.',
    );
  }
}

RawTicketPrinterBackend createRawTicketPrinterBackend() {
  return const RawTicketPrinterBackend();
}
