part of '../receipt_printer_backend_io.dart';

String _cupsJobName(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'W Burger Ticket';
  return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
}

String _commandError(String executable, _CommandResult result) {
  final stderr = result.stderr.trim();
  final stdout = result.stdout.trim();
  final detail = stderr.isNotEmpty
      ? stderr
      : stdout.isNotEmpty
          ? stdout
          : 'exit code ${result.exitCode}';
  return '$executable failed: $detail';
}

Future<_CommandResult?> _runCommand(
  String executable,
  List<String> arguments, {
  Uint8List? stdinBytes,
  required Duration timeout,
  bool ignoreMissingExecutable = false,
}) async {
  Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      runInShell: false,
    );
  } on ProcessException {
    if (ignoreMissingExecutable) return null;
    rethrow;
  }

  final stdoutFuture = process.stdout.transform(systemEncoding.decoder).join();
  final stderrFuture = process.stderr.transform(systemEncoding.decoder).join();

  try {
    if (stdinBytes != null) {
      process.stdin.add(stdinBytes);
    }
    await process.stdin.close();
  } catch (_) {
    // If CUPS exits early, the exit code and stderr below carry the real error.
  }

  late final int exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    throw TimeoutException(
      '$executable ${arguments.join(' ')} timed out after ${timeout.inSeconds}s',
    );
  }

  return _CommandResult(
    exitCode: exitCode,
    stdout: await stdoutFuture,
    stderr: await stderrFuture,
  );
}

class _CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

base class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

base class _PrinterInfo2 extends Struct {
  external Pointer<Utf16> pServerName;
  external Pointer<Utf16> pPrinterName;
  external Pointer<Utf16> pShareName;
  external Pointer<Utf16> pPortName;
  external Pointer<Utf16> pDriverName;
  external Pointer<Utf16> pComment;
  external Pointer<Utf16> pLocation;
  external Pointer<Void> pDevMode;
  external Pointer<Utf16> pSepFile;
  external Pointer<Utf16> pPrintProcessor;
  external Pointer<Utf16> pDatatype;
  external Pointer<Utf16> pParameters;
  external Pointer<Void> pSecurityDescriptor;

  @Uint32()
  external int attributes;

  @Uint32()
  external int priority;

  @Uint32()
  external int defaultPriority;

  @Uint32()
  external int startTime;

  @Uint32()
  external int untilTime;

  @Uint32()
  external int status;

  @Uint32()
  external int cJobs;

  @Uint32()
  external int averagePpm;
}

base class _CommTimeouts extends Struct {
  @Uint32()
  external int readIntervalTimeout;

  @Uint32()
  external int readTotalTimeoutMultiplier;

  @Uint32()
  external int readTotalTimeoutConstant;

  @Uint32()
  external int writeTotalTimeoutMultiplier;

  @Uint32()
  external int writeTotalTimeoutConstant;
}

typedef _EnumPrintersNative = Int32 Function(
  Uint32 flags,
  Pointer<Utf16> name,
  Uint32 level,
  Pointer<Uint8> printerEnum,
  Uint32 bufferBytes,
  Pointer<Uint32> bytesNeeded,
  Pointer<Uint32> printersReturned,
);
typedef _EnumPrintersDart = int Function(
  int flags,
  Pointer<Utf16> name,
  int level,
  Pointer<Uint8> printerEnum,
  int bufferBytes,
  Pointer<Uint32> bytesNeeded,
  Pointer<Uint32> printersReturned,
);

typedef _OpenPrinterNative = Int32 Function(
  Pointer<Utf16> printerName,
  Pointer<IntPtr> printerHandle,
  Pointer<Void> defaults,
);
typedef _OpenPrinterDart = int Function(
  Pointer<Utf16> printerName,
  Pointer<IntPtr> printerHandle,
  Pointer<Void> defaults,
);

typedef _StartDocPrinterNative = Int32 Function(
  IntPtr printerHandle,
  Uint32 level,
  Pointer<_DocInfo1> docInfo,
);
typedef _StartDocPrinterDart = int Function(
  int printerHandle,
  int level,
  Pointer<_DocInfo1> docInfo,
);

typedef _StartPagePrinterNative = Int32 Function(IntPtr printerHandle);
typedef _StartPagePrinterDart = int Function(int printerHandle);

typedef _WritePrinterNative = Int32 Function(
  IntPtr printerHandle,
  Pointer<Void> buffer,
  Uint32 bufferBytes,
  Pointer<Uint32> bytesWritten,
);
typedef _WritePrinterDart = int Function(
  int printerHandle,
  Pointer<Void> buffer,
  int bufferBytes,
  Pointer<Uint32> bytesWritten,
);

typedef _EndPagePrinterNative = Int32 Function(IntPtr printerHandle);
typedef _EndPagePrinterDart = int Function(int printerHandle);

typedef _EndDocPrinterNative = Int32 Function(IntPtr printerHandle);
typedef _EndDocPrinterDart = int Function(int printerHandle);

typedef _ClosePrinterNative = Int32 Function(IntPtr printerHandle);
typedef _ClosePrinterDart = int Function(int printerHandle);

typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

typedef _CreateFileNative = IntPtr Function(
  Pointer<Utf16> fileName,
  Uint32 desiredAccess,
  Uint32 shareMode,
  Pointer<Void> securityAttributes,
  Uint32 creationDisposition,
  Uint32 flagsAndAttributes,
  IntPtr templateFile,
);
typedef _CreateFileDart = int Function(
  Pointer<Utf16> fileName,
  int desiredAccess,
  int shareMode,
  Pointer<Void> securityAttributes,
  int creationDisposition,
  int flagsAndAttributes,
  int templateFile,
);

typedef _ReadFileNative = Int32 Function(
  IntPtr fileHandle,
  Pointer<Void> buffer,
  Uint32 bytesToRead,
  Pointer<Uint32> bytesRead,
  Pointer<Void> overlapped,
);
typedef _ReadFileDart = int Function(
  int fileHandle,
  Pointer<Void> buffer,
  int bytesToRead,
  Pointer<Uint32> bytesRead,
  Pointer<Void> overlapped,
);

typedef _WriteFileNative = Int32 Function(
  IntPtr fileHandle,
  Pointer<Void> buffer,
  Uint32 bytesToWrite,
  Pointer<Uint32> bytesWritten,
  Pointer<Void> overlapped,
);
typedef _WriteFileDart = int Function(
  int fileHandle,
  Pointer<Void> buffer,
  int bytesToWrite,
  Pointer<Uint32> bytesWritten,
  Pointer<Void> overlapped,
);

typedef _CloseHandleNative = Int32 Function(IntPtr handle);
typedef _CloseHandleDart = int Function(int handle);

typedef _SetCommTimeoutsNative = Int32 Function(
  IntPtr fileHandle,
  Pointer<_CommTimeouts> timeouts,
);
typedef _SetCommTimeoutsDart = int Function(
  int fileHandle,
  Pointer<_CommTimeouts> timeouts,
);
