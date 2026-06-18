final RegExp qrOrderTokenPattern = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

final RegExp _standaloneTokenPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._~:=+-]{7,255}$',
);

const _queryTokenKeys = {
  'token',
  'redemption_token',
  'redemptionToken',
  'qr_token',
  'qrToken',
  'code',
};

String? extractQrOrderToken(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final uuidMatch = qrOrderTokenPattern.firstMatch(trimmed);
  if (uuidMatch != null) {
    return uuidMatch.group(0)?.toLowerCase();
  }

  final uriToken = _extractTokenFromUri(trimmed);
  if (uriToken != null) return uriToken;

  final prefixedToken = _extractTokenFromKnownPrefix(trimmed);
  if (prefixedToken != null) return prefixedToken;

  return _normalizeTokenCandidate(trimmed);
}

String? _extractTokenFromUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.hasQuery || uri.hasAuthority)) {
    final token = _extractTokenFromParsedUri(uri);
    if (token != null) return token;
  }

  final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(value);
  if (urlMatch == null) return null;

  final embeddedUri = Uri.tryParse(urlMatch.group(0)!);
  return embeddedUri == null ? null : _extractTokenFromParsedUri(embeddedUri);
}

String? _extractTokenFromParsedUri(Uri uri) {
  final queryParameters = {
    for (final entry in uri.queryParameters.entries)
      entry.key.toLowerCase(): entry.value,
  };

  for (final key in _queryTokenKeys) {
    final value = queryParameters[key.toLowerCase()];
    final token = _normalizeTokenCandidate(value);
    if (token != null) return token;
  }

  for (final segment in uri.pathSegments.reversed) {
    final token = _normalizeTokenCandidate(segment);
    if (token != null) return token;
  }

  return null;
}

String? _extractTokenFromKnownPrefix(String value) {
  final match = RegExp(
    r'^(?:w[\s_-]*burger|wburger|order|qr)\s*[:=#-]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;
  return _normalizeTokenCandidate(match.group(1));
}

String? _normalizeTokenCandidate(String? value) {
  var candidate = value?.trim();
  if (candidate == null || candidate.isEmpty) return null;

  if ((candidate.startsWith('"') && candidate.endsWith('"')) ||
      (candidate.startsWith("'") && candidate.endsWith("'"))) {
    candidate = candidate.substring(1, candidate.length - 1).trim();
  }

  final uuidMatch = qrOrderTokenPattern.firstMatch(candidate);
  if (uuidMatch != null && uuidMatch.group(0) == candidate) {
    return candidate.toLowerCase();
  }

  if (!_standaloneTokenPattern.hasMatch(candidate)) return null;
  return candidate;
}
