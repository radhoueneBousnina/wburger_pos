import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:web/web.dart' as web;

import '../network/api_client.dart';
import '../network/api_constants.dart';

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

  static final Dio _bridgeDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 8),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  Future<RawTicketPrinterBackendResult> printTicket({
    required String jobName,
    required Uint8List bytes,
    int? paperWidthMm,
    String? previewText,
    bool allowBrowserFallback = true,
  }) async {
    String? bridgeError;
    final bridgeErrors = <String>[];
    final base64Bytes = base64Encode(bytes);

    // 1. Try the cashier machine's local USB print bridge. The deployed API
    // stays on the VPS; raw ESC/POS bytes must go to localhost.
    for (final endpoint in _localPrintEndpoints()) {
      try {
        final response = await _bridgeDio.post(
          endpoint,
          data: {
            'bytes': base64Bytes,
            'job_name': jobName,
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data is Map && data['status'] == 'success') {
            if (kDebugMode) {
              debugPrint('[Printer] Local print bridge success: $endpoint');
            }
            final printerCount = _readPrinterCount(data);
            return RawTicketPrinterBackendResult(
              printerCount: printerCount,
              printedCount: _readPrintedCount(data, fallback: printerCount),
              successMessage: (data['message'] as String?) ??
                  'Ticket queued through the web print bridge.',
            );
          }
          if (data is Map) {
            final details = _backendPrintMessage(data);
            bridgeError = details == null
                ? 'Local USB print bridge is unavailable.'
                : 'Local USB print bridge unavailable: $details';
            bridgeErrors.add('${_endpointLabel(endpoint)}: $bridgeError');
          }
        }
      } catch (e) {
        bridgeError = _describeBridgeError(
          e,
          fallback: 'Local USB print bridge is unavailable.',
        );
        bridgeErrors.add('${_endpointLabel(endpoint)}: $bridgeError');
        if (kDebugMode) {
          debugPrint('[Printer] Local print bridge failed at $endpoint: $e');
        }
      }
    }

    // 2. Try direct browser-to-printer access through Web Serial when the
    // browser exposes it. This is still secondary to the desktop app.
    if (_hasWebSerial) {
      try {
        final success = await _printViaWebSerial(bytes);
        if (success) {
          return const RawTicketPrinterBackendResult(
            printerCount: 1,
            printedCount: 1,
            successMessage: 'Ticket sent to the selected web printer.',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[WebSerial] Print error: $e');
        }
        bridgeError ??= 'Web Serial print failed.';
      }
    }

    // 3. Final fallback for the browser build: open a normal print dialog
    // using a text preview of the ticket. This keeps the web build useful for
    // testing on Windows/Linux/macOS even when no raw device access exists.
    final preview = allowBrowserFallback ? previewText?.trim() : null;
    if (preview != null && preview.isNotEmpty) {
      try {
        await _openBrowserPrintPreview(
          jobName: jobName,
          paperWidthMm: paperWidthMm ?? 80,
          previewText: preview,
        );
        return const RawTicketPrinterBackendResult(
          printerCount: 1,
          printedCount: 1,
          successMessage:
              'Opened the browser print dialog for web testing. Use the dialog to finish printing.',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PrinterPreview] Browser print preview failed: $e');
        }
        bridgeError ??= 'Browser print preview failed.';
      }
    }

    return RawTicketPrinterBackendResult(
      printerCount: 0,
      printedCount: 0,
      failedPrinters: const ['web'],
      error: bridgeErrors.isNotEmpty
          ? 'Print bridge failed. ${bridgeErrors.join(' ')}'
          : bridgeError ??
              'No browser printing path is available. Use the desktop app for direct thermal printing.',
    );
  }

  Future<bool> connectPrinter() async {
    if (!_hasWebSerial) return true;
    return _requestSerialPort();
  }

  Future<RawCashDrawerStatusResult> readCashDrawerStatus() async {
    Object? lastError;
    for (final endpoint in _drawerStatusEndpoints()) {
      try {
        final response = await _bridgeDio.get(endpoint);
        final data = response.data;
        if (data is! Map) {
          lastError = 'Drawer status bridge returned an invalid response.';
          continue;
        }

        final status = data['status']?.toString();
        if (status == 'success') {
          return RawCashDrawerStatusResult(
            supported: true,
            isOpen: data['is_open'] is bool ? data['is_open'] as bool : null,
            pin3High:
                data['pin3_high'] is bool ? data['pin3_high'] as bool : null,
            source: data['source']?.toString(),
          );
        }

        lastError = _backendPrintMessage(data) ??
            'Drawer status bridge is not available.';
      } catch (e) {
        lastError = e;
      }
    }

    return RawCashDrawerStatusResult(
      supported: false,
      error: lastError == null
          ? 'Drawer status bridge is not available.'
          : _describeBridgeError(
              lastError,
              fallback: 'Drawer status bridge is not available.',
            ),
    );
  }
}

RawTicketPrinterBackend createRawTicketPrinterBackend() {
  return const RawTicketPrinterBackend();
}

List<String> _localPrintEndpoints() {
  return _bridgeEndpointsForPath(ApiConstants.printProxy);
}

List<String> _drawerStatusEndpoints() {
  return _bridgeEndpointsForPath(ApiConstants.drawerStatusProxy);
}

List<String> _bridgeEndpointsForPath(String apiPath) {
  final normalizedPath = apiPath.startsWith('/') ? apiPath : '/$apiPath';
  final endpoints = <String>[
    '${_normalizedBridgeBaseUrl()}$normalizedPath',
  ];

  final configuredUri = Uri.tryParse(ApiConstants.printBridgeBaseUrl.trim());
  final scheme =
      configuredUri?.scheme.isNotEmpty == true ? configuredUri!.scheme : 'http';
  final port = configuredUri?.port ?? 19100;

  endpoints
    ..add('$scheme://127.0.0.1:$port$normalizedPath')
    ..add('$scheme://localhost:$port$normalizedPath');

  return _uniqueEndpoints(endpoints);
}

String _normalizedBridgeBaseUrl() {
  var value = ApiConstants.printBridgeBaseUrl.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value.isEmpty ? 'http://127.0.0.1:19100' : value;
}

List<String> _uniqueEndpoints(List<String> endpoints) {
  final seen = <String>{};
  return endpoints.where((endpoint) {
    final value = endpoint.trim();
    return value.isNotEmpty && seen.add(value);
  }).toList(growable: false);
}

String _endpointLabel(String endpoint) {
  final uri = Uri.tryParse(endpoint);
  if (uri == null || uri.host.isEmpty) return 'Local USB print bridge';
  if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
    return 'Local USB print bridge';
  }
  return 'Local USB print bridge';
}

int _readPrinterCount(Map data) {
  final count = data['printer_count'];
  if (count is int && count > 0) return count;

  final printers = data['detected_printers'];
  if (printers is List && printers.isNotEmpty) return printers.length;
  return 1;
}

int _readPrintedCount(Map data, {required int fallback}) {
  final count = data['printed_count'];
  if (count is int && count >= 0) return count;
  return fallback;
}

String? _backendPrintMessage(Map data) {
  final error = data['error'];
  if (error is Map) {
    final message = error['message'] ?? error['detail'];
    if (message != null) return message.toString();
  }
  final message = data['message'] ?? data['error'] ?? data['detail'];
  if (message == null) return null;
  if (message is List) return message.join('\n');
  return message.toString();
}

String _describeBridgeError(
  Object error, {
  required String fallback,
}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return 'Local USB print bridge is not running on this cashier machine. Start the POS with scripts/run_pos_web_vps.sh and try again.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Local USB print bridge timed out. Check that the printer is connected and CUPS is not stuck.';
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        break;
    }
  }
  return apiClient.describeError(error, fallback: fallback);
}

Future<void> _openBrowserPrintPreview({
  required String jobName,
  required int paperWidthMm,
  required String previewText,
}) async {
  final body = web.document.body;
  if (body == null) {
    throw StateError('Document body is not available for print preview.');
  }

  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..setAttribute(
      'style',
      'position:fixed;right:0;bottom:0;width:0;height:0;border:0;opacity:0;pointer-events:none;',
    )
    ..setAttribute(
      'srcdoc',
      _buildPrintHtmlDocument(
        title: jobName,
        paperWidthMm: paperWidthMm,
        previewText: previewText,
      ),
    );

  body.appendChild(iframe);
  await Future<void>.delayed(const Duration(milliseconds: 150));

  final contentWindow = iframe.contentWindow;
  if (contentWindow == null) {
    iframe.remove();
    throw StateError('Print preview window could not be created.');
  }

  contentWindow.focus();
  contentWindow.print();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  iframe.remove();
}

String _buildPrintHtmlDocument({
  required String title,
  required int paperWidthMm,
  required String previewText,
}) {
  final safeTitle = _escapeHtml(title);
  final safeText = _escapeHtml(previewText);
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>$safeTitle</title>
    <style>
      @page { size: ${paperWidthMm}mm auto; margin: 6mm; }
      body {
        margin: 0;
        padding: 12px;
        background: #ffffff;
        color: #000000;
        font-family: "Courier New", monospace;
      }
      pre {
        margin: 0 auto;
        max-width: ${paperWidthMm}mm;
        white-space: pre-wrap;
        word-break: break-word;
        font-size: 12px;
        line-height: 1.35;
      }
    </style>
  </head>
  <body>
    <pre>$safeText</pre>
  </body>
</html>
''';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

// ---------------------------------------------------------------------------
// Web Serial API Interop
// ---------------------------------------------------------------------------

@JS('navigator.serial')
external JSAny? get _navigatorSerialMaybe;

bool get _hasWebSerial => _navigatorSerialMaybe != null;

@JS('navigator.serial')
external SerialManager get _serial;

extension type SerialManager(JSObject _) implements JSObject {
  external JSPromise<SerialPort> requestPort();
  external JSPromise<JSArray<SerialPort>> getPorts();
}

extension type SerialPort(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(SerialOptions options);
  external web.WritableStream? get writable;
}

@JS()
@anonymous
extension type SerialOptions._(JSObject _) implements JSObject {
  external factory SerialOptions({int baudRate});
}

SerialPort? _selectedPort;

Future<bool> _requestSerialPort() async {
  if (!_hasWebSerial) return false;
  try {
    final port = await _serial.requestPort().toDart;
    _selectedPort = port;
    return true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[WebSerial] Request port error: $e');
    }
    return false;
  }
}

Future<bool> _printViaWebSerial(Uint8List bytes) async {
  if (!_hasWebSerial) return false;
  if (_selectedPort == null) {
    try {
      final ports = await _serial.getPorts().toDart;
      final dartPorts = ports.toDart;
      if (dartPorts.isNotEmpty) {
        _selectedPort = dartPorts[0];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebSerial] Get ports error: $e');
      }
    }
  }

  if (_selectedPort == null) return false;

  final port = _selectedPort!;

  try {
    await port.open(SerialOptions(baudRate: 9600)).toDart;
  } catch (_) {
    // Ignore "already open" cases.
  }

  final writable = port.writable;
  if (writable == null) {
    throw StateError('Serial port writable stream is null.');
  }

  final writer = writable.getWriter();
  try {
    await writer.write(bytes.toJS).toDart;
    await writer.ready.toDart;
  } finally {
    writer.releaseLock();
  }

  return true;
}
