part of '../receipt_printer_service.dart';

class ReceiptPrinterService {
  ReceiptPrinterService._();
  static final ReceiptPrinterService instance = ReceiptPrinterService._();
  static const bool _drawerOpenWhenPin3High = bool.fromEnvironment(
    'CASH_DRAWER_OPEN_WHEN_PIN3_HIGH',
    defaultValue: true,
  );
  static const Duration _expectedDrawerOpenWindow = Duration(seconds: 12);

  final ReceiptTicketBuilder _ticketBuilder = const ReceiptTicketBuilder();

  final RawTicketPrinterBackend _backend = createRawTicketPrinterBackend();
  DateTime? _expectedDrawerOpenUntil;

  Future<bool> connectWebPrinter() async {
    if (kIsWeb) {
      return await _backend.connectPrinter();
    }
    return true;
  }

  Future<ReceiptPrintResult> printReceipt(
    ReceiptData data, {
    ReceiptPrinterConfig config = defaultReceiptPrinterConfig,
    bool? openDrawer,
    bool allowBrowserFallback = true,
  }) async {
    final shouldOpenDrawer = shouldOpenDrawerForReceipt(
      data,
      explicitOpenDrawer: openDrawer,
    );
    if (shouldOpenDrawer) {
      markDrawerOpenExpected();
    }
    if (kDebugMode) {
      debugPrint(
        '[Printer] printReceipt() called for ticket: ${data.ticketNumber}, openDrawer=$shouldOpenDrawer',
      );
    }
    try {
      final printedAt = DateTime.now();
      final bytes = await buildReceiptTicketBytes(
        data,
        config: config,
        printedAt: printedAt,
        openDrawer: shouldOpenDrawer,
      );
      if (kDebugMode) {
        debugPrint(
          '[Printer] Built ticket payload: ${bytes.length} bytes, '
          'paper=${config.paperSize.widthMm}mm, '
          'mode=${config.useEscPosFormatting ? 'escpos' : 'plain-raw-text'}',
        );
      }
      final result = await _backend.printTicket(
        jobName: _jobName(data),
        bytes: bytes,
        paperWidthMm: config.paperSize.widthMm,
        previewText: buildPreviewText(
          data,
          config: config,
          printedAt: printedAt,
        ),
        allowBrowserFallback: allowBrowserFallback,
      );
      final out = ReceiptPrintResult(
        printerCount: result.printerCount,
        printedCount: result.printedCount,
        failedPrinters: result.failedPrinters,
        unsupportedPlatform: result.unsupportedPlatform,
        error: result.error,
        successMessage: result.successMessage,
      );
      if (kDebugMode) {
        debugPrint(
          '[Printer] Result: printers=${out.printerCount}, printed=${out.printedCount}, '
          'unsupported=${out.unsupportedPlatform}, error=${out.error}, '
          'failed=${out.failedPrinters}',
        );
      }
      if (out.isSuccess) {
        PosMonitoringService.instance.updatePrinterStatus('ok');
      } else {
        PosMonitoringService.instance.recordPrinterFailure(
          out.message,
          metadata: {
            'ticket_number': data.ticketNumber,
            'failed_printers': out.failedPrinters,
          },
        );
      }
      return out;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Printer] Exception during printReceipt: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      PosMonitoringService.instance.recordPrinterFailure(
        'Thermal ticket printing failed. Check printer connection and try again.',
        metadata: {
          'ticket_number': data.ticketNumber,
          'error': error.toString()
        },
      );
      return ReceiptPrintResult(
        printerCount: 0,
        printedCount: 0,
        error:
            'Thermal ticket printing failed. Check printer connection and try again.',
      );
    }
  }

  Future<ReceiptPrintResult> printOrderReceipt(
    Order order, {
    String? cashierName,
    bool isReprint = false,
    ReceiptPrinterConfig config = defaultReceiptPrinterConfig,
    bool? openDrawer,
  }) {
    return printReceipt(
      ReceiptData.fromOrder(
        order,
        cashierName: cashierName,
        isReprint: isReprint,
      ),
      config: config,
      openDrawer: openDrawer,
    );
  }

  Future<ReceiptPrintResult> printSampleReceipt({
    ReceiptPrinterConfig config = defaultReceiptPrinterConfig,
  }) {
    return printReceipt(
      ReceiptData.sampleTestReceipt(),
      config: config,
    );
  }

  Future<ReceiptPrintResult> printHardwareSmokeTest({
    ReceiptPrinterConfig config = const ReceiptPrinterConfig.mm80(),
  }) async {
    if (kDebugMode) {
      debugPrint('[Printer] printHardwareSmokeTest() called');
    }
    try {
      final bytes = ReceiptTicketBuilder.buildSmokeTestBytes(config);
      final result = await _backend.printTicket(
        jobName: 'W Burger Printer Smoke Test',
        bytes: bytes,
        paperWidthMm: config.paperSize.widthMm,
        previewText: ReceiptTicketBuilder.buildSmokeTestPreview(config),
      );
      final out = ReceiptPrintResult(
        printerCount: result.printerCount,
        printedCount: result.printedCount,
        failedPrinters: result.failedPrinters,
        unsupportedPlatform: result.unsupportedPlatform,
        error: result.error,
        successMessage: result.successMessage,
      );
      if (out.isSuccess) {
        PosMonitoringService.instance.updatePrinterStatus('ok');
      } else {
        PosMonitoringService.instance.recordPrinterFailure(out.message);
      }
      return out;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Printer] Smoke test exception: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      PosMonitoringService.instance.recordPrinterFailure(
        'Printer smoke test failed. Check printer connection and try again.',
        metadata: {'error': error.toString()},
      );
      return ReceiptPrintResult(
        printerCount: 0,
        printedCount: 0,
        error:
            'Printer smoke test failed. Check printer connection and try again.',
      );
    }
  }

  Future<ReceiptPrintResult> openCashDrawer({
    ReceiptPrinterConfig config = defaultReceiptPrinterConfig,
  }) async {
    if (kDebugMode) {
      debugPrint('[Printer] openCashDrawer() called');
    }
    markDrawerOpenExpected();
    try {
      final bytes = buildCashDrawerPulseBytes();
      final result = await _backend.printTicket(
        jobName: 'W Burger Cash Drawer',
        bytes: bytes,
        paperWidthMm: config.paperSize.widthMm,
        allowBrowserFallback: false,
      );
      final out = ReceiptPrintResult(
        printerCount: result.printerCount,
        printedCount: result.printedCount,
        failedPrinters: result.failedPrinters,
        unsupportedPlatform: result.unsupportedPlatform,
        error: result.error,
        successMessage: result.successMessage ??
            'Cash drawer pulse sent to the thermal printer.',
      );
      if (out.isSuccess) {
        PosMonitoringService.instance.updatePrinterStatus('ok');
      } else {
        PosMonitoringService.instance.recordPrinterFailure(out.message);
      }
      return out;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Printer] Cash drawer open exception: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      PosMonitoringService.instance.recordPrinterFailure(
        'Cash drawer open failed. Check printer connection and try again.',
        metadata: {'error': error.toString()},
      );
      return ReceiptPrintResult(
        printerCount: 0,
        printedCount: 0,
        error:
            'Cash drawer open failed. Check printer connection and try again.',
      );
    }
  }

  Future<CashDrawerStatusResult> readCashDrawerStatus() async {
    try {
      final result = await _backend.readCashDrawerStatus();
      final isOpen = result.isOpen ??
          (result.pin3High == null
              ? null
              : result.pin3High == _drawerOpenWhenPin3High);
      return CashDrawerStatusResult(
        supported: result.supported,
        isOpen: isOpen,
        pin3High: result.pin3High,
        source: result.source,
        error: result.error,
      );
    } catch (error) {
      return CashDrawerStatusResult(
        supported: false,
        error: 'Cash drawer status query failed: ${error.toString()}',
      );
    }
  }

  void markDrawerOpenExpected({
    Duration window = _expectedDrawerOpenWindow,
  }) {
    _expectedDrawerOpenUntil = DateTime.now().add(window);
  }

  bool consumeExpectedDrawerOpen() {
    final expectedUntil = _expectedDrawerOpenUntil;
    if (expectedUntil == null) return false;

    _expectedDrawerOpenUntil = null;
    return DateTime.now().isBefore(expectedUntil);
  }

  Uint8List buildCashDrawerPulseBytes({
    int pin = 0,
    int onTime = 40,
    int offTime = 200,
  }) {
    return ReceiptTicketBuilder.buildCashDrawerPulseBytes(
      pin: pin,
      onTime: onTime,
      offTime: offTime,
    );
  }

  Future<Uint8List> buildReceiptTicketBytes(
    ReceiptData data, {
    ReceiptPrinterConfig config = defaultReceiptPrinterConfig,
    DateTime? printedAt,
    bool openDrawer = false,
  }) {
    return _ticketBuilder.buildBytes(
      data,
      config: config,
      printedAt: printedAt,
      includeLogo: true,
      openDrawer: openDrawer,
    );
  }

  Uint8List buildTicketBytes(
    ReceiptData data, {
    ReceiptPrinterConfig config = const ReceiptPrinterConfig.mm80(),
    DateTime? printedAt,
  }) {
    return _ticketBuilder.buildBytesSync(
      data,
      config: config,
      printedAt: printedAt,
    );
  }

  String buildPreviewText(
    ReceiptData data, {
    ReceiptPrinterConfig config = const ReceiptPrinterConfig.mm80(),
    DateTime? printedAt,
  }) {
    return _ticketBuilder.buildPreviewText(
      data,
      config: config,
      printedAt: printedAt,
    );
  }

  String _jobName(ReceiptData data) {
    final ticket =
        data.ticketNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return 'W Burger Ticket $ticket';
  }

  bool shouldOpenDrawerForReceipt(
    ReceiptData data, {
    bool? explicitOpenDrawer,
  }) {
    if (explicitOpenDrawer != null) return explicitOpenDrawer;
    return !data.isReprint && data.paymentType == PaymentType.cash;
  }
}
