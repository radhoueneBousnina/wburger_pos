import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

part 'receipt_printer_backend_io/unix_printing.dart';
part 'receipt_printer_backend_io/windows_printing.dart';
part 'receipt_printer_backend_io/command_runner.dart';

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
    if (Platform.isWindows) {
      return Isolate.run(() => _printTicketOnWindows(jobName, bytes));
    }

    if (Platform.isLinux || Platform.isMacOS) {
      return Isolate.run(() => _printTicketOnUnix(jobName, bytes));
    }

    return const RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      unsupportedPlatform: true,
    );
  }

  Future<bool> connectPrinter() async => true;

  Future<RawCashDrawerStatusResult> readCashDrawerStatus() async {
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        return await Isolate.run(_readCashDrawerStatusOnUnix)
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        return const RawCashDrawerStatusResult(
          supported: false,
          error: 'Cash drawer status query timed out.',
        );
      } catch (error) {
        return RawCashDrawerStatusResult(
          supported: false,
          error: 'Cash drawer status query failed: ${error.toString()}',
        );
      }
    }

    return const RawCashDrawerStatusResult(
      supported: false,
      error: 'Cash drawer status detection is not available on this platform.',
    );
  }
}

RawTicketPrinterBackend createRawTicketPrinterBackend() {
  return const RawTicketPrinterBackend();
}
