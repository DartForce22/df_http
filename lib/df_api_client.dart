import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '/models/models.dart';
import '/utils/utils.dart';
import 'df_http_client_config.dart';

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
  DfApiClient({required this.httpApiConfig});

  /// Returns a copy of this client with updated configuration.
  ///
  /// Useful when only part of the configuration needs to be changed
  /// (e.g. headers, base URL, timeout).
  DfApiClient copyWith({DfHttpClientConfig? httpApiConfig}) {
    return DfApiClient(httpApiConfig: httpApiConfig ?? this.httpApiConfig);
  }

  /// HTTP configuration used for all API calls.
  final DfHttpClientConfig httpApiConfig;

  ///This flag is used to determine whether the application can proceed with API calls,
  /// or all API calls have to be paused until token refreshing is done
  static Completer<void>? _refreshCompleter;

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
    final client = http.Client();
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
            .get(apiUri, headers: httpApiConfig.headers)
            .timeout(
              Duration(seconds: httpApiConfig.timeout),
              onTimeout: () => throw Exception(
                "API Timeout exception, no response from the server for: $apiPath",
              ),
            );
      },
      onFinish: client.close,
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
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
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
      onFinish: client.close,
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
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }

    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
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
      onFinish: client.close,
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
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }

    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
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
      onFinish: client.close,
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
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
      apiPath: apiPath,
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
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
      onFinish: client.close,
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
    required VoidCallback onFinish,
  }) async {
    Logger.log(
      "--------> PROCESSING API CALL",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    Response? res;
    final retryPauseDuration =
        500 * ((httpApiConfig.maxRetryAttempts + 1) - retryCount);

    // Handle token refresh if authorization is present and token is expired
    if (httpApiConfig.refreshToken != null &&
        httpApiConfig.authorizationPresent() &&
        _refreshCompleter == null) {
      if (JwtDecoder.isExpired(httpApiConfig.getAuthorizationToken())) {
        _refreshCompleter = Completer();

        try {
          var refreshTokenResult = await httpApiConfig.refreshToken!();

          switch (refreshTokenResult) {
            case Success(value: final _):
              Logger.log(
                "--------> REFRESHING TOKEN SUCCESS",
                type: LogType.success,
                tag: "DF-API-CLIENT",
              );
              break;
            case Failure(exception: final exception):
              Logger.log(
                "--------> REFRESHING TOKEN FAILED: $exception",
                type: LogType.error,
                tag: "DF-API-CLIENT",
              );
              break;
          }
        } catch (e) {
          Logger.log("Token refresh crashed: $e", type: LogType.error);
        } finally {
          _refreshCompleter?.complete();
          _refreshCompleter = null;
        }
      }
    }

    if (httpApiConfig.authorizationPresent() &&
        httpApiConfig.waitForTokenRefresh) {
      Logger.log(
        "--------> REFRESHING TOKEN",
        type: LogType.warning,
        tag: "DF-API-CLIENT",
      );
      await _refreshCompleter?.future;
    }

    try {
      res = await apiCall();
    } catch (e, s) {
      if (e is SocketException) {
        //Checks if there is internet connection
        var connected = await hasInternetConnection();

        //Seconds to wait before checking internet connection again
        var secondsToWait = 5;

        while (!connected) {
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

        try {
          await FirebaseCrashlytics.instance.recordError(
            e,
            s,
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

      Logger.log(
        '--------> $e \n API CALL EXCEPTION \n RESPONSE BODY= ${res?.body}',
        type: LogType.error,
        tag: "DF-API-CLIENT",
      );
      //Exception needs to be handled
    }

    // Retry on gateway/server errors
    if (res == null || res.statusCode == 502 || res.statusCode == 503) {
      //If API call failed, this will retry API request
      if (retryCount > 0) {
        Logger.log(
          '--------> RETRY API CALL AFTER $retryPauseDuration milliseconds - $retryCount RETRIES LEFT',
          type: LogType.warning,
          tag: "DF-API-CLIENT",
        );
        try {
          await FirebaseCrashlytics.instance.recordError(
            '--------> RETRY API PATH=($apiPath) CALL AFTER $retryPauseDuration milliseconds - $retryCount RETRIES LEFT',
            null,
            reason: 'a non-fatal error',
            information: ['df_http'],
          );
        } catch (e) {
          Logger.log(
            "Failed logging to firebase crashlytics: $e",
            type: LogType.warning,
          );
        }
        await Future<void>.delayed(Duration(milliseconds: retryPauseDuration));
        return _processApiCall(
          apiPath: apiPath,
          --retryCount,
          apiCall: apiCall,
          onFinish: onFinish,
        );
      }
    }
    onFinish();
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
}
