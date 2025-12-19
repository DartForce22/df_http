import 'dart:io';

import 'package:df_http/df_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;
  late final DfHttpClientConfig config;
  late final DfApiClient apiClient;
  int refreshCount = 0;
  const longLivedToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjI1MzQwMjMwMDc5OSwic3ViIjoiMTIzNDU2Nzg5MCIsIm5hbWUiOiJUZXN0IFVzZXIiLCJpYXQiOjE1MTYyMzkwMjJ9.bW9ja19zaWduYXR1cmVfaGVyZV9ub3RfdmFsaWRhdGVkX2luX3VuaXRfdGVzdHM";
  // This is a dummy JWT payload with "exp": 1 (Jan 1, 1970)
  const expiredToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
      "eyJleHAiOjF9."
      "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";

  setUpAll(() {
    // This tells mocktail: "If you need a dummy Uri, use this one"
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockClient = MockClient();
    refreshCount = 0;

    config = DfHttpClientConfig(
      baseApiUrl: 'https://api.example.com',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $expiredToken'},
      refreshToken: () async {
        refreshCount++;
        await Future.delayed(
          Duration(milliseconds: 100),
        ); // Simulate network lag
        return Success(longLivedToken);
      },
    );

    apiClient = DfApiClient(httpApiConfig: config, client: mockClient);
  });

  test(
    'Multiple concurrent calls should only trigger refreshToken ONCE',
    () async {
      // 1. Mock a standard response
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('{"status": "ok"}', 200));

      // 2. Trigger 5 calls simultaneously
      // Assuming you have a way to make JwtDecoder.isExpired return true for the test
      await Future.wait([
        apiClient.get('/user'),
        apiClient.get('/settings'),
        apiClient.get('/notifications'),
        apiClient.get('/profile'),
        apiClient.get('/balance'),
      ]);

      // 3. Verify the logic
      expect(
        refreshCount,
        equals(1),
        reason: 'Refresh should be locked after the first call starts',
      );
      expect(config.getAuthorizationToken(), contains(longLivedToken));
    },
  );
}
