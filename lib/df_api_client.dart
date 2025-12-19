import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:df_http/df_http.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '/utils/utils.dart';

const List<int> _retryStatusCodes = [502, 503, 504];

/// Centralized HTTP API client used for all network calls.
///
/// `DfApiClient` wraps the `http` package and provides:
/// - Unified GET/POST/PUT/PATCH/DELETE methods
/// - Automatic retry logic
/// - Token refresh handling
/// - Network connectivity checks
/// - Timeout handling
/// - Firebase Crashlytics error reporting
///
/// All requests are executed using configuration provided by
/// [DfHttpClientConfig].
class DfApiClient {
  /// Creates a new API client with the given HTTP configuration.
  DfApiClient({
    required this.httpApiConfig,
    http.Client? client,
    this.onErrorRecorded,
  }) : httpClient = client ?? http.Client();

  /// Use [DfApiClient] constructor instead.
  @Deprecated(
    'Use [DfApiClient] constructor instead, copyWith will be removed in future versions.',
  )
  DfApiClient copyWith({DfHttpClientConfig? httpApiConfig}) {
    return DfApiClient(httpApiConfig: httpApiConfig ?? this.httpApiConfig);
  }

  /// HTTP configuration used for all API calls.
  final DfHttpClientConfig httpApiConfig;

  final http.Client httpClient;

  /// Add a callback for recording errors to avoid Firebase dependency in tests
  final Future<void> Function(Object error, StackTrace? stack)? onErrorRecorded;

  /// Global stream to notify the UI about internet connection status
  static final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  static Stream<bool> get onConnectivityChanged => _connectionController.stream;

  ///This flag is used to determine whether the application can proceed with API calls,
  /// or all API calls have to be paused until token refreshing is done
  Completer<void>? _refreshCompleter;

  /// Executes a HTTP GET request for the given [apiPath].
  ///
  /// Applies:
  /// - Base URL resolution
  /// - Authorization headers
  /// - Timeout handling
  /// - Retry logic
  Future<Response?> get(String apiPath) async {
    Logger.log(
      "--------> START OF GET API CALL <--------",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await httpClient
            .get(apiUri, headers: httpApiConfig.headers)
            .timeout(
              Duration(seconds: httpApiConfig.timeout),
              onTimeout: () => throw Exception(
                "API Timeout exception, no response from the server for: $apiPath",
              ),
            );
      },
    );
  }

  /// Executes a HTTP POST request for the given [apiPath].
  ///
  /// If [jsonEncodeBody] is `true`, the [body] will be JSON-encoded
  /// before sending.
  Future<Response?> post(
    String apiPath, {
    Object? body,
    bool jsonEncodeBody = true,
  }) async {
    Logger.log(
      "--------> START OF POST API CALL <--------",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Object? requestBody = body;

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await httpClient
            .post(
              apiUri,
              encoding: httpApiConfig.encoding,
              body: requestBody,
              headers: httpApiConfig.headers,
            )
            .timeout(
              Duration(seconds: httpApiConfig.timeout),
              onTimeout: () => throw Exception(
                "API Timeout exception, no response from the server for: $apiPath",
              ),
            );
      },
    );
  }

  /// Executes a HTTP PATCH request for the given [apiPath].
  ///
  /// If [jsonEncodeBody] is `true`, the [body] will be JSON-encoded.
  Future<Response?> patch(
    String apiPath, {
    Object? body,
    bool jsonEncodeBody = true,
  }) async {
    Logger.log(
      "--------> START OF PATCH API CALL <--------",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Object? requestBody = body;

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }

    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await httpClient
            .patch(
              apiUri,
              encoding: httpApiConfig.encoding,
              body: requestBody,
              headers: httpApiConfig.headers,
            )
            .timeout(
              Duration(seconds: httpApiConfig.timeout),
              onTimeout: () => throw Exception(
                "API Timeout exception, no response from the server for: $apiPath",
              ),
            );
      },
    );
  }

  /// Executes a HTTP PUT request for the given [apiPath].
  ///
  /// If [jsonEncodeBody] is `true`, the [body] will be JSON-encoded.
  Future<Response?> put(
    String apiPath, {
    Object? body,
    bool jsonEncodeBody = true,
  }) async {
    Logger.log(
      "--------> START OF PUT API CALL <--------",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Object? requestBody = body;

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }

    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await httpClient
            .put(
              apiUri,
              encoding: httpApiConfig.encoding,
              body: requestBody,
              headers: httpApiConfig.headers,
            )
            .timeout(
              Duration(seconds: httpApiConfig.timeout),
              onTimeout: () => throw Exception(
                "API Timeout exception, no response from the server for: $apiPath",
              ),
            );
      },
    );
  }

  /// Executes a HTTP DELETE request for the given [apiPath].
  ///
  /// Supports an optional request body and JSON encoding.
  Future<Response?> delete(
    String apiPath, {
    Object? body,
    bool jsonEncodeBody = true,
  }) async {
    Object? requestBody = body;

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await httpClient
            .delete(
              apiUri,
              encoding: httpApiConfig.encoding,
              body: requestBody,
              headers: httpApiConfig.headers,
            )
            .timeout(
              Duration(seconds: httpApiConfig.timeout),
              onTimeout: () => throw Exception(
                "API Timeout exception, no response from the server for: $apiPath",
              ),
            );
      },
    );
  }

  /// Core request execution pipeline.
  ///
  /// Responsibilities:
  /// - Token expiration detection
  /// - Token refresh synchronization
  /// - Retry handling for failed requests
  /// - Internet connectivity recovery
  /// - Crashlytics logging
  ///
  /// [retryCount] determines how many retry attempts are still allowed.
  Future<Response?> _processApiCall(
    int retryCount, {
    required Future<Response> Function() apiCall,
    required String apiPath,
  }) async {
    Logger.log(
      "--------> PROCESSING API CALL",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Response? res;

    // Exponential backoff with jitter
    var retryPauseDurationMs = httpApiConfig.calculateRetryWaitingPeriod(
      retryCount,
    );

    // Handle token refresh if authorization is present and token is expired
    await _ensureValidToken();

    try {
      res = await apiCall();
    } catch (e, s) {
      if (e is SocketException) {
        // Notify UI that we lost connection
        _connectionController.add(false);

        //Checks if there is internet connection
        var connected = await hasInternetConnection();
        var maxConnectionCheckingAttempts = 5;

        //Seconds to wait before checking internet connection again
        var secondsToWait = 5;

        while (!connected && maxConnectionCheckingAttempts > 0) {
          maxConnectionCheckingAttempts--;
          await Future<void>.delayed(Duration(seconds: secondsToWait));

          if (secondsToWait < 10) {
            secondsToWait += 5;
          } else {
            secondsToWait = 5;
          }

          //Checks again if there is internet connection
          connected = await hasInternetConnection();

          Logger.log(
            '--------> CHECKING INTERNET CONNECTION',
            type: LogType.warning,
            tag: "DF-API-CLIENT",
          );
        }

        if (connected) {
          // Notify UI that we are back online
          _connectionController.add(true);
        } else {
          Logger.log(
            'No internet after $maxConnectionCheckingAttempts attempts',
            type: LogType.error,
          );
          // either rethrow a SocketException or return null to let caller handle
          throw SocketException('No internet connection');
        }

        await tryRecordException(exception: e, stack: s);
      }
      final body = res?.body ?? '';
      final snippet = body.length > 200
          ? '${body.substring(0, 200)}... (truncated)'
          : body;

      Logger.log(
        '--------> $e \n API CALL EXCEPTION \n RESPONSE BODY= $snippet',
        type: LogType.error,
        tag: "DF-API-CLIENT",
      );

      if (retryCount == 0) {
        rethrow;
      }
    }

    // Retry on gateway/server errors
    if (res == null || _retryStatusCodes.contains(res.statusCode)) {
      //If API call failed, this will retry API request
      if (retryCount > 0) {
        Logger.log(
          '--------> RETRY API CALL AFTER $retryPauseDurationMs milliseconds - $retryCount RETRIES LEFT',
          type: LogType.warning,
          tag: "DF-API-CLIENT",
        );

        await tryRecordException(
          exception: Exception(
            '--------> RETRY API PATH=($apiPath) CALL AFTER $retryPauseDurationMs milliseconds - $retryCount RETRIES LEFT',
          ),
        );

        await Future<void>.delayed(
          Duration(milliseconds: retryPauseDurationMs),
        );
        return _processApiCall(
          apiPath: apiPath,
          retryCount - 1,
          apiCall: apiCall,
        );
      }
    }
    Logger.log(
      "--------> API RESPONSE STATUS CODE ${res?.statusCode}",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Logger.log(
      "--------> END OF API CALL <--------\n",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    return res;
  }

  /// Builds the full request [Uri] from the base API URL and [apiPath].
  Uri _generateApiUri(String apiPath) {
    Logger.log(
      "--------> GENERATING API URL",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Logger.log(
      "--------> API URL '${httpApiConfig.baseApiUrl}$apiPath'",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    return Uri.parse('${httpApiConfig.baseApiUrl}$apiPath');
  }

  /// Checks whether the device currently has an active internet connection.
  ///
  /// Returns `true` if DNS lookup succeeds, otherwise `false`.
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureValidToken() async {
    if (!httpApiConfig.waitForTokenRefresh ||
        httpApiConfig.refreshToken == null ||
        !httpApiConfig.authorizationPresent()) {
      return;
    }
    // If a refresh is already happening, code execution MUST wait.
    while (_refreshCompleter != null) {
      await _refreshCompleter?.future;
    }

    //THE CHECK
    if (JwtDecoder.isExpired(httpApiConfig.getAuthorizationToken())) {
      // Create the completer IMMEDIATELY before calling any 'await'.
      // Dart is single-threaded, no other code can run between
      _refreshCompleter = Completer<void>();

      try {
        //THE ASYNC WORK
        //Any other request that enters now
        //will see _refreshCompleter != null and hit the 'while' loop above.
        var res = await httpApiConfig.refreshToken!().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException("Token refresh timed out"),
        );

        switch (res) {
          case Success(value: final token):
            Logger.log("REFRESHING TOKEN SUCCESSFUL", type: LogType.api);
            //Update the headers so the next calls in line don't refresh!
            httpApiConfig.addHeaderParameters({
              HttpHeaders.authorizationHeader: "Bearer $token",
            });
            break;
          case Failure(exception: Exception e):
            throw TimeoutException("Token refresh failed $e");
        }
      } finally {
        //THE RELEASE
        _refreshCompleter?.complete();
        _refreshCompleter = null;
      }
    }
  }

  /// Close underlying resources used by this client.
  /// Call this when the client is no longer needed.
  void dispose() {
    try {
      httpClient.close();
      Logger.log(
        "DF-API-CLIENT httpClient closed",
        type: LogType.api,
        tag: "DF-API-CLIENT",
      );
    } catch (e) {
      Logger.log(
        "Failed closing httpClient: $e",
        type: LogType.warning,
        tag: "DF-API-CLIENT",
      );
    }
  }

  /// Attempts to log an exception to an external monitoring service.
  ///
  /// If [onErrorRecorded] is provided in the constructor, the exception
  /// will be passed to that callback (ideal for unit testing or custom logging).
  ///
  /// Otherwise, it defaults to logging via **Firebase Crashlytics** with
  /// the 'df_http' tag. Failures during the logging process itself are
  /// caught and printed to the [Logger] to prevent the app from crashing
  /// while trying to report an error.
  ///
  /// Parameters:
  /// - [exception]: The error object encountered during the API call.
  /// - [stack]: The stack trace associated with the error for easier debugging.
  Future<void> tryRecordException({
    required Exception exception,
    StackTrace? stack,
  }) async {
    if (onErrorRecorded != null) {
      await onErrorRecorded!(exception, stack);
    } else {
      try {
        await FirebaseCrashlytics.instance.recordError(
          exception,
          stack,
          reason: 'a non-fatal error',
          information: ['df_http'],
        );
      } catch (e) {
        Logger.log(
          "Failed logging to firebase crashlytics: $e",
          type: LogType.warning,
        );
      }
    }
  }
}
