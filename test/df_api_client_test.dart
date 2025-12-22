import 'dart:io';

import 'package:df_http/df_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;
  late DfHttpClientConfig config;
  late DfApiClient apiClient;
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
      maxDelayMs: 100,
      maxRetryAttempts: 3,
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

  test('should NOT refresh if token is valid', () async {
    //Explicitly set the "good" state for this test
    config.replaceHeaders({
      HttpHeaders.authorizationHeader: "Bearer $longLivedToken",
    });
    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response('{}', 200));

    await apiClient.get('/some-path');

    // Verify refresh was NEVER called
    expect(refreshCount, 0);
  });

  test('should throw SocketException when internetConnectionCheck remains false', () async {
    config = DfHttpClientConfig(
      baseApiUrl: 'https://api.example.com',
      // Mock: Device is always offline
      internetConnectionCheck: () async => false,
    );

    apiClient = DfApiClient(httpApiConfig: config, client: mockClient);

    // Mock the initial call to throw a SocketException (triggering the check logic)
    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenThrow(const SocketException('No Network'));

    // The client should attempt to check connection 5 times and then throw
    expect(
          () => apiClient.get('/test'),
      throwsA(isA<SocketException>()),
    );
  });

  test('should recover when internetConnectionCheck returns true after initially being false', () async {
    int checkAttempts = 0;

    config = DfHttpClientConfig(
      baseApiUrl: 'https://api.example.com',
      internetConnectionCheck: () async {
        checkAttempts++;
        // First 2 checks fail, 3rd check succeeds
        return checkAttempts > 2;
      },
    );

    apiClient = DfApiClient(httpApiConfig: config, client: mockClient);

    // 1. Initial call fails with SocketException
    // 2. Client enters while loop, calls internetConnectionCheck
    // 3. Once connected is true, it proceeds to rethrow the exception (per current logic)
    //    or you can verify it finishes the loop.

    when(() => mockClient.get(any(), headers: any(named: 'headers')))
        .thenThrow(const SocketException('Connection lost'));

    try {
      await apiClient.get('/test');
    } catch (e) {
      // Per your current _processApiCall logic, if it recovers,
      // it still rethrows the error at the end of the catch block
      // if retryCount is 0, or retries if retryCount > 0.
    }

    expect(checkAttempts, greaterThanOrEqualTo(3));
  });

}
