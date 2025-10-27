import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '/models/models.dart';
import '/utils/utils.dart';
import 'df_http_client_config.dart';

///An instance of this class is used to make all API
///calls with predefined logic
class DfApiClient {
  DfApiClient({required this.httpApiConfig});

  DfApiClient copyWith({DfHttpClientConfig? httpApiConfig}) {
    return DfApiClient(httpApiConfig: httpApiConfig ?? this.httpApiConfig);
  }

  final DfHttpClientConfig httpApiConfig;

  ///This flag is used to determine whether the application can proceed with API calls,
  /// or all API calls have to be paused until token refreshing is done
  static bool _refreshTokenInProgress = false;

  Future<Response?> get(String apiPath) async {
    Logger.log(
      "--------> START OF GET API CALL <--------",
      type: LogType.api,
      tag: "DF-API-CLIENT",
    );
    final client = http.Client();
    Uri apiUri = _generateApiUri(apiPath);
    return _processApiCall(
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

  Future<Response?> _processApiCall(
    int retryCount, {
    required Future<Response> Function() apiCall,
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

    if (httpApiConfig.refreshToken != null &&
        httpApiConfig.authorizationPresent() &&
        !_refreshTokenInProgress) {
      if (JwtDecoder.isExpired(httpApiConfig.getAuthorizationToken())) {
        _refreshTokenInProgress = true;

        var refreshTokenResult = await httpApiConfig.refreshToken!();

        switch (refreshTokenResult) {
          case Success(value: final _):
            Logger.log(
              "--------> REFRESHING TOKEN SUCCESS",
              type: LogType.success,
              tag: "DF-API-CLIENT",
            );
            _refreshTokenInProgress = false;
            break;
          case Failure(exception: final exception):
            _refreshTokenInProgress = false;
            Logger.log(
              "--------> REFRESHING TOKEN FAILED: $exception",
              type: LogType.error,
              tag: "DF-API-CLIENT",
            );
            break;
        }
      }
    }

    //Pausing API calls if the token is being refreshed, and if API call have
    //auth header
    while (_refreshTokenInProgress &&
        httpApiConfig.authorizationPresent() &&
        httpApiConfig.waitForTokenRefresh) {
      await Future.delayed(const Duration(milliseconds: 400), () {
        Logger.log(
          "--------> REFRESHING TOKEN",
          type: LogType.warning,
          tag: "DF-API-CLIENT",
        );
      });
    }

    try {
      res = await apiCall();
    } catch (e) {
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
      }

      Logger.log(
        '--------> $e \n API CALL EXCEPTION \n RESPONSE BODY= ${res?.body}',
        type: LogType.error,
        tag: "DF-API-CLIENT",
      );
      //Exception needs to be handled
    }

    if (res == null || res.statusCode == 502 || res.statusCode == 503) {
      //If API call failed, this will retry API request
      if (retryCount > 0) {
        Logger.log(
          '--------> RETRY API CALL AFTER $retryPauseDuration milliseconds - $retryCount RETRIES LEFT',
          type: LogType.warning,
          tag: "DF-API-CLIENT",
        );
        await Future<void>.delayed(Duration(milliseconds: retryPauseDuration));
        return _processApiCall(
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

  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
