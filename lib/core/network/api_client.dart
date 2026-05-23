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

  static const String tokenKey = 'wburger_auth_token';
  static const String refreshTokenKey = 'wburger_refresh_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  bool _isRefreshing = false;

  factory ApiClient() {
    return _instance;
  }

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
          final token = await getAccessToken();
          if (token != null && token.isNotEmpty) {
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
          // Handle 401 Unauthorized by attempting a token refresh
          if (e.response?.statusCode == 401 && !_isRefreshing) {
            final refreshToken = await getRefreshToken();

            if (refreshToken != null && refreshToken.isNotEmpty) {
              _isRefreshing = true;
              try {
                // Attempt to refresh the access token
                final refreshRes = await Dio().post(
                  '${ApiConstants.baseUrl}${ApiConstants.apiPrefix}/auth/token/refresh/',
                  data: {'refresh': refreshToken},
                );

                final newAccessToken = refreshRes.data['access'];
                if (newAccessToken != null) {
                  await _secureStorage.write(
                    key: tokenKey,
                    value: newAccessToken.toString(),
                  );
                  final newRefreshToken = refreshRes.data['refresh'];
                  if (newRefreshToken != null) {
                    await _secureStorage.write(
                      key: refreshTokenKey,
                      value: newRefreshToken.toString(),
                    );
                  }
                  await _clearLegacyTokens();

                  // Update the request with the new token and retry
                  final options = e.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccessToken';

                  final response = await dio.fetch(options);
                  _isRefreshing = false;
                  return handler.resolve(response);
                }
              } catch (refreshError) {
                // If refresh fails, log out user.
                if (kDebugMode) debugPrint('Refresh token failed.');
                await clearAllTokens();
              } finally {
                _isRefreshing = false;
              }
            } else {
              await clearAllTokens();
            }
          }
          handler.next(e);
        },
      ),
    );
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
