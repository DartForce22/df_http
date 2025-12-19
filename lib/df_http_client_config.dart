import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '/models/result.dart';

/// Configuration object for HTTP API calls used with df_http.
///
/// This class defines how requests are made, retried, and how headers are
/// handled. It also supports token refresh logic.
class DfHttpClientConfig {
  /// Creates a new [DfHttpClientConfig] instance.
  ///
  /// [baseApiUrl] is required and should be the base URL for your API.
  ///
  /// - [encoding]: Optional request/response encoding (e.g. UTF-8).
  /// - [headers]: Default headers added to every request.
  /// - [timeout]: Request timeout in seconds (default: 10).
  /// - [retryApiCall]: Whether failed API calls should automatically retry.
  /// - [waitForTokenRefresh]: Whether requests should wait until token refresh completes.
  /// - [maxRetryAttempts]: Maximum number of retry attempts for failed requests.
  /// - [refreshToken]: Callback used to refresh tokens if authentication fails.
  /// - [maxDelayMs]: Represent the maximum waiting time on API retry. Default set to _60000ms_
  /// ---
  /// - [random]: Provide a "seeded" Random in tests so that the retry delay is predictable
  ///
  DfHttpClientConfig({
    required this.baseApiUrl,
    this.encoding,
    this.headers = const {},
    this.timeout = 10,
    this.retryApiCall = true,
    this.waitForTokenRefresh = true,
    this.maxRetryAttempts = 3,
    this.refreshToken,
    this.maxDelayMs = 60000,
    Random? random,
  }) : _rand = random ?? Random();

  final int maxDelayMs;
  final String baseApiUrl;
  final Encoding? encoding;
  Map<String, String> headers;
  final int timeout;
  final bool retryApiCall;
  bool waitForTokenRefresh;
  final int maxRetryAttempts;
  Future<Result<String, Exception>> Function()? refreshToken;

  /// Used to generate random jitter value for the retry waiting time
  final Random _rand;

  void addHeaderParameters(Map<String, String> headers) {
    this.headers.addAll(headers);
  }

  void replaceHeaders(Map<String, String> headers) {
    this.headers = headers;
  }

  bool removeAuthorization() {
    return headers.remove(HttpHeaders.authorizationHeader) != null;
  }

  bool removeHeaderParameter(String headerName) {
    return headers.remove(headerName) != null;
  }

  bool authorizationPresent() {
    return headers.containsKey(HttpHeaders.authorizationHeader);
  }

  String? getAuthorizationToken() {
    String? authorizationToken = headers[HttpHeaders.authorizationHeader];
    if (authorizationToken != null) {
      authorizationToken = authorizationToken.replaceFirst("Bearer ", "");
    }
    return authorizationToken;
  }

  DfHttpClientConfig clone() {
    return DfHttpClientConfig(
      baseApiUrl: baseApiUrl,
      encoding: encoding,
      headers: {...headers},
      timeout: timeout,
      retryApiCall: retryApiCall,
      maxRetryAttempts: maxRetryAttempts,
      refreshToken: refreshToken,
    );
  }

  DfHttpClientConfig copyWith({
    String? baseApiUrl,
    Encoding? encoding,
    Map<String, String>? headers,
    int? timeout,
    bool? retryApiCall,
    bool? waitForTokenRefresh,
    int? maxRetryAttempts,
    Future<Result<String, Exception>> Function()? refreshToken,
  }) {
    return DfHttpClientConfig(
      baseApiUrl: baseApiUrl ?? this.baseApiUrl,
      encoding: encoding ?? this.encoding,
      headers: headers ?? {...this.headers},
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      refreshToken: refreshToken ?? this.refreshToken,
      retryApiCall: retryApiCall ?? this.retryApiCall,
      timeout: timeout ?? this.timeout,
      waitForTokenRefresh: waitForTokenRefresh ?? this.waitForTokenRefresh,
    );
  }

  int calculateRetryWaitingPeriod(int retryCount) {
    // Exponential backoff with jitter
    final attemptsUsed = (maxRetryAttempts - retryCount);
    final baseMs = 500; // base delay in ms
    final cappedAttempts = min(attemptsUsed, 10); // prevents huge shifts
    final exponential =
        baseMs * (1 << cappedAttempts); // base * 2^cappedAttempts
    final jitter = _rand.nextInt(200); // 0..199 ms jitter
    var retryPauseDurationMs = exponential + jitter;

    //Prevents too long retry awaits
    if (retryPauseDurationMs > maxDelayMs) {
      retryPauseDurationMs = maxDelayMs;
    }

    return retryPauseDurationMs;
  }
}
