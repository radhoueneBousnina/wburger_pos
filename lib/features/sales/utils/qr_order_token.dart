final RegExp qrOrderTokenPattern = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

String? extractQrOrderToken(String value) {
  final match = qrOrderTokenPattern.firstMatch(value.trim());
  return match?.group(0)?.toLowerCase();
}
