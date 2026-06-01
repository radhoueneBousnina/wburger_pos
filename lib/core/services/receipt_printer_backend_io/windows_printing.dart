part of '../receipt_printer_backend_io.dart';

class _WindowsPrinterSpooler {
  static const int _printerEnumLocal = 0x00000002;
  static const int _printerEnumConnections = 0x00000004;
  static const int _printerAttributeWorkOffline = 0x00000400;
  static const int _printerAttributeFax = 0x00004000;
  static const int _printerStatusError = 0x00000002;
  static const int _printerStatusOffline = 0x00000080;
  static const String _posPrinterNameConfig =
      String.fromEnvironment('POS_PRINTER_NAME');
  static const String _posPrinterNamesConfig =
      String.fromEnvironment('POS_PRINTER_NAMES');
  static const String _rawPrinterNamesConfig =
      String.fromEnvironment('RAW_PRINT_ALLOWED_PRINTERS');

  final DynamicLibrary _winspool = DynamicLibrary.open('winspool.drv');
  final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

  late final _EnumPrintersDart _enumPrinters = _winspool
      .lookupFunction<_EnumPrintersNative, _EnumPrintersDart>('EnumPrintersW');
  late final _GetDefaultPrinterDart _getDefaultPrinter = _winspool
      .lookupFunction<_GetDefaultPrinterNative, _GetDefaultPrinterDart>(
          'GetDefaultPrinterW');
  late final _OpenPrinterDart _openPrinter = _winspool
      .lookupFunction<_OpenPrinterNative, _OpenPrinterDart>('OpenPrinterW');
  late final _StartDocPrinterDart _startDocPrinter =
      _winspool.lookupFunction<_StartDocPrinterNative, _StartDocPrinterDart>(
          'StartDocPrinterW');
  late final _StartPagePrinterDart _startPagePrinter =
      _winspool.lookupFunction<_StartPagePrinterNative, _StartPagePrinterDart>(
          'StartPagePrinter');
  late final _WritePrinterDart _writePrinter = _winspool
      .lookupFunction<_WritePrinterNative, _WritePrinterDart>('WritePrinter');
  late final _EndPagePrinterDart _endPagePrinter =
      _winspool.lookupFunction<_EndPagePrinterNative, _EndPagePrinterDart>(
          'EndPagePrinter');
  late final _EndDocPrinterDart _endDocPrinter =
      _winspool.lookupFunction<_EndDocPrinterNative, _EndDocPrinterDart>(
          'EndDocPrinter');
  late final _ClosePrinterDart _closePrinter = _winspool
      .lookupFunction<_ClosePrinterNative, _ClosePrinterDart>('ClosePrinter');
  late final _GetLastErrorDart _getLastError = _kernel32
      .lookupFunction<_GetLastErrorNative, _GetLastErrorDart>('GetLastError');

  List<_WindowsPrinter> listTicketPrinters() {
    return using((Arena alloc) {
      final bytesNeeded = alloc<Uint32>();
      final printersReturned = alloc<Uint32>();
      final flags = _printerEnumLocal | _printerEnumConnections;

      _enumPrinters(
        flags,
        nullptr.cast<Utf16>(),
        2,
        nullptr.cast<Uint8>(),
        0,
        bytesNeeded,
        printersReturned,
      );

      if (bytesNeeded.value == 0) return <_WindowsPrinter>[];

      final buffer = alloc<Uint8>(bytesNeeded.value);
      final ok = _enumPrinters(
        flags,
        nullptr.cast<Utf16>(),
        2,
        buffer,
        bytesNeeded.value,
        bytesNeeded,
        printersReturned,
      );
      if (ok == 0) {
        throw StateError(_windowsError('EnumPrinters'));
      }

      final printers = <_WindowsPrinter>[];
      final info = buffer.cast<_PrinterInfo2>();
      for (var i = 0; i < printersReturned.value; i++) {
        final item = (info + i).ref;
        final printer = _WindowsPrinter(
          name: _readUtf16(item.pPrinterName),
          driverName: _readUtf16(item.pDriverName),
          portName: _readUtf16(item.pPortName),
          attributes: item.attributes,
          status: item.status,
        );
        if (printer.name.isNotEmpty &&
            !_isOfflineOrError(printer.attributes, printer.status) &&
            !_isFax(printer.attributes) &&
            !_isVirtualPrinter(
              printer.name,
              printer.driverName,
              printer.portName,
            )) {
          printers.add(printer);
        }
      }

      printers.sort((a, b) => a.name.compareTo(b.name));

      final configuredNames = _configuredPrinterNames();
      if (configuredNames.isNotEmpty) {
        return printers
            .where((printer) =>
                configuredNames.contains(_normalizePrinterName(printer.name)))
            .toList();
      }

      final ticketPrinters = printers.where(_isTicketPrinter).toList();
      if (ticketPrinters.isNotEmpty) return ticketPrinters;

      final defaultPrinter = _defaultPrinter(printers, alloc);
      if (defaultPrinter != null) return [defaultPrinter];

      // Many Windows POS installs expose a receipt printer with a generic
      // driver/name. If it is the only real printer, use it; otherwise fail
      // closed unless Windows has an explicit default real printer.
      if (printers.length == 1) return printers;

      return const <_WindowsPrinter>[];
    });
  }

  _WindowsPrinter? _defaultPrinter(
    List<_WindowsPrinter> printers,
    Arena alloc,
  ) {
    final defaultName = _defaultPrinterName(alloc);
    if (defaultName == null) return null;

    final normalizedDefault = _normalizePrinterName(defaultName);
    for (final printer in printers) {
      if (_normalizePrinterName(printer.name) == normalizedDefault) {
        return printer;
      }
    }
    return null;
  }

  String? _defaultPrinterName(Arena alloc) {
    final bufferChars = alloc<Uint32>();
    _getDefaultPrinter(nullptr.cast<Utf16>(), bufferChars);
    if (bufferChars.value == 0) return null;

    final buffer = alloc<Uint16>(bufferChars.value).cast<Utf16>();
    final ok = _getDefaultPrinter(buffer, bufferChars);
    if (ok == 0) return null;

    final name = buffer.toDartString().trim();
    return name.isEmpty ? null : name;
  }

  void printRawBytes({
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

        final docStarted = _startDocPrinter(printerHandle, 1, docInfo);
        if (docStarted == 0) {
          throw StateError(_windowsError('StartDocPrinter'));
        }
        startedDoc = true;

        final pageStarted = _startPagePrinter(printerHandle);
        if (pageStarted == 0) {
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

  bool _isOfflineOrError(int attributes, int status) {
    return (attributes & _printerAttributeWorkOffline) != 0 ||
        (status & _printerStatusOffline) != 0 ||
        (status & _printerStatusError) != 0;
  }

  bool _isFax(int attributes) => (attributes & _printerAttributeFax) != 0;

  Set<String> _configuredPrinterNames() {
    final rawValues = <String>[
      _posPrinterNameConfig,
      _posPrinterNamesConfig,
      _rawPrinterNamesConfig,
      Platform.environment['POS_PRINTER_NAME'] ?? '',
      Platform.environment['POS_PRINTER_NAMES'] ?? '',
      Platform.environment['RAW_PRINT_ALLOWED_PRINTERS'] ?? '',
    ];

    return rawValues
        .expand((value) => value.split(','))
        .map(_normalizePrinterName)
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  bool _isTicketPrinter(_WindowsPrinter printer) {
    final value = _normalizePrinterSearchValue(
      printer.name,
      printer.driverName,
    );
    final keywords = const [
      '80mm',
      '58mm',
      'thermal',
      'receipt',
      'ticket',
      'escpos',
      'esc-pos',
      'esc_pos',
      'sprt',
      'xprinter',
      'xp-',
      'rongta',
      'rp-',
      'zjiang',
      'sunmi',
      'bixolon',
      'star',
      'citizen',
      'epson tm',
      'tm-t',
      'tm-u',
      'tsp',
      'ct-s',
      'usb',
      'pos58',
      'pos80',
      'pos-58',
      'pos-80',
    ];

    if (keywords.any(value.contains)) return true;
    return RegExp(r'(^|[\s_\-/])pos([0-9\s_\-/]|$)').hasMatch(value);
  }

  bool _isVirtualPrinter(String name, String driverName, String portName) {
    final value = _normalizePrinterSearchValue(name, driverName, portName);
    return value.contains('pdf') ||
        value.contains('xps') ||
        value.contains('fax') ||
        value.contains('onenote') ||
        value.contains('document writer');
  }

  String _normalizePrinterName(String value) => value.trim().toLowerCase();

  String _normalizePrinterSearchValue(
    String name,
    String driverName, [
    String portName = '',
  ]) {
    return '$name $driverName $portName'.toLowerCase();
  }
}

class _WindowsPrinter {
  final String name;
  final String driverName;
  final String portName;
  final int attributes;
  final int status;

  const _WindowsPrinter({
    required this.name,
    required this.driverName,
    required this.portName,
    required this.attributes,
    required this.status,
  });
}

String _readUtf16(Pointer<Utf16> pointer) {
  if (pointer.address == 0) return '';
  return pointer.toDartString();
}
