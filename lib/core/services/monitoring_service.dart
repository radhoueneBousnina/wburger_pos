import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_constants.dart';

class MonitoringSnapshot {
  final String deviceId;
  final String apiUrl;
  final String appVersion;
  final String internetStatus;
  final String backendStatus;
  final DateTime? lastSyncAt;
  final int unsyncedOrdersCount;
  final String printerStatus;
  final String localDbStatus;
  final String lastError;

  const MonitoringSnapshot({
    required this.deviceId,
    required this.apiUrl,
    required this.appVersion,
    required this.internetStatus,
    required this.backendStatus,
    required this.lastSyncAt,
    required this.unsyncedOrdersCount,
    required this.printerStatus,
    required this.localDbStatus,
    required this.lastError,
  });
}

class PosMonitoringService {
  PosMonitoringService._();
  static final PosMonitoringService instance = PosMonitoringService._();

  static const _queueKey = 'pos_monitoring_event_queue';
  static const _deviceIdKey = 'pos_monitoring_device_id';
  static const _tokenKey = 'wburger_auth_token';
  static const _eventDedupeWindow = Duration(minutes: 10);
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const _ingestionSecret = String.fromEnvironment(
    'MONITORING_INGESTION_SECRET',
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static final RegExp _sensitiveKeyPattern = RegExp(
    r'(password|passwd|pwd|secret|token|jwt|authorization|cookie|session|card|pan|cvv|cvc|pin|iban)',
    caseSensitive: false,
  );
  static final RegExp _emailPattern =
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
  static final RegExp _bearerPattern =
      RegExp(r'Bearer\s+[A-Za-z0-9._-]+', caseSensitive: false);
  static final RegExp _jwtPattern =
      RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b');
  static final RegExp _cardPattern = RegExp(r'\b(?:\d[ -]*?){13,19}\b');

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  SharedPreferences? _prefs;
  Timer? _heartbeatTimer;
  bool _initialized = false;
  bool _flushing = false;
  bool _heartbeatInFlight = false;
  bool _backendOnline = true;
  bool _internetOnline = true;
  final Map<String, DateTime> _lastMonitoringEventAt = {};

  DateTime? _lastSyncAt;
  int _unsyncedOrdersCount = 0;
  String _printerStatus = 'unknown';
  String _localDbStatus = 'ok';
  String _lastError = '';

  Future<void> init() async {
    if (_initialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    await deviceId();
    _initialized = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(sendHeartbeat()),
    );
    unawaited(flushQueue());
    unawaited(sendHeartbeat());
  }

  Future<String> deviceId() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final host = kIsWeb ? 'web' : Platform.localHostname;
    final created = 'pos-$host-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  Future<MonitoringSnapshot> snapshot() async {
    await init();
    return MonitoringSnapshot(
      deviceId: await deviceId(),
      apiUrl: '${ApiConstants.baseUrl}${ApiConstants.apiPrefix}',
      appVersion: appVersion,
      internetStatus: _internetOnline ? 'online' : 'offline',
      backendStatus: _backendOnline ? 'online' : 'offline',
      lastSyncAt: _lastSyncAt,
      unsyncedOrdersCount: _unsyncedOrdersCount,
      printerStatus: _printerStatus,
      localDbStatus: _localDbStatus,
      lastError: _lastError,
    );
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    return recordEvent(
      level: 'critical',
      eventType: 'app_crash',
      message: details.exceptionAsString(),
      metadata: {
        'library': details.library,
        'context': details.context?.toDescription(),
        'stack': details.stack?.toString(),
      },
    );
  }

  Future<void> recordException(
    Object error,
    StackTrace stack, {
    String level = 'critical',
    String eventType = 'app_crash',
    Map<String, dynamic> metadata = const {},
  }) {
    return recordEvent(
      level: level,
      eventType: eventType,
      message: error.toString(),
      metadata: {
        ...metadata,
        'stack': stack.toString(),
      },
    );
  }

  Future<void> recordEvent({
    required String level,
    required String eventType,
    required String message,
    Map<String, dynamic> metadata = const {},
  }) async {
    await init();
    final cleanLevel = _cleanText(level);
    final cleanEventType = _cleanText(eventType);
    final cleanMessage = _cleanText(message);
    _lastError = cleanLevel == 'info' ? _lastError : cleanMessage;
    await logLocal(
        '${DateTime.now().toIso8601String()} [$level] $eventType $message');

    if (_isDuplicateMonitoringEvent(
      level: cleanLevel,
      eventType: cleanEventType,
      message: cleanMessage,
    )) {
      await logLocal(
        '${DateTime.now().toIso8601String()} [info] monitoring_duplicate_suppressed $cleanEventType',
      );
      return;
    }

    final payload = {
      'source': 'flutter_pos',
      'level': cleanLevel,
      'event_type': cleanEventType,
      'message': cleanMessage,
      'device_id': await deviceId(),
      'app_version': appVersion,
      'environment': kReleaseMode ? 'production' : 'debug',
      'notification_channels': ['email'],
      'suppress_push': true,
      'metadata': _sanitize({
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'notification_policy': 'email_only',
        ...metadata,
      }),
    };
    final sent = await _send(ApiConstants.monitoringEvents, payload);
    if (!sent) await _enqueue(payload);
  }

  Future<void> flushQueue() async {
    await init();
    if (_flushing) return;
    _flushing = true;
    try {
      final queued = _readQueue();
      if (queued.isEmpty) return;
      final remaining = <Map<String, dynamic>>[];
      for (final event in queued) {
        final sent = await _send(ApiConstants.monitoringEvents, event);
        if (!sent) remaining.add(event);
      }
      await _writeQueue(remaining);
    } finally {
      _flushing = false;
    }
  }

  Future<bool> sendHeartbeat() async {
    await init();
    if (_heartbeatInFlight) return _backendOnline;
    _heartbeatInFlight = true;
    try {
      final payload = {
        'device_id': await deviceId(),
        'app_version': appVersion,
        'last_sync_at': _lastSyncAt?.toIso8601String(),
        'internet_status': _internetOnline ? 'online' : 'offline',
        'printer_status': _printerStatus,
        'local_db_status': _localDbStatus,
        'unsynced_orders_count': _unsyncedOrdersCount,
        'last_error': _lastError,
        'metadata': _sanitize({
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'queued_monitoring_events': _readQueue().length,
        }),
      };
      final sent = await _send(ApiConstants.posHeartbeat, payload);
      if (sent) {
        noteBackendRestored();
      } else {
        noteBackendFailure('POS heartbeat failed');
      }
      return sent;
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void noteBackendRestored() {
    final wasOffline = !_backendOnline || !_internetOnline;
    _backendOnline = true;
    _internetOnline = true;
    _lastSyncAt = DateTime.now();
    if (wasOffline) {
      unawaited(recordEvent(
        level: 'info',
        eventType: 'internet_restored',
        message: 'POS backend connection restored.',
      ));
      unawaited(flushQueue());
    }
  }

  void noteBackendFailure(String message) {
    final firstFailure = _backendOnline || _internetOnline;
    _backendOnline = false;
    _internetOnline = false;
    _lastError = _cleanText(message);
    if (firstFailure) {
      unawaited(recordEvent(
        level: 'warning',
        eventType: 'internet_lost',
        message: message,
      ));
    }
  }

  void updatePrinterStatus(String status, {String? error}) {
    _printerStatus = status;
    if (error != null && error.isNotEmpty) _lastError = _cleanText(error);
    unawaited(sendHeartbeat());
  }

  void recordPrinterFailure(String message,
      {Map<String, dynamic> metadata = const {}}) {
    _printerStatus = 'failed';
    _lastError = _cleanText(message);
    unawaited(recordEvent(
      level: 'error',
      eventType: 'printer_failed',
      message: message,
      metadata: metadata,
    ));
  }

  void recordSyncFailure(String message,
      {Map<String, dynamic> metadata = const {}}) {
    _lastError = _cleanText(message);
    unawaited(recordEvent(
      level: 'error',
      eventType: 'sync_failed',
      message: message,
      metadata: metadata,
    ));
  }

  void recordLocalDbError(String message,
      {Map<String, dynamic> metadata = const {}}) {
    _localDbStatus = 'error';
    _lastError = _cleanText(message);
    unawaited(recordEvent(
      level: 'error',
      eventType: 'local_db_error',
      message: message,
      metadata: metadata,
    ));
  }

  void setUnsyncedOrdersCount(int count) {
    final normalized = count < 0 ? 0 : count;
    final wasZero = _unsyncedOrdersCount == 0;
    _unsyncedOrdersCount = normalized;
    if (normalized > 0 && wasZero) {
      unawaited(recordEvent(
        level: 'warning',
        eventType: 'unsynced_orders_detected',
        message: '$normalized unsynced POS orders detected.',
        metadata: {'unsynced_orders_count': normalized},
      ));
    }
    unawaited(sendHeartbeat());
  }

  Future<void> uploadLogs() async {
    final tail = await readLogTail();
    await recordEvent(
      level: 'info',
      eventType: 'pos_logs_uploaded',
      message: 'POS diagnostics logs uploaded.',
      metadata: {'log_tail': tail},
    );
  }

  Future<String> readLogTail({int maxBytes = 80000}) async {
    if (kIsWeb) return 'Local file logs are not available on web.';
    final file = await _logFile();
    if (!await file.exists()) return '';
    final bytes = await file.readAsBytes();
    final start = bytes.length > maxBytes ? bytes.length - maxBytes : 0;
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  Future<void> logLocal(String line) async {
    if (kIsWeb) return;
    try {
      final file = await _logFile();
      await file.parent.create(recursive: true);
      if (await file.exists() && await file.length() > 1024 * 1024) {
        final rotated = File('${file.path}.1');
        if (await rotated.exists()) await rotated.delete();
        await file.rename(rotated.path);
      }
      await file.writeAsString('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {}
  }

  Future<File> _logFile() async {
    final dir = await _logDirectory();
    return File('${dir.path}${Platform.pathSeparator}pos.log');
  }

  Future<Directory> _logDirectory() async {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory(
            '$appData${Platform.pathSeparator}WBurgerPOS${Platform.pathSeparator}logs');
      }
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
          '$home${Platform.pathSeparator}.wburger_pos${Platform.pathSeparator}logs');
    }
    return Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}wburger_pos_logs');
  }

  Future<bool> _send(String endpoint, Map<String, dynamic> payload) async {
    try {
      final token = await _readAuthToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      if (_ingestionSecret.isNotEmpty) {
        headers['X-Monitoring-Secret'] = _ingestionSecret;
      }
      final response = await _dio.post(
        endpoint,
        data: payload,
        options: Options(
          headers: headers.isEmpty ? null : headers,
        ),
      );
      final ok = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
      if (ok) {
        _backendOnline = true;
        _internetOnline = true;
        _lastSyncAt = DateTime.now();
      }
      return ok;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        _backendOnline = false;
        _internetOnline = false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _readAuthToken() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    final queue = _readQueue();
    queue.add(payload);
    final trimmed =
        queue.length > 200 ? queue.sublist(queue.length - 200) : queue;
    await _writeQueue(trimmed);
  }

  List<Map<String, dynamic>> _readQueue() {
    final raw = _prefs?.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    await _prefs?.setString(_queueKey, jsonEncode(queue));
  }

  bool _isDuplicateMonitoringEvent({
    required String level,
    required String eventType,
    required String message,
  }) {
    if (level == 'info') return false;
    final now = DateTime.now();
    _lastMonitoringEventAt.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _eventDedupeWindow,
    );
    final fingerprint = '$level|$eventType|$message';
    final previous = _lastMonitoringEventAt[fingerprint];
    if (previous != null && now.difference(previous) <= _eventDedupeWindow) {
      return true;
    }
    _lastMonitoringEventAt[fingerprint] = now;
    return false;
  }

  dynamic _sanitize(dynamic value, [int depth = 0]) {
    if (depth > 5) return '[truncated]';
    if (value == null || value is num || value is bool) return value;
    if (value is String) return _cleanText(value);
    if (value is List) {
      return value.take(50).map((item) => _sanitize(item, depth + 1)).toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries.take(80)) {
        final key = entry.key.toString();
        out[key] = _sensitiveKeyPattern.hasMatch(key)
            ? '[redacted]'
            : _sanitize(entry.value, depth + 1);
      }
      return out;
    }
    return _cleanText(value.toString());
  }

  String _cleanText(Object? value) {
    final cleaned = value
        .toString()
        .replaceAll(_bearerPattern, 'Bearer [redacted]')
        .replaceAll(_jwtPattern, '[redacted]')
        .replaceAll(_emailPattern, '[redacted]')
        .replaceAll(_cardPattern, '[redacted]');
    return cleaned.length > 2000 ? '${cleaned.substring(0, 2000)}...' : cleaned;
  }
}
