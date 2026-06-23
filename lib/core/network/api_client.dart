import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/monitoring_service.dart';
import 'api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio dio;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  final StreamController<void> _authInvalidatedController =
      StreamController<void>.broadcast();
  Future<String?>? _refreshFuture;

  static const String tokenKey = 'wburger_auth_token';
  static const String refreshTokenKey = 'wburger_refresh_token';
  static const String _skipAuthHeaderKey = 'skipAuthHeader';
  static const String _retriedAfterRefreshKey = 'retriedAfterRefresh';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  factory ApiClient() {
    return _instance;
  }

  Stream<void> get authInvalidated => _authInvalidatedController.stream;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add Auth Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra[_skipAuthHeaderKey] == true;
          final token = skipAuth ? null : await getAccessToken();
          if (!skipAuth && token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          PosMonitoringService.instance.noteBackendRestored();
          handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            PosMonitoringService.instance.noteBackendFailure(describeError(e));
          }
          if (e.response?.statusCode == 401 && _canRefreshRequest(e)) {
            final newAccessToken = await _refreshAccessToken();
            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              final options = e.requestOptions;
              options.extra[_retriedAfterRefreshKey] = true;
              options.headers['Authorization'] = 'Bearer $newAccessToken';

              final response = await dio.fetch(options);
              return handler.resolve(response);
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  bool _canRefreshRequest(DioException error) {
    final options = error.requestOptions;
    if (options.extra[_retriedAfterRefreshKey] == true) return false;
    if (options.extra[_skipAuthHeaderKey] == true) return false;

    final path = options.uri.path;
    return !path.endsWith('/auth/login/') &&
        !path.endsWith('/auth/logout/') &&
        !path.endsWith('/auth/token/refresh/');
  }

  Future<String?> _refreshAccessToken() {
    final existingRefresh = _refreshFuture;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _performRefresh();
    _refreshFuture = refresh;
    return refresh.whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _invalidateAuth();
      return null;
    }

    try {
      final refreshRes = await Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ).post(
        '${ApiConstants.apiPrefix}/auth/token/refresh/',
        data: {'refresh': refreshToken},
        options: Options(extra: const {_skipAuthHeaderKey: true}),
      );

      final newAccessToken = _tokenFromResponse(refreshRes.data, const [
        'access',
        'access_token',
        'key',
        'token',
      ]);
      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _invalidateAuth();
        return null;
      }

      await _secureStorage.write(key: tokenKey, value: newAccessToken);
      final newRefreshToken = _tokenFromResponse(refreshRes.data, const [
        'refresh',
        'refresh_token',
      ]);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: refreshTokenKey,
          value: newRefreshToken,
        );
      }
      await _clearLegacyTokens();
      return newAccessToken;
    } catch (refreshError) {
      if (kDebugMode) debugPrint('Refresh token failed.');
      await _invalidateAuth();
      return null;
    }
  }

  Future<void> _invalidateAuth() async {
    await clearAllTokens();
    if (!_authInvalidatedController.isClosed) {
      _authInvalidatedController.add(null);
    }
  }

  static String? _tokenFromResponse(Object? data, List<String> keys) {
    if (data is! Map) return null;

    for (final key in keys) {
      final value = data[key];
      final token = value?.toString().trim();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  Future<void> init() {
    return _initFuture ??= _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTokens();
  }

  String describeError(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is DioException) {
      final data = error.response?.data;
      final payloadMessage = _messageFromPayload(data);
      if (payloadMessage != null) {
        return payloadMessage;
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection to the server timed out. Please try again.';
        case DioExceptionType.connectionError:
          return 'Unable to reach the server. Please check the connection and try again.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          if (statusCode >= 500) {
            return 'The server is unavailable right now. Please try again shortly.';
          }
          return fallback;
        case DioExceptionType.cancel:
          return 'The request was cancelled.';
        case DioExceptionType.badCertificate:
          return 'The server connection could not be trusted.';
        case DioExceptionType.unknown:
          return 'Unable to connect to the server. Please try again.';
      }
    }

    if (error is String) {
      return _cleanMessage(error) ?? fallback;
    }

    if (error is FormatException || error is TypeError || error is StateError) {
      return fallback;
    }

    final message = _cleanMessage(error.toString());
    if (message != null && message != 'null') return message;
    return fallback;
  }

  void logError(String context, Object error) {
    final message = describeError(error);
    if (kDebugMode) debugPrint('$context: $message');
    unawaited(PosMonitoringService.instance.recordEvent(
      level: 'error',
      eventType: _eventTypeForContext(context),
      message: message,
      metadata: {'context': context},
    ));
  }

  static String _eventTypeForContext(String context) {
    final lowered = context.toLowerCase();
    if (lowered.contains('printer') || lowered.contains('print')) {
      return 'printer_failed';
    }
    if (lowered.contains('sync') ||
        lowered.contains('warmup') ||
        lowered.contains('fetch')) {
      return 'sync_failed';
    }
    if (lowered.contains('payment')) return 'payment_failed';
    if (lowered.contains('order')) return 'order_creation_failed';
    return 'pos_error';
  }

  static String? _messageFromPayload(Object? payload) {
    if (payload is String) return _cleanMessage(payload);
    if (payload is List) {
      for (final item in payload) {
        final message = _messageFromPayload(item);
        if (message != null) return message;
      }
      return null;
    }
    if (payload is Map) {
      final envelope = payload['error'];
      if (envelope is Map) {
        return _messageFromPayload(envelope['message']) ??
            _messageFromPayload(envelope['detail']) ??
            _messageFromPayload(envelope['error']);
      }
      return _messageFromPayload(payload['message']) ??
          _messageFromPayload(payload['detail']) ??
          _messageFromPayload(envelope) ??
          _firstFieldMessage(payload);
    }
    return null;
  }

  static String? _firstFieldMessage(Map payload) {
    const ignored = {
      'status',
      'success',
      'code',
      'error_code',
      'request_id',
      'requestId',
      'details',
    };
    for (final entry in payload.entries) {
      final key = entry.key.toString();
      if (ignored.contains(key)) continue;
      final message = _messageFromPayload(entry.value);
      if (message == null) continue;
      if (key == 'error' || key == 'message' || key == 'detail') {
        return message;
      }
      return '$key: $message';
    }
    return null;
  }

  static String? _cleanMessage(String? value) {
    final cleaned = value
        ?.replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
        .trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  Future<bool> bootstrapSession() async {
    await init();

    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      await dio.get('${ApiConstants.apiPrefix}/auth/user/');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearAllTokens();
        return false;
      }
      rethrow;
    }
  }

  /// Save tokens securely
  Future<void> saveTokens({required String access, String? refresh}) async {
    await init();
    await _secureStorage.write(key: tokenKey, value: access);
    if (refresh != null) {
      await _secureStorage.write(key: refreshTokenKey, value: refresh);
    }
    await _clearLegacyTokens();
  }

  /// Helper to remove all tokens
  Future<void> clearAllTokens() async {
    await init();
    await _secureStorage.delete(key: tokenKey);
    await _secureStorage.delete(key: refreshTokenKey);
    await _clearLegacyTokens();
  }

  /// Get current access token
  Future<String?> getAccessToken() async {
    await init();
    return _readSecret(tokenKey);
  }

  Future<String?> getRefreshToken() async {
    await init();
    return _readSecret(refreshTokenKey);
  }

  Future<String?> _readSecret(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _migrateLegacyTokens() async {
    final prefs = _prefs!;
    final legacyAccess = prefs.getString(tokenKey);
    final legacyRefresh = prefs.getString(refreshTokenKey);

    if (legacyAccess != null && legacyAccess.isNotEmpty) {
      final storedAccess = await _readSecret(tokenKey);
      if (storedAccess == null || storedAccess.isEmpty) {
        await _secureStorage.write(key: tokenKey, value: legacyAccess);
      }
    }
    if (legacyRefresh != null && legacyRefresh.isNotEmpty) {
      final storedRefresh = await _readSecret(refreshTokenKey);
      if (storedRefresh == null || storedRefresh.isEmpty) {
        await _secureStorage.write(key: refreshTokenKey, value: legacyRefresh);
      }
    }

    if (legacyAccess != null || legacyRefresh != null) {
      await _clearLegacyTokens();
    }
  }

  Future<void> _clearLegacyTokens() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(tokenKey);
    await prefs.remove(refreshTokenKey);
  }
}

// Global accessor
final apiClient = ApiClient();
