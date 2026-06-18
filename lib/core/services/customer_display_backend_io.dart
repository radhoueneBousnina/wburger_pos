import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'customer_display_backend.dart';

CustomerDisplayBackend createCustomerDisplayBackend() =>
    const _IoCustomerDisplayBackend();

class _IoCustomerDisplayBackend implements CustomerDisplayBackend {
  const _IoCustomerDisplayBackend();

  @override
  Future<CustomerDisplayBackendResult> showAmount({
    required String label,
    required String amountText,
    String? preferredSource,
  }) async {
    if (!Platform.isWindows) {
      return const CustomerDisplayBackendResult.disabled();
    }

    return Isolate.run(() {
      final settings = _CustomerDisplaySettings.fromEnvironment();
      if (!settings.isConfigured && !settings.autoDetect) {
        return const CustomerDisplayBackendResult.disabled();
      }

      final payload = _CustomerDisplayPayloadBuilder(settings).build(
        label: label,
        amountText: amountText,
      );
      final targets = settings.targets(preferredSource: preferredSource);
      if (targets.isEmpty) {
        return const CustomerDisplayBackendResult.failed(
          error: 'No customer display serial ports were found.',
        );
      }

      final failures = <String>[];
      for (final target in targets) {
        try {
          switch (target.kind) {
            case _CustomerDisplayTargetKind.serial:
              _WindowsCustomerDisplaySerialWriter().write(
                portName: target.name,
                baudRate: settings.baudRate,
                bytes: payload,
              );
              break;
            case _CustomerDisplayTargetKind.printer:
              _WindowsCustomerDisplayPrinterWriter().writeRawBytes(
                printerName: target.name,
                jobName: 'W Burger Customer Display',
                bytes: payload,
              );
              break;
          }
          return CustomerDisplayBackendResult.ok(source: target.name);
        } catch (error) {
          failures.add('${target.name}: $error');
        }
      }

      return CustomerDisplayBackendResult.failed(
        source: targets.first.name,
        error: failures.isEmpty
            ? 'Customer display write failed.'
            : 'Customer display write failed. Tried ${failures.join('; ')}',
      );
    }).timeout(
      const Duration(seconds: 2),
      onTimeout: () => const CustomerDisplayBackendResult.failed(
        error: 'Customer display write timed out.',
      ),
    );
  }
}

class _CustomerDisplaySettings {
  static const String _portConfig =
      String.fromEnvironment('CUSTOMER_DISPLAY_PORT');
  static const String _posPortConfig =
      String.fromEnvironment('POS_CUSTOMER_DISPLAY_PORT');
  static const String _printerConfig =
      String.fromEnvironment('CUSTOMER_DISPLAY_PRINTER_NAME');
  static const String _posPrinterConfig =
      String.fromEnvironment('POS_CUSTOMER_DISPLAY_PRINTER_NAME');
  static const String _baudConfig =
      String.fromEnvironment('CUSTOMER_DISPLAY_BAUD');
  static const String _modeConfig =
      String.fromEnvironment('CUSTOMER_DISPLAY_MODE');
  static const String _autoConfig =
      String.fromEnvironment('CUSTOMER_DISPLAY_AUTO');

  final String? portName;
  final String? printerName;
  final int baudRate;
  final String mode;
  final bool autoDetect;

  const _CustomerDisplaySettings({
    required this.portName,
    required this.printerName,
    required this.baudRate,
    required this.mode,
    required this.autoDetect,
  });

  bool get isConfigured => portName != null || printerName != null;

  factory _CustomerDisplaySettings.fromEnvironment() {
    final portName = _firstConfiguredValue([
          _portConfig,
          _posPortConfig,
          Platform.environment['CUSTOMER_DISPLAY_PORT'] ?? '',
          Platform.environment['POS_CUSTOMER_DISPLAY_PORT'] ?? '',
        ]) ??
        'COM8';
    final printerName = _firstConfiguredValue([
      _printerConfig,
      _posPrinterConfig,
      Platform.environment['CUSTOMER_DISPLAY_PRINTER_NAME'] ?? '',
      Platform.environment['POS_CUSTOMER_DISPLAY_PRINTER_NAME'] ?? '',
    ]);
    final baudRaw = _firstConfiguredValue([
      _baudConfig,
      Platform.environment['CUSTOMER_DISPLAY_BAUD'] ?? '',
    ]);
    final mode = _firstConfiguredValue([
          _modeConfig,
          Platform.environment['CUSTOMER_DISPLAY_MODE'] ?? '',
        ]) ??
        'amount';
    final autoRaw = _firstConfiguredValue([
          _autoConfig,
          Platform.environment['CUSTOMER_DISPLAY_AUTO'] ?? '',
        ]) ??
        'true';

    return _CustomerDisplaySettings(
      portName: portName,
      printerName: printerName,
      baudRate: int.tryParse(baudRaw ?? '') ?? 2400,
      mode: mode.trim().toLowerCase(),
      autoDetect: !_isFalse(autoRaw),
    );
  }

  List<_CustomerDisplayTarget> targets({String? preferredSource}) {
    final targets = <_CustomerDisplayTarget>[];
    final preferred = preferredSource?.trim();
    if (portName != null) {
      targets.add(_CustomerDisplayTarget.serial(portName!));
    }
    if (printerName != null) {
      targets.add(_CustomerDisplayTarget.printer(printerName!));
    }
    if (preferred != null &&
        preferred.isNotEmpty &&
        portName == null &&
        printerName == null) {
      targets.add(_CustomerDisplayTarget.serial(preferred));
    }
    if (autoDetect && portName == null && printerName == null) {
      targets.addAll(_WindowsSerialPortEnumerator().listCustomerDisplayPorts());
    }

    final seen = <String>{};
    return targets.where((target) {
      final key = '${target.kind.name}:${target.name.toLowerCase()}';
      return seen.add(key);
    }).toList();
  }

  static String? _firstConfiguredValue(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static bool _isFalse(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == '0' ||
        normalized == 'false' ||
        normalized == 'no' ||
        normalized == 'off';
  }
}

enum _CustomerDisplayTargetKind { serial, printer }

class _CustomerDisplayTarget {
  final _CustomerDisplayTargetKind kind;
  final String name;

  const _CustomerDisplayTarget._({
    required this.kind,
    required this.name,
  });

  factory _CustomerDisplayTarget.serial(String name) =>
      _CustomerDisplayTarget._(
        kind: _CustomerDisplayTargetKind.serial,
        name: name,
      );

  factory _CustomerDisplayTarget.printer(String name) =>
      _CustomerDisplayTarget._(
        kind: _CustomerDisplayTargetKind.printer,
        name: name,
      );
}

class _WindowsSerialPortEnumerator {
  List<_CustomerDisplayTarget> listCustomerDisplayPorts() {
    final entries = _listWindowsSerialPorts();
    if (entries.isEmpty) {
      return _fallbackPorts().map(_CustomerDisplayTarget.serial).toList();
    }

    entries.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.portNumber.compareTo(a.portNumber);
    });

    return entries
        .where((entry) => entry.portName.isNotEmpty)
        .map((entry) => _CustomerDisplayTarget.serial(entry.portName))
        .toList();
  }

  List<_SerialPortEntry> _listWindowsSerialPorts() {
    try {
      final result = Process.runSync(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          r'Get-CimInstance Win32_SerialPort | ForEach-Object { "$($_.DeviceID)|$($_.Name)|$($_.Description)" }',
        ],
        runInShell: false,
      );
      if (result.exitCode != 0) return const [];
      final output = result.stdout.toString();
      return output
          .split(RegExp(r'\r?\n'))
          .map(_SerialPortEntry.tryParse)
          .whereType<_SerialPortEntry>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> _fallbackPorts() {
    return const [
      'COM8',
      'COM7',
      'COM6',
      'COM9',
      'COM10',
      'COM11',
      'COM12',
      'COM13',
      'COM14',
      'COM15',
      'COM16',
      'COM5',
      'COM4',
      'COM3',
      'COM2',
      'COM1',
    ];
  }
}

class _SerialPortEntry {
  final String portName;
  final String name;
  final String description;

  const _SerialPortEntry({
    required this.portName,
    required this.name,
    required this.description,
  });

  int get portNumber =>
      int.tryParse(portName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get score {
    final value = '$portName $name $description'.toLowerCase();
    var score = 0;
    if (value.contains('customer') ||
        value.contains('display') ||
        value.contains('pole') ||
        value.contains('vfd')) {
      score += 100;
    }
    if (value.contains('usb')) score += 35;
    if (value.contains('prolific') ||
        value.contains('pl2303') ||
        value.contains('ch340')) {
      score += 30;
    }
    if (value.contains('communications port')) score -= 60;
    if (portNumber <= 3) score -= 30;
    return score;
  }

  static _SerialPortEntry? tryParse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('|');
    if (parts.isEmpty) return null;
    final portName = parts[0].trim();
    if (!RegExp(r'^COM\d+$', caseSensitive: false).hasMatch(portName)) {
      return null;
    }
    return _SerialPortEntry(
      portName: portName.toUpperCase(),
      name: parts.length > 1 ? parts[1].trim() : '',
      description: parts.length > 2 ? parts[2].trim() : '',
    );
  }
}

class _CustomerDisplayPayloadBuilder {
  final _CustomerDisplaySettings settings;

  const _CustomerDisplayPayloadBuilder(this.settings);

  Uint8List build({
    required String label,
    required String amountText,
  }) {
    final normalizedLabel = _ascii(label.trim().toUpperCase());
    final normalizedAmount = _ascii(amountText.trim());
    final mode = settings.mode;

    if (mode == 'amount' || mode == 'amount-clear') {
      return Uint8List.fromList([0x0c, ..._bytes('$normalizedAmount\r')]);
    }

    if (mode == 'plain') {
      return _bytes('$normalizedLabel $normalizedAmount\r\n');
    }

    if (mode == 'epson' || mode == 'escpos') {
      return Uint8List.fromList([
        0x1b,
        0x40,
        0x0c,
        ..._bytes('$normalizedLabel\r\n$normalizedAmount'),
      ]);
    }

    return _bytes('$normalizedAmount\r');
  }

  Uint8List _bytes(String value) => Uint8List.fromList(ascii.encode(value));

  String _ascii(String value) {
    return value
        .replaceAll(RegExp(r'[^A-Za-z0-9 .,:;+\-_/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _WindowsCustomerDisplaySerialWriter {
  static const Duration _clearDelay = Duration(milliseconds: 200);

  void write({
    required String portName,
    required int baudRate,
    required Uint8List bytes,
  }) {
    final powershellResult = _writeWithPowerShell(
      portName: portName,
      baudRate: baudRate,
      bytes: bytes,
    );
    if (powershellResult == null) return;
    throw StateError(powershellResult);
  }

  String? _writeWithPowerShell({
    required String portName,
    required int baudRate,
    required Uint8List bytes,
  }) {
    try {
      final clearFirst = bytes.isNotEmpty && bytes.first == 0x0c;
      final textBytes = clearFirst ? Uint8List.sublistView(bytes, 1) : bytes;
      final text = ascii
          .decode(textBytes, allowInvalid: true)
          .replaceAll('\r', '')
          .replaceAll('\n', '');
      final script = [
        r'$ErrorActionPreference = "Stop"',
        r'$port = New-Object System.IO.Ports.SerialPort',
        '\$port.PortName = ${_psString(portName)}',
        '\$port.BaudRate = $baudRate',
        r'$port.Parity = [System.IO.Ports.Parity]::None',
        r'$port.DataBits = 8',
        r'$port.StopBits = [System.IO.Ports.StopBits]::One',
        r'$port.Handshake = [System.IO.Ports.Handshake]::None',
        r'$port.Encoding = [System.Text.Encoding]::ASCII',
        r'$port.WriteTimeout = 1000',
        'try {',
        r'  $port.Open()',
        if (clearFirst) ...[
          r'  $port.Write([byte[]]@(0x0C),0,1)',
          '  Start-Sleep -Milliseconds ${_clearDelay.inMilliseconds}',
        ],
        if (text.isNotEmpty) ...[
          '  \$port.Write(${_psString(text)})',
          r'  $port.Write([char]13)',
        ],
        '  Start-Sleep -Milliseconds 300',
        '} finally {',
        r'  if ($port -and $port.IsOpen) { $port.Close() }',
        '}',
      ].join('; ');

      final result = _runPowerShell(script);
      if (result.exitCode == 0) return null;
      return '${result.stderr}${result.stdout}'.trim();
    } catch (error) {
      return error.toString();
    }
  }

  String _psString(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  ProcessResult _runPowerShell(String script) {
    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final executable =
        '$windir\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    final arguments = [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ];
    try {
      return Process.runSync(executable, arguments, runInShell: false);
    } on ProcessException {
      return Process.runSync('powershell.exe', arguments, runInShell: false);
    }
  }
}

class _WindowsCustomerDisplayPrinterWriter {
  final DynamicLibrary _winspool = DynamicLibrary.open('winspool.drv');
  final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

  late final _OpenPrinterDart _openPrinter = _winspool
      .lookupFunction<_OpenPrinterNative, _OpenPrinterDart>('OpenPrinterW');
  late final _StartDocPrinterDart _startDocPrinter =
      _winspool.lookupFunction<_StartDocPrinterNative, _StartDocPrinterDart>(
    'StartDocPrinterW',
  );
  late final _StartPagePrinterDart _startPagePrinter =
      _winspool.lookupFunction<_StartPagePrinterNative, _StartPagePrinterDart>(
    'StartPagePrinter',
  );
  late final _WritePrinterDart _writePrinter = _winspool
      .lookupFunction<_WritePrinterNative, _WritePrinterDart>('WritePrinter');
  late final _EndPagePrinterDart _endPagePrinter =
      _winspool.lookupFunction<_EndPagePrinterNative, _EndPagePrinterDart>(
    'EndPagePrinter',
  );
  late final _EndDocPrinterDart _endDocPrinter =
      _winspool.lookupFunction<_EndDocPrinterNative, _EndDocPrinterDart>(
    'EndDocPrinter',
  );
  late final _ClosePrinterDart _closePrinter = _winspool
      .lookupFunction<_ClosePrinterNative, _ClosePrinterDart>('ClosePrinter');
  late final _GetLastErrorDart _getLastError = _kernel32
      .lookupFunction<_GetLastErrorNative, _GetLastErrorDart>('GetLastError');

  void writeRawBytes({
    required String printerName,
    required String jobName,
    required Uint8List bytes,
  }) {
    using((Arena alloc) {
      final printerNamePtr = printerName.toNativeUtf16(allocator: alloc);
      final printerHandlePtr = alloc<IntPtr>();
      final opened = _openPrinter(
        printerNamePtr,
        printerHandlePtr,
        nullptr.cast<Void>(),
      );
      if (opened == 0) {
        throw StateError(_windowsError('OpenPrinter'));
      }

      final printerHandle = printerHandlePtr.value;
      var startedDoc = false;
      var startedPage = false;
      try {
        final docInfo = alloc<_DocInfo1>()
          ..ref.pDocName = jobName.toNativeUtf16(allocator: alloc)
          ..ref.pOutputFile = nullptr.cast<Utf16>()
          ..ref.pDatatype = 'RAW'.toNativeUtf16(allocator: alloc);

        if (_startDocPrinter(printerHandle, 1, docInfo) == 0) {
          throw StateError(_windowsError('StartDocPrinter'));
        }
        startedDoc = true;

        if (_startPagePrinter(printerHandle) == 0) {
          throw StateError(_windowsError('StartPagePrinter'));
        }
        startedPage = true;

        final data = alloc<Uint8>(bytes.length);
        data.asTypedList(bytes.length).setAll(0, bytes);
        final written = alloc<Uint32>();
        final writeOk = _writePrinter(
          printerHandle,
          data.cast<Void>(),
          bytes.length,
          written,
        );
        if (writeOk == 0 || written.value != bytes.length) {
          throw StateError(_windowsError('WritePrinter'));
        }
      } finally {
        if (startedPage) _endPagePrinter(printerHandle);
        if (startedDoc) _endDocPrinter(printerHandle);
        _closePrinter(printerHandle);
      }
    });
  }

  String _windowsError(String operation) {
    return '$operation failed with Windows error ${_getLastError()}';
  }
}

base class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

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
