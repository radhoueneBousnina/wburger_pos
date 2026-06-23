import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/data/providers/app_providers.dart';

void main() {
  test('login token parser accepts dj-rest-auth token aliases', () {
    final response = {
      'access_token': 'access.jwt',
      'refresh_token': 'refresh.jwt',
    };

    expect(loginAccessTokenFromResponse(response), 'access.jwt');
    expect(loginRefreshTokenFromResponse(response), 'refresh.jwt');
  });

  test('login token parser accepts current backend token names', () {
    final response = {
      'access': 'access.jwt',
      'refresh': 'refresh.jwt',
    };

    expect(loginAccessTokenFromResponse(response), 'access.jwt');
    expect(loginRefreshTokenFromResponse(response), 'refresh.jwt');
  });
}
