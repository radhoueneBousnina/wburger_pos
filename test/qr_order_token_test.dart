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

  test('extracts QR order tokens from live URL and prefix variants', () {
    expect(
      extractQrOrderToken('https://w-burger.com/orders/qr?code=qr_live_ABC123'),
      'qr_live_ABC123',
    );
    expect(
      extractQrOrderToken(
        'https://w-burger.com/orders/qr/qr-live-token-42/',
      ),
      'qr-live-token-42',
    );
    expect(
      extractQrOrderToken('W-BURGER: signed.token:ABC123'),
      'signed.token:ABC123',
    );
    expect(extractQrOrderToken('qr_live_ABC123'), 'qr_live_ABC123');
  });

  test('returns null when scanner payload has no QR order token', () {
    expect(extractQrOrderToken('not an order qr'), isNull);
    expect(extractQrOrderToken(''), isNull);
  });
}
