import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/features/sales/utils/qr_order_token.dart';

void main() {
  test('extracts QR order tokens from scanner payloads', () {
    const token = '123e4567-e89b-12d3-a456-426614174000';

    expect(extractQrOrderToken(token), token);
    expect(
      extractQrOrderToken(token.toUpperCase()),
      token,
    );
    expect(
      extractQrOrderToken('https://wburger.tn/orders/qr?token=$token'),
      token,
    );
    expect(
      extractQrOrderToken('WBURGER:$token\n'),
      token,
    );
  });

  test('returns null when scanner payload has no QR order token', () {
    expect(extractQrOrderToken('not an order qr'), isNull);
    expect(extractQrOrderToken(''), isNull);
  });
}
