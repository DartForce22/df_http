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
    final client = http.Client();
    return _processApiCall(
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
            .get(_generateApiUri(apiPath), headers: httpApiConfig.headers)
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
    Object? requestBody = body;
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }
    return _processApiCall(
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
            .post(
              _generateApiUri(apiPath),
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
    Object? requestBody = body;
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }
    return _processApiCall(
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
            .patch(
              _generateApiUri(apiPath),
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
    Object? requestBody = body;
    final client = http.Client();

    if (jsonEncodeBody && body != null) {
      requestBody = jsonEncode(body);
    }

    return _processApiCall(
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
            .put(
              _generateApiUri(apiPath),
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
    return _processApiCall(
      httpApiConfig.maxRetryAttempts,
      apiCall: () async {
        return await client
            .delete(
              _generateApiUri(apiPath),
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
              "Refreshing token success",
              tag: 'processApiCall',
              type: LogType.error,
            );
            _refreshTokenInProgress = false;
            break;
          case Failure(exception: final exception):
            _refreshTokenInProgress = false;
            Logger.log(
              "Refreshing token failed: $exception",
              tag: 'processApiCall',
              type: LogType.error,
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
        Logger.log("Waiting for token to refresh");
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
            'Checking internet connection',
            tag: "processApiCall-apiResponse",
            type: LogType.debug,
          );
        }
      }

      Logger.log(
        '$e \nRequest url= ${res?.request?.url}\nResponse body= ${res?.body}',
        tag: "processApiCall-apiResponse",
        type: LogType.error,
      );
      //Exception needs to be handled
    }

    if (res == null || res.statusCode == 502 || res.statusCode == 503) {
      //If API call failed, this will retry API request
      if (retryCount > 0) {
        await Future<void>.delayed(Duration(milliseconds: retryPauseDuration));
        return _processApiCall(
          --retryCount,
          apiCall: apiCall,
          onFinish: onFinish,
        );
      }
    }
    onFinish();
    return res;
  }

  Uri _generateApiUri(String apiPath) {
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
