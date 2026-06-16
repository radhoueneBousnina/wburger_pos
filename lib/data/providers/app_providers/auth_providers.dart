part of '../app_providers.dart';

class AuthState {
  final bool isAuthenticated;
  final String? username;
  final String? role;
  final Map<String, bool> permissions;

  const AuthState({
    this.isAuthenticated = false,
    this.username,
    this.role,
    this.permissions = const {},
  });

  static const featurePermissionKeys = [
    'can_access_pos',
    'can_apply_discount',
    'can_cancel_order',
    'can_close_session',
    'can_view_daily_stats',
    'can_access_stock',
    'can_access_purchases',
    'can_access_reporting',
    'can_open_cash_drawer',
    'can_validate_day',
    'can_manage_catalog',
    'can_manage_deals',
    'can_manage_marketing_posts',
    'can_access_kitchen',
    'can_view_loyalty',
    'can_manage_loyalty_rules',
  ];

  static Map<String, bool> permissionsFromUserDetails(
    String? role,
    Object? rawPermissions,
  ) {
    if (role == 'admin') {
      return {for (final key in featurePermissionKeys) key: true};
    }

    final source = rawPermissions is Map ? rawPermissions : const {};
    return {
      for (final key in featurePermissionKeys)
        key: source[key] == true ||
            source[key]?.toString().toLowerCase() == 'true',
    };
  }

  AuthState copyWith({
    bool? isAuthenticated,
    String? username,
    String? role,
    Map<String, bool>? permissions,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(bool initialIsAuthenticated)
      : super(AuthState(
          isAuthenticated: initialIsAuthenticated,
        ));

  Future<bool> login(String username, String password) async {
    try {
      final loginUrl = Uri.parse(
        apiClient.dio.options.baseUrl,
      ).resolve(ApiConstants.login);
      debugPrint('W Burger POS login URL: $loginUrl');
      debugPrint('W Burger POS app URL: ${Uri.base}');
      debugPrint('W Burger POS API base URL: ${apiClient.dio.options.baseUrl}');
      unawaited(PosMonitoringService.instance.logLocal(
        'Login started. api_base=${apiClient.dio.options.baseUrl} '
        'login_url=$loginUrl',
      ));

      final res = await apiClient.dio.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
      );

      final access = res.data['access'] ?? res.data['key'] ?? res.data['token'];
      final refresh = res.data['refresh'];

      if (access != null) {
        await apiClient.saveTokens(
          access: access.toString(),
          refresh: refresh?.toString(),
        );

        // Fetch user info to verify role
        final userRes = await apiClient.dio.get('/api/v1/auth/user/');
        final role = userRes.data['role']?.toString().toLowerCase();
        final permissions = AuthState.permissionsFromUserDetails(
          role,
          userRes.data['feature_permissions'],
        );

        if (role != 'admin' && role != 'staff') {
          // Unauthorized role for POS
          await apiClient.clearAllTokens();
          state = const AuthState();
          throw 'Access Denied: Only Staff and Admins can access the POS system.';
        }

        if (role != 'admin' && permissions['can_access_pos'] != true) {
          await apiClient.clearAllTokens();
          state = const AuthState();
          throw 'Access Denied: Your account does not have POS access.';
        }

        state = AuthState(
          isAuthenticated: true,
          username: userRes.data['username']?.toString() ?? username,
          role: role,
          permissions: permissions,
        );
        return true;
      }
    } on DioException catch (e) {
      debugPrint('W Burger POS login failed');
      debugPrint('  request URL: ${e.requestOptions.uri}');
      debugPrint('  app URL: ${Uri.base}');
      debugPrint('  Dio type: ${e.type}');
      debugPrint('  Dio message: ${e.message}');
      debugPrint('  raw error: ${e.error}');
      debugPrint('  status: ${e.response?.statusCode}');
      debugPrint('  response: ${e.response?.data}');
      final statusCode = e.response?.statusCode?.toString() ?? 'none';
      final errorMessage = apiClient.describeError(
        e,
        fallback: 'Unable to sign in right now.',
      );
      unawaited(PosMonitoringService.instance.logLocal(
        'Login failed. url=${e.requestOptions.uri} type=${e.type.name} '
        'status=$statusCode message=$errorMessage',
      ));
      apiClient.logError('Login error', e);
      throw errorMessage;
    } catch (e) {
      apiClient.logError('Login generic error', e);
      throw e.toString().replaceFirst('Exception: ', '');
    }
    return false;
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post(ApiConstants.logout);
    } catch (e) {
      apiClient.logError('Backend logout failed', e);
    }
    await apiClient.clearAllTokens();
    state = const AuthState();
  }

  bool hasPermission(String key) {
    return state.permissions[key] ?? false;
  }
}

class CashDrawerOpenResult {
  final bool logSaved;
  final ReceiptPrintResult? printerResult;
  final String? error;

  const CashDrawerOpenResult({
    required this.logSaved,
    this.printerResult,
    this.error,
  });

  bool get isSuccess => logSaved && printerResult?.isSuccess == true;

  String get message {
    if (isSuccess) return 'Cash drawer opened and logged.';
    if (error != null && error!.isNotEmpty) return error!;
    final printMessage = printerResult?.message;
    if (logSaved && printMessage != null) {
      return 'Drawer log was saved, but the hardware did not open: $printMessage';
    }
    return 'Unable to open the cash drawer.';
  }
}

final initialAuthStateProvider = Provider<bool>((ref) => false);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final initAuth = ref.watch(initialAuthStateProvider);
  return AuthNotifier(initAuth);
});

// ============================================================
// POS SESSION PROVIDER
// ============================================================
