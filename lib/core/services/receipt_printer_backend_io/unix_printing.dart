part of '../receipt_printer_backend_io.dart';

Future<RawCashDrawerStatusResult> _readCashDrawerStatusOnUnix() async {
  final rawDevices = _UnixRawDevicePrinter();
  final devices = rawDevices.listTicketDevices();
  if (devices.isEmpty) {
    return const RawCashDrawerStatusResult(
      supported: false,
      error: 'No raw ESC/POS device was found for drawer status detection.',
    );
  }

  final errors = <String>[];
  RawCashDrawerStatusResult? closedResult;
  for (final device in devices) {
    try {
      final pin3High = await rawDevices.readDrawerPin3High(device);
      final isOpen = _isDrawerOpenFromPin3High(pin3High);
      final result = RawCashDrawerStatusResult(
        supported: true,
        isOpen: isOpen,
        pin3High: pin3High,
        source: device.path,
      );
      if (isOpen) return result;
      closedResult ??= result;
    } catch (error) {
      errors.add('${device.path} (${error.toString()})');
    }
  }

  if (closedResult != null) return closedResult;

  return RawCashDrawerStatusResult(
    supported: false,
    error: errors.isEmpty
        ? 'Drawer status was not available from the connected printer.'
        : 'Drawer status was not available: ${errors.join(' ')}',
  );
}

bool _isDrawerOpenFromPin3High(bool pin3High) {
  const compiledOpenWhenHigh = bool.fromEnvironment(
    'CASH_DRAWER_OPEN_WHEN_PIN3_HIGH',
    defaultValue: true,
  );
  final runtimeValue = Platform.environment['CASH_DRAWER_OPEN_WHEN_PIN3_HIGH'];
  final openWhenHigh = runtimeValue == null
      ? compiledOpenWhenHigh
      : _isTruthyEnvironmentValue(runtimeValue);
  return openWhenHigh ? pin3High : !pin3High;
}

bool _isTruthyEnvironmentValue(String value) {
  return const {'1', 'true', 'yes', 'on'}.contains(value.trim().toLowerCase());
}

Future<RawTicketPrinterBackendResult> _printTicketOnUnix(
  String jobName,
  Uint8List bytes,
) async {
  final cupsResult = await _printTicketWithCups(jobName, bytes);
  if (cupsResult.printedCount > 0) {
    return cupsResult;
  }

  final deviceResult = await _printTicketWithRawDevices(bytes);
  if (deviceResult.printedCount > 0) {
    return deviceResult;
  }

  if (cupsResult.printerCount > 0) {
    final errors = <String>[
      if (cupsResult.error != null) cupsResult.error!,
      ...cupsResult.failedPrinters,
      if (deviceResult.error != null) deviceResult.error!,
      ...deviceResult.failedPrinters,
    ];
    return RawTicketPrinterBackendResult(
      printerCount: cupsResult.printerCount,
      printedCount: 0,
      failedPrinters: errors,
      error: errors.isEmpty
          ? 'CUPS found a printer but the ticket was not queued.'
          : 'CUPS printer failed and raw device fallback did not print: ${errors.join(' ')}',
    );
  }

  if (deviceResult.printerCount > 0) {
    return deviceResult;
  }

  if (cupsResult.error != null && deviceResult.error != null) {
    return RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      error: '${cupsResult.error} ${deviceResult.error}',
    );
  }
  return cupsResult.error != null ? cupsResult : deviceResult;
}

Future<RawTicketPrinterBackendResult> _printTicketWithCups(
  String jobName,
  Uint8List bytes,
) async {
  try {
    final cups = _CupsRawPrinter();
    final printers = await cups.listTicketPrinters();
    if (printers.isEmpty) {
      return const RawTicketPrinterBackendResult(
        printerCount: 0,
        printedCount: 0,
      );
    }

    final printResults = await Future.wait(
      printers.map((printer) async {
        try {
          await cups.printRawBytes(
            printerName: printer.name,
            jobName: jobName,
            bytes: bytes,
          );
          return null;
        } catch (error) {
          return '${printer.name} (${error.toString()})';
        }
      }),
    );
    final failedPrinters = printResults.whereType<String>().toList();

    return RawTicketPrinterBackendResult(
      printerCount: printers.length,
      printedCount: printers.length - failedPrinters.length,
      failedPrinters: failedPrinters,
      successMessage: failedPrinters.isEmpty
          ? 'Ticket queued on ${printers.map((printer) => printer.name).join(', ')} (${bytes.length} bytes).'
          : null,
    );
  } catch (error) {
    return RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      error: 'CUPS raw thermal ticket printing failed: ${error.toString()}',
    );
  }
}

Future<RawTicketPrinterBackendResult> _printTicketWithRawDevices(
  Uint8List bytes,
) async {
  try {
    final rawDevices = _UnixRawDevicePrinter();
    final devices = rawDevices.listTicketDevices();
    if (devices.isEmpty) {
      return const RawTicketPrinterBackendResult(
        printerCount: 0,
        printedCount: 0,
        error: 'No raw ESC/POS device was found at /dev/usb/lp* or /dev/lp*.',
      );
    }

    final printResults = await Future.wait(
      devices.map((device) async {
        try {
          await rawDevices.printRawBytes(device: device, bytes: bytes);
          return null;
        } catch (error) {
          return '${device.path} (${error.toString()})';
        }
      }),
    );
    final failedPrinters = printResults.whereType<String>().toList();

    return RawTicketPrinterBackendResult(
      printerCount: devices.length,
      printedCount: devices.length - failedPrinters.length,
      failedPrinters: failedPrinters,
      successMessage: failedPrinters.isEmpty
          ? 'Ticket written directly to ${devices.map((device) => device.path).join(', ')} (${bytes.length} bytes).'
          : null,
      error: failedPrinters.length == devices.length
          ? 'Raw ESC/POS device printing failed. Check Linux printer permissions for ${failedPrinters.join(', ')}.'
          : null,
    );
  } catch (error) {
    return RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      error: 'Raw ESC/POS device printing failed: ${error.toString()}',
    );
  }
}

Future<RawTicketPrinterBackendResult> _printTicketOnWindows(
  String jobName,
  Uint8List bytes,
) async {
  try {
    if (_isCashDrawerJob(jobName)) {
      final configuredNetworkResult =
          await _printCashDrawerToConfiguredNetworkEndpoints(bytes);
      if (configuredNetworkResult != null &&
          configuredNetworkResult.printedCount > 0) {
        return configuredNetworkResult;
      }
    }

    final spooler = _WindowsPrinterSpooler();
    final printers = spooler.listTicketPrinters();
    final configuredEndpoints = _configuredTicketNetworkEndpoints();
    final printerEndpointLabels = printers
        .map((printer) =>
            _networkPrinterEndpointFromWindowsPort(printer.portName)
                ?.label
                .toLowerCase())
        .whereType<String>()
        .toSet();
    final extraEndpoints = configuredEndpoints
        .where((endpoint) =>
            !printerEndpointLabels.contains(endpoint.label.toLowerCase()))
        .toList();

    if (printers.isEmpty && extraEndpoints.isEmpty) {
      return const RawTicketPrinterBackendResult(
        printerCount: 0,
        printedCount: 0,
      );
    }

    final printResults = await Future.wait(
      [
        ...printers.map((printer) => Isolate.run(
              () => _printTicketOnSingleWindowsPrinter(
                printer.name,
                printer.portName,
                jobName,
                bytes,
              ),
            )),
        ...extraEndpoints.map((endpoint) async {
          try {
            await _writeRawBytesToNetworkPrinter(endpoint, bytes);
            return null;
          } catch (error) {
            return '${endpoint.label} (${error.toString()})';
          }
        }),
      ],
    );
    final failedPrinters = printResults.whereType<String>().toList();
    final targetNames = [
      ...printers.map((printer) => printer.name),
      ...extraEndpoints.map((endpoint) => endpoint.label),
    ];

    return RawTicketPrinterBackendResult(
      printerCount: targetNames.length,
      printedCount: targetNames.length - failedPrinters.length,
      failedPrinters: failedPrinters,
      successMessage: failedPrinters.isEmpty
          ? 'Ticket queued on ${targetNames.join(', ')} (${bytes.length} bytes).'
          : null,
    );
  } catch (error) {
    return RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      error: 'Direct thermal ticket printing failed: ${error.toString()}',
    );
  }
}

Future<RawTicketPrinterBackendResult?>
    _printCashDrawerToConfiguredNetworkEndpoints(Uint8List bytes) async {
  final endpoints = _configuredCashDrawerNetworkEndpoints();
  if (endpoints.isEmpty) return null;

  final printResults = await Future.wait(
    endpoints.map((endpoint) async {
      try {
        await _writeRawBytesToNetworkPrinter(endpoint, bytes);
        return null;
      } catch (error) {
        return '${endpoint.label} (${error.toString()})';
      }
    }),
  );
  final failedPrinters = printResults.whereType<String>().toList();

  return RawTicketPrinterBackendResult(
    printerCount: endpoints.length,
    printedCount: endpoints.length - failedPrinters.length,
    failedPrinters: failedPrinters,
    successMessage: failedPrinters.isEmpty
        ? 'Cash drawer pulse sent directly to ${endpoints.map((endpoint) => endpoint.label).join(', ')}.'
        : null,
    error: failedPrinters.length == endpoints.length
        ? 'Direct cash drawer network pulse failed: ${failedPrinters.join(' ')}'
        : null,
  );
}

Future<String?> _printTicketOnSingleWindowsPrinter(
  String printerName,
  String portName,
  String jobName,
  Uint8List bytes,
) async {
  String? networkError;
  final networkEndpoint = _networkPrinterEndpointFromWindowsPort(portName);

  if (networkEndpoint != null) {
    try {
      await _writeRawBytesToNetworkPrinter(networkEndpoint, bytes);
      return null;
    } catch (error) {
      networkError = '${networkEndpoint.label} (${error.toString()})';
    }
  }

  try {
    _WindowsPrinterSpooler().printRawBytes(
      printerName: printerName,
      jobName: jobName,
      bytes: bytes,
    );
    return null;
  } catch (error) {
    if (networkError != null) {
      return '$printerName (network raw failed: $networkError; Windows spooler failed: ${error.toString()})';
    }
    return '$printerName (${error.toString()})';
  }
}

bool _isCashDrawerJob(String jobName) {
  return jobName.toLowerCase().contains('cash drawer');
}

List<_NetworkPrinterEndpoint> _configuredTicketNetworkEndpoints() {
  const compiledHost = String.fromEnvironment('POS_PRINTER_HOST');
  const compiledHosts = String.fromEnvironment('POS_PRINTER_HOSTS');
  const compiledRawHost = String.fromEnvironment('RAW_PRINTER_HOST');
  const compiledRawHosts = String.fromEnvironment('RAW_PRINTER_HOSTS');
  const compiledRawPrintHosts =
      String.fromEnvironment('RAW_PRINT_PRINTER_HOSTS');
  final rawValues = <String>[
    compiledHost,
    compiledHosts,
    compiledRawHost,
    compiledRawHosts,
    compiledRawPrintHosts,
    Platform.environment['POS_PRINTER_HOST'] ?? '',
    Platform.environment['POS_PRINTER_HOSTS'] ?? '',
    Platform.environment['RAW_PRINTER_HOST'] ?? '',
    Platform.environment['RAW_PRINTER_HOSTS'] ?? '',
    Platform.environment['RAW_PRINT_PRINTER_HOSTS'] ?? '',
  ];

  return _configuredNetworkEndpoints(rawValues);
}

List<_NetworkPrinterEndpoint> _configuredCashDrawerNetworkEndpoints() {
  const compiledHost = String.fromEnvironment('CASH_DRAWER_PRINTER_HOST');
  const compiledHosts = String.fromEnvironment('CASH_DRAWER_PRINTER_HOSTS');
  final rawValues = <String>[
    compiledHost,
    compiledHosts,
    Platform.environment['CASH_DRAWER_PRINTER_HOST'] ?? '',
    Platform.environment['CASH_DRAWER_PRINTER_HOSTS'] ?? '',
  ];

  return _configuredNetworkEndpoints(rawValues);
}

List<_NetworkPrinterEndpoint> _configuredNetworkEndpoints(
  Iterable<String> rawValues,
) {
  final endpoints = <_NetworkPrinterEndpoint>[];
  final seen = <String>{};
  for (final rawValue in rawValues) {
    for (final part in rawValue.split(RegExp(r'[,;]'))) {
      final endpoint = _networkPrinterEndpointFromHost(part);
      if (endpoint == null) continue;
      final key = endpoint.label.toLowerCase();
      if (seen.add(key)) {
        endpoints.add(endpoint);
      }
    }
  }
  return endpoints;
}

Future<void> _writeRawBytesToNetworkPrinter(
  _NetworkPrinterEndpoint endpoint,
  Uint8List bytes,
) async {
  final socket = await Socket.connect(
    endpoint.host,
    endpoint.port,
    timeout: const Duration(seconds: 2),
  );
  try {
    socket.add(bytes);
    await socket.flush().timeout(const Duration(seconds: 2));
  } finally {
    socket.destroy();
  }
}

_NetworkPrinterEndpoint? _networkPrinterEndpointFromHost(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  final match = RegExp(
    r'^([A-Za-z0-9.-]+)(?::(\d{2,5}))?$',
  ).firstMatch(value);
  if (match == null) return null;

  return _NetworkPrinterEndpoint(
    host: match.group(1)!,
    port: int.tryParse(match.group(2) ?? '') ?? 9100,
  );
}

_NetworkPrinterEndpoint? _networkPrinterEndpointFromWindowsPort(
  String portName,
) {
  final trimmed = portName.trim();
  if (trimmed.isEmpty) return null;

  final ipMatch = RegExp(
    r'((?:\d{1,3}\.){3}\d{1,3})(?::(\d{2,5}))?',
  ).firstMatch(trimmed);
  if (ipMatch != null) {
    return _NetworkPrinterEndpoint(
      host: ipMatch.group(1)!,
      port: int.tryParse(ipMatch.group(2) ?? '') ?? 9100,
    );
  }

  var value = trimmed;
  if (value.toUpperCase().startsWith('IP_')) {
    value = value.substring(3);
  }
  if (RegExp(r'^(COM|LPT|USB|WSD|FILE|PORTPROMPT)', caseSensitive: false)
      .hasMatch(value)) {
    return null;
  }
  if (value.contains(r'\') || value.contains('/')) return null;

  final hostMatch = RegExp(
    r'^([A-Za-z0-9.-]+)(?::(\d{2,5}))?$',
  ).firstMatch(value);
  if (hostMatch == null) return null;

  final host = hostMatch.group(1)!;
  if (!host.contains('.') && !host.contains('-')) return null;

  return _NetworkPrinterEndpoint(
    host: host,
    port: int.tryParse(hostMatch.group(2) ?? '') ?? 9100,
  );
}

class _NetworkPrinterEndpoint {
  final String host;
  final int port;

  const _NetworkPrinterEndpoint({
    required this.host,
    required this.port,
  });

  String get label => '$host:$port';
}

class _CupsRawPrinter {
  static const Duration _listTimeout = Duration(seconds: 3);
  static const Duration _printTimeout = Duration(seconds: 8);

  Future<List<_CupsPrinter>> listTicketPrinters() async {
    final enabledNames = await _enabledPrinterNames();
    final deviceUris = await _deviceUris();
    final disabledNames = await _disabledPrinterNames();
    final names = enabledNames.isNotEmpty ? enabledNames : deviceUris.keys;

    final printers = <_CupsPrinter>[];
    final seen = <String>{};
    for (final rawName in names) {
      final name = rawName.trim();
      if (name.isEmpty || disabledNames.contains(name) || !seen.add(name)) {
        continue;
      }

      final printer = _CupsPrinter(
        name: name,
        deviceUri: deviceUris[name] ?? '',
      );
      if (!_isVirtualPrinter(printer)) {
        printers.add(printer);
      }
    }

    final ticketPrinters = printers.where(_isTicketPrinter).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (ticketPrinters.isNotEmpty) return ticketPrinters;

    printers.sort((a, b) => a.name.compareTo(b.name));
    return printers;
  }

  Future<void> printRawBytes({
    required String printerName,
    required String jobName,
    required Uint8List bytes,
  }) async {
    final payload = await _writeTempPayload(bytes);
    try {
      final result = await _runCommand(
        'lp',
        [
          '-d',
          printerName,
          '-o',
          'raw',
          '-o',
          'job-sheets=none,none',
          '-t',
          _cupsJobName(jobName),
          payload.path,
        ],
        timeout: _printTimeout,
        ignoreMissingExecutable: false,
      );
      if (result == null) {
        throw StateError('lp command not found. Is CUPS installed?');
      }
      if (result.exitCode != 0) {
        throw StateError(_commandError('lp', result));
      }
    } finally {
      try {
        await payload.delete();
      } catch (_) {
        // The OS temp directory will clean this up if CUPS still has it open.
      }
    }
  }

  Future<File> _writeTempPayload(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final file = await File(
      '${tempDir.path}${Platform.pathSeparator}'
      'wburger-ticket-${DateTime.now().microsecondsSinceEpoch}.bin',
    ).create();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Set<String>> _enabledPrinterNames() async {
    final result = await _runCommand(
      'lpstat',
      const ['-e'],
      timeout: _listTimeout,
      ignoreMissingExecutable: true,
    );
    if (result == null) return <String>{};
    if (result.exitCode != 0) {
      if (_isNoPrintersResult(result)) return <String>{};
      // Treat unexpected errors as empty rather than throwing — we'll fall
      // back to the device-URI map collected by lpstat -v.
      return <String>{};
    }
    return result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
  }

  Future<Map<String, String>> _deviceUris() async {
    final result = await _runCommand(
      'lpstat',
      const ['-v'],
      timeout: _listTimeout,
      ignoreMissingExecutable: true,
    );
    if (result == null) return <String, String>{};
    if (result.exitCode != 0) {
      if (_isNoPrintersResult(result)) return <String, String>{};
      return <String, String>{};
    }

    final devices = <String, String>{};
    final linePattern = RegExp(r'^device for (.+?):\s*(.+)$');
    for (final rawLine in result.stdout.split('\n')) {
      final match = linePattern.firstMatch(rawLine.trim());
      if (match == null) continue;
      devices[match.group(1)!.trim()] = match.group(2)!.trim();
    }
    return devices;
  }

  Future<Set<String>> _disabledPrinterNames() async {
    final result = await _runCommand(
      'lpstat',
      const ['-p'],
      timeout: _listTimeout,
      ignoreMissingExecutable: true,
    );
    if (result == null || result.exitCode != 0) return <String>{};

    final disabled = <String>{};
    final linePattern =
        RegExp(r'^printer\s+(\S+)\s+.*disabled', caseSensitive: false);
    for (final rawLine in result.stdout.split('\n')) {
      final match = linePattern.firstMatch(rawLine.trim());
      if (match != null) disabled.add(match.group(1)!.trim());
    }
    return disabled;
  }

  bool _isVirtualPrinter(_CupsPrinter printer) {
    final value = '${printer.name} ${printer.deviceUri}'.toLowerCase();
    return value.contains('pdf') ||
        value.contains('xps') ||
        value.contains('fax') ||
        value.contains('onenote') ||
        value.contains('cups-pdf') ||
        value.contains('print-to-file') ||
        value.contains('file:/');
  }

  bool _isTicketPrinter(_CupsPrinter printer) {
    final value = '${printer.name} ${printer.deviceUri}'.toLowerCase();
    return value.contains('80mm') ||
        value.contains('58mm') ||
        value.contains('thermal') ||
        value.contains('receipt') ||
        value.contains('escpos') ||
        value.contains('esc-pos') ||
        value.contains('esc_pos') ||
        value.contains('pos') ||
        value.contains('sprt') ||
        value.contains('xprinter') ||
        value.contains('xp-') ||
        value.contains('rongta') ||
        value.contains('rp-') ||
        value.contains('zjiang') ||
        value.contains('sunmi') ||
        value.contains('bixolon') ||
        value.contains('star') ||
        value.contains('citizen') ||
        value.contains('epson%20tm') ||
        value.contains('epson tm') ||
        value.contains('tm-t') ||
        value.contains('tm-u') ||
        value.contains('tsp') ||
        value.contains('ct-s') ||
        value.contains('usb') ||
        value.contains('label') ||
        value.contains('ticket');
  }

  bool _isNoPrintersResult(_CommandResult result) {
    final value = '${result.stdout}\n${result.stderr}'.toLowerCase();
    return value.contains('no destinations') ||
        value.contains('no printers') ||
        value.contains('no default destination') ||
        value.contains('no system default destination') ||
        value.contains('lpstat: no printers');
  }
}

class _CupsPrinter {
  final String name;
  final String deviceUri;

  const _CupsPrinter({
    required this.name,
    required this.deviceUri,
  });
}

class _UnixRawDevicePrinter {
  static const Duration _writeTimeout = Duration(seconds: 4);
  static const Duration _statusReadTimeout = Duration(milliseconds: 350);

  List<_RawPrinterDevice> listTicketDevices() {
    final devices = <_RawPrinterDevice>[];

    if (Platform.isLinux) {
      devices.addAll(_globDevices('/dev/usb', RegExp(r'^lp\d+$')));
      devices.addAll(_globDevices('/dev', RegExp(r'^lp\d+$')));
    }

    if (Platform.isMacOS) {
      devices.addAll(_globDevices('/dev', RegExp(r'^(cu|tty)\.usb.*')));
    }

    final seen = <String>{};
    final uniqueDevices = <_RawPrinterDevice>[];
    for (final device in devices) {
      if (seen.add(device.path)) uniqueDevices.add(device);
    }
    uniqueDevices.sort((a, b) => a.path.compareTo(b.path));
    return uniqueDevices;
  }

  Future<bool> readDrawerPin3High(_RawPrinterDevice device) async {
    final dleEotStatus = await _queryStatusByte(
      device.path,
      Uint8List.fromList(const [0x10, 0x04, 0x01]),
    );
    if (dleEotStatus != null) {
      return (dleEotStatus & 0x04) != 0;
    }

    final gsRStatus = await _queryStatusByte(
      device.path,
      Uint8List.fromList(const [0x1d, 0x72, 0x02]),
    );
    if (gsRStatus != null) {
      return (gsRStatus & 0x01) != 0;
    }

    throw StateError('No drawer status byte returned.');
  }

  Future<void> printRawBytes({
    required _RawPrinterDevice device,
    required Uint8List bytes,
  }) async {
    await _writeDevice(device.path, bytes).timeout(_writeTimeout);
  }

  List<_RawPrinterDevice> _globDevices(String directoryPath, RegExp pattern) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) return const [];

    final devices = <_RawPrinterDevice>[];
    for (final entity in directory.listSync(followLinks: false)) {
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
      if (!pattern.hasMatch(name)) continue;
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.notFound ||
          type == FileSystemEntityType.directory) {
        continue;
      }
      devices.add(_RawPrinterDevice(path: entity.path));
    }
    return devices;
  }

  Future<void> _writeDevice(String path, Uint8List bytes) async {
    final file = File(path);
    final printer = await file.open(mode: FileMode.writeOnly);
    try {
      await printer.writeFrom(bytes);
      await printer.flush();
    } finally {
      await printer.close();
    }
  }

  Future<int?> _queryStatusByte(String path, Uint8List command) async {
    final file = File(path);
    final printer = await file.open(mode: FileMode.write);
    try {
      await printer.writeFrom(command);
      await printer.flush();
      final response = await printer.read(1).timeout(
            _statusReadTimeout,
            onTimeout: () => Uint8List(0),
          );
      if (response.isEmpty) return null;
      return response.first;
    } finally {
      await printer.close();
    }
  }
}

class _RawPrinterDevice {
  final String path;

  const _RawPrinterDevice({required this.path});
}
