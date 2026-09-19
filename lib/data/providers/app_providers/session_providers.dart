part of '../app_providers.dart';

class PosSessionStatus {
  final String? activeSessionId;
  final String? activeSessionDate;
  final double activeSessionOpeningFund;
  final bool todaySessionExists;
  final bool yesterdaySessionOpen;
  final String? yesterdaySessionId;
  final bool isLocal;
  final bool pendingSync;

  const PosSessionStatus({
    this.activeSessionId,
    this.activeSessionDate,
    this.activeSessionOpeningFund = 0,
    this.todaySessionExists = false,
    this.yesterdaySessionOpen = false,
    this.yesterdaySessionId,
    this.isLocal = false,
    this.pendingSync = false,
  });

  bool get hasActiveSession =>
      activeSessionId != null && activeSessionId!.isNotEmpty;

  bool get isTodaySessionClosed => !hasActiveSession && todaySessionExists;

  int get activeSessionDateDiffDays {
    if (!hasActiveSession || activeSessionDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final parts = activeSessionDate!.split('-');
    if (parts.length != 3) return 0;
    final sessionDate =
        DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return today.difference(sessionDate).inDays;
  }

  factory PosSessionStatus.fromJson(Map<String, dynamic> json) {
    return PosSessionStatus(
      activeSessionId: json['active_session_id']?.toString(),
      activeSessionDate: json['active_session_date']?.toString(),
      activeSessionOpeningFund: double.tryParse(
            json['active_session_opening_fund']?.toString() ?? '0',
          ) ??
          0,
      todaySessionExists: json['today_session_exists'] == true,
      yesterdaySessionOpen: json['yesterday_session_open'] == true,
      yesterdaySessionId: json['yesterday_session_id']?.toString(),
    );
  }
}

class _StoredPosSession {
  final String id;
  final String date;
  final DateTime openedAt;
  final double openingFund;
  final bool pendingSync;

  const _StoredPosSession({
    required this.id,
    required this.date,
    required this.openedAt,
    required this.openingFund,
    required this.pendingSync,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'opened_at': openedAt.toUtc().toIso8601String(),
        'opening_fund': openingFund,
        'pending_sync': pendingSync,
      };

  factory _StoredPosSession.fromJson(Map<String, dynamic> json) {
    return _StoredPosSession(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      openedAt: DateTime.parse(json['opened_at'].toString()),
      openingFund:
          double.tryParse(json['opening_fund']?.toString() ?? '0') ?? 0,
      pendingSync: json['pending_sync'] == true,
    );
  }

  _StoredPosSession copyWith({
    String? id,
    bool? pendingSync,
  }) {
    return _StoredPosSession(
      id: id ?? this.id,
      date: date,
      openedAt: openedAt,
      openingFund: openingFund,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}

class TpeReceiptUploadSession {
  final String token;
  final String sessionId;
  final String sessionDate;
  final String uploadUrl;
  final double systemCardAmount;
  final double actualCardAmount;
  final double differenceAmount;
  final DateTime? expiresAt;
  final bool isExpired;
  final bool isUploaded;
  final DateTime? uploadedAt;
  final String? originalFilename;

  const TpeReceiptUploadSession({
    required this.token,
    required this.sessionId,
    required this.sessionDate,
    required this.uploadUrl,
    required this.systemCardAmount,
    required this.actualCardAmount,
    required this.differenceAmount,
    required this.expiresAt,
    required this.isExpired,
    required this.isUploaded,
    required this.uploadedAt,
    required this.originalFilename,
  });

  factory TpeReceiptUploadSession.fromJson(Map<String, dynamic> json) {
    double amount(String key) =>
        double.tryParse(json[key]?.toString() ?? '') ?? 0.0;
    DateTime? dateTime(String key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return TpeReceiptUploadSession(
      token: json['token']?.toString() ?? '',
      sessionId: json['session']?.toString() ?? '',
      sessionDate: json['session_date']?.toString() ?? '',
      uploadUrl: json['upload_url']?.toString() ?? '',
      systemCardAmount: amount('system_card_amount'),
      actualCardAmount: amount('actual_card_amount'),
      differenceAmount: amount('difference_amount'),
      expiresAt: dateTime('expires_at'),
      isExpired: json['is_expired'] == true,
      isUploaded: json['is_uploaded'] == true,
      uploadedAt: dateTime('uploaded_at'),
      originalFilename: json['original_filename']?.toString(),
    );
  }
}

class StockDocumentUploadSession {
  final String token;
  final String sessionId;
  final String sessionDate;
  final String uploadUrl;
  final DateTime? expiresAt;
  final bool isExpired;
  final bool isUploaded;
  final DateTime? uploadedAt;
  final String? originalFilename;

  const StockDocumentUploadSession({
    required this.token,
    required this.sessionId,
    required this.sessionDate,
    required this.uploadUrl,
    required this.expiresAt,
    required this.isExpired,
    required this.isUploaded,
    required this.uploadedAt,
    required this.originalFilename,
  });

  factory StockDocumentUploadSession.fromJson(Map<String, dynamic> json) {
    DateTime? dateTime(String key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return StockDocumentUploadSession(
      token: json['token']?.toString() ?? '',
      sessionId: json['session']?.toString() ?? '',
      sessionDate: json['session_date']?.toString() ?? '',
      uploadUrl: json['upload_url']?.toString() ?? '',
      expiresAt: dateTime('expires_at'),
      isExpired: json['is_expired'] == true,
      isUploaded: json['is_uploaded'] == true,
      uploadedAt: dateTime('uploaded_at'),
      originalFilename: json['original_filename']?.toString(),
    );
  }
}

class PosSessionService {
  static const _storedSessionKey = 'wburger_pos_active_session_v1';
  final bool Function()? isTestMode;

  const PosSessionService({this.isTestMode});

  bool get _testModeActive => isTestMode?.call() == true;

  PosSessionStatus _trainingStatus() {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return PosSessionStatus(
      activeSessionId: 'test-mode-session',
      activeSessionDate: date,
      todaySessionExists: true,
    );
  }

  String _localDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  bool isNetworkFailure(Object error) {
    if (error is! DioException || error.response != null) return false;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.unknown;
  }

  Future<_StoredPosSession?> _loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storedSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final session = _StoredPosSession.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (session.id.isEmpty || session.date.isEmpty) return null;
      return session;
    } catch (_) {
      await prefs.remove(_storedSessionKey);
      return null;
    }
  }

  Future<void> _saveStoredSession(_StoredPosSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storedSessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storedSessionKey);
  }

  PosSessionStatus _statusFromStored(_StoredPosSession session) {
    return PosSessionStatus(
      activeSessionId: session.id,
      activeSessionDate: session.date,
      activeSessionOpeningFund: session.openingFund,
      todaySessionExists: session.date == _localDate(DateTime.now()),
      isLocal: true,
      pendingSync: session.pendingSync,
    );
  }

  Future<void> _cacheServerStatus(PosSessionStatus status) async {
    if (!status.hasActiveSession || status.activeSessionDate == null) {
      await clearStoredSession();
      return;
    }
    final previous = await _loadStoredSession();
    await _saveStoredSession(_StoredPosSession(
      id: status.activeSessionId!,
      date: status.activeSessionDate!,
      openedAt: previous?.date == status.activeSessionDate
          ? previous!.openedAt
          : DateTime.now(),
      openingFund: status.activeSessionOpeningFund,
      pendingSync: false,
    ));
  }

  Future<void> syncPendingSession() async {
    if (_testModeActive) return;
    final stored = await _loadStoredSession();
    if (stored == null || !stored.pendingSync) return;
    final response = await apiClient.dio.post(
      ApiConstants.sessionSyncOffline,
      data: {
        'session_date': stored.date,
        'opened_at': stored.openedAt.toUtc().toIso8601String(),
        'opening_fund': stored.openingFund.toStringAsFixed(3),
      },
    );
    final serverId = response.data is Map
        ? (response.data['id']?.toString() ?? stored.id)
        : stored.id;
    await _saveStoredSession(stored.copyWith(
      id: serverId,
      pendingSync: false,
    ));
  }

  Future<String?> effectiveSessionDate() async {
    if (_testModeActive) return _trainingStatus().activeSessionDate;
    return (await _loadStoredSession())?.date;
  }

  Future<PosSessionStatus> fetchStatus() async {
    if (_testModeActive) {
      return _trainingStatus();
    }
    try {
      await syncPendingSession();
      final response = await apiClient.dio.get(ApiConstants.sessionStatus);
      final status = PosSessionStatus.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await _cacheServerStatus(status);
      return status;
    } catch (error) {
      if (!isNetworkFailure(error)) rethrow;
      final stored = await _loadStoredSession();
      if (stored == null) rethrow;
      return _statusFromStored(stored);
    }
  }

  Future<PosSessionStatus> openTodaySession({double openingFund = 0}) async {
    if (_testModeActive) {
      return _trainingStatus();
    }
    try {
      await apiClient.dio.post(
        ApiConstants.sessionOpenToday,
        data: {'opening_fund': openingFund.toStringAsFixed(3)},
      );
      return fetchStatus();
    } catch (error) {
      if (!isNetworkFailure(error)) rethrow;
      final openedAt = DateTime.now();
      final stored = _StoredPosSession(
        id: 'offline-session-${openedAt.microsecondsSinceEpoch}',
        date: _localDate(openedAt),
        openedAt: openedAt,
        openingFund: openingFund,
        pendingSync: true,
      );
      await _saveStoredSession(stored);
      return _statusFromStored(stored);
    }
  }

  Future<PosSessionStatus> reopenTodaySession() async {
    if (_testModeActive) {
      return _trainingStatus();
    }
    await apiClient.dio.post(ApiConstants.sessionReopenToday);
    return fetchStatus();
  }

  Future<void> createCashClosure({
    required String sessionId,
    required double actualCash,
    required double actualCard,
    required double actualOther,
    required double actualFund,
  }) async {
    if (_testModeActive) return;
    await apiClient.dio.post(
      ApiConstants.closures,
      data: {
        'session': sessionId,
        'actual_cash': actualCash.toStringAsFixed(3),
        'actual_card': actualCard.toStringAsFixed(3),
        'actual_other': actualOther.toStringAsFixed(3),
        'actual_fund': actualFund.toStringAsFixed(3),
      },
    );
  }

  Future<void> submitStockVerification({
    required String sessionId,
    required List<Map<String, dynamic>> items,
    String? note,
    String? stockDocumentUploadToken,
  }) async {
    if (_testModeActive) return;
    await apiClient.dio.post(
      ApiConstants.stockVerificationSubmit,
      data: {
        'session': sessionId,
        'items': items,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (stockDocumentUploadToken != null &&
            stockDocumentUploadToken.trim().isNotEmpty)
          'stock_document_upload_token': stockDocumentUploadToken.trim(),
      },
    );
  }

  Future<TpeReceiptUploadSession> createTpeReceiptUploadSession({
    required String sessionId,
    required double systemCardAmount,
    required double actualCardAmount,
  }) async {
    if (_testModeActive) {
      return TpeReceiptUploadSession(
        token: 'test-mode-token',
        sessionId: sessionId,
        sessionDate: _trainingStatus().activeSessionDate ?? '',
        uploadUrl: '',
        systemCardAmount: systemCardAmount,
        actualCardAmount: actualCardAmount,
        differenceAmount: actualCardAmount - systemCardAmount,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isExpired: false,
        isUploaded: true,
        uploadedAt: DateTime.now(),
        originalFilename: 'training-tpe-receipt.jpg',
      );
    }
    final response = await apiClient.dio.post(
      '${ApiConstants.dailySessions}$sessionId${ApiConstants.sessionTpeUpload}',
      data: {
        'system_card_amount': systemCardAmount.toStringAsFixed(3),
        'actual_card_amount': actualCardAmount.toStringAsFixed(3),
      },
    );
    return TpeReceiptUploadSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TpeReceiptUploadSession> fetchTpeReceiptUploadSession({
    required String sessionId,
    required String token,
  }) async {
    if (_testModeActive) {
      return TpeReceiptUploadSession(
        token: token,
        sessionId: sessionId,
        sessionDate: _trainingStatus().activeSessionDate ?? '',
        uploadUrl: '',
        systemCardAmount: 0,
        actualCardAmount: 0,
        differenceAmount: 0,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isExpired: false,
        isUploaded: true,
        uploadedAt: DateTime.now(),
        originalFilename: 'training-tpe-receipt.jpg',
      );
    }
    final response = await apiClient.dio.get(
      '${ApiConstants.dailySessions}$sessionId${ApiConstants.sessionTpeUpload}',
      queryParameters: {'token': token},
    );
    return TpeReceiptUploadSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<StockDocumentUploadSession> createStockDocumentUploadSession({
    required String sessionId,
  }) async {
    if (_testModeActive) {
      return StockDocumentUploadSession(
        token: 'test-mode-stock-document-token',
        sessionId: sessionId,
        sessionDate: _trainingStatus().activeSessionDate ?? '',
        uploadUrl: '',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isExpired: false,
        isUploaded: true,
        uploadedAt: DateTime.now(),
        originalFilename: 'training-stock-verification.jpg',
      );
    }
    final response = await apiClient.dio.post(
      '${ApiConstants.dailySessions}$sessionId${ApiConstants.sessionStockDocumentUpload}',
    );
    return StockDocumentUploadSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<StockDocumentUploadSession> fetchStockDocumentUploadSession({
    required String sessionId,
    required String token,
  }) async {
    if (_testModeActive) {
      return StockDocumentUploadSession(
        token: token,
        sessionId: sessionId,
        sessionDate: _trainingStatus().activeSessionDate ?? '',
        uploadUrl: '',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isExpired: false,
        isUploaded: true,
        uploadedAt: DateTime.now(),
        originalFilename: 'training-stock-verification.jpg',
      );
    }
    final response = await apiClient.dio.get(
      '${ApiConstants.dailySessions}$sessionId${ApiConstants.sessionStockDocumentUpload}',
      queryParameters: {'token': token},
    );
    return StockDocumentUploadSession.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> closeSession(
    String sessionId, {
    String? staffNote,
    Uint8List? tpeBillBytes,
    String? tpeBillFileName,
  }) async {
    if (_testModeActive) return;
    final data = <String, dynamic>{
      if (staffNote != null && staffNote.trim().isNotEmpty)
        'staff_note': staffNote.trim(),
    };

    if (tpeBillBytes != null) {
      data['tpe_bill'] = MultipartFile.fromBytes(
        tpeBillBytes,
        filename: tpeBillFileName ?? 'tpe-receipt.jpg',
      );
    }

    await apiClient.dio.post(
      '${ApiConstants.dailySessions}$sessionId${ApiConstants.sessionClose}',
      data: tpeBillBytes == null ? data : FormData.fromMap(data),
    );
    await clearStoredSession();
  }

  String describeApiError(Object error, {String fallback = 'Request failed'}) {
    return apiClient.describeError(error, fallback: fallback);
  }
}

final posSessionServiceProvider = Provider<PosSessionService>((ref) {
  return PosSessionService(
    isTestMode: () => ref.read(testModeProvider).isActive,
  );
});

final activeSessionStatusProvider =
    FutureProvider<PosSessionStatus?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return null;
  }
  return ref.watch(posSessionServiceProvider).fetchStatus();
});

// ============================================================
// CATALOG PROVIDERS
// ============================================================
