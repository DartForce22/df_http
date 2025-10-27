import 'dart:developer' as developer;

enum LogType { info, warning, error, success, debug, api }

enum ApiLogType { request, response, error }

class Logger {
  static void log(
    String message, {
    String? additionalMessage,
    String? tag,
    LogType type = LogType.info,
    StackTrace? stackTrace, // Added the stackTrace parameter
  }) {
    final timestamp = DateTime.now().toIso8601String();
    String emoji;
    String colorCode;

    switch (type) {
      case LogType.info:
        emoji = 'ℹ️';
        colorCode = '\x1B[34m'; // Blue
        break;
      case LogType.warning:
        emoji = '⚠️';
        colorCode = '\x1B[33m'; // Yellow
        break;
      case LogType.error:
        emoji = '❌';
        colorCode = '\x1B[31m'; // Red
        break;
      case LogType.success:
        emoji = '✅';
        colorCode = '\x1B[32m'; // Green
        break;
      case LogType.debug:
        emoji = '🐞';
        colorCode = '\x1B[35m'; // Purple
        break;
      case LogType.api:
        emoji = '👻';
        colorCode = '\x1B[35m'; // Purple
        break;
    }

    String messageTag = tag != null
        ? ' ${type.name}-$tag: '
        : ' ${type.name} :';

    // Building the log message
    final baseMessage =
        '$colorCode[$timestamp] $emoji $messageTag $message${additionalMessage != null ? "\n$additionalMessage" : ""}';

    // Check if we have a stackTrace and append it to the message
    final logMessage = stackTrace != null
        ? '$baseMessage\nStackTrace: $stackTrace'
        : baseMessage;

    // Print the styled message
    developer.log(logMessage, name: type.name);
  }

  static void logApi({
    required ApiLogType type,
    required String apiPath,
    required String method, // Added API method (GET, POST, etc.)
    int? statusCode,
    String? requestBody,
    String? responseBody,
    Map<String, String>? headers,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    String emoji;
    String colorCode;

    switch (type) {
      case ApiLogType.request:
        emoji = '📤'; // Outgoing request
        colorCode = '\x1B[36m'; // Cyan
        break;
      case ApiLogType.response:
        emoji = '📥'; // Incoming response
        colorCode = '\x1B[32m'; // Green
        break;
      case ApiLogType.error:
        emoji = '❌';
        colorCode = '\x1B[31m'; // Red
        break;
    }

    final baseMessage =
        '''
$colorCode[$timestamp] $emoji API ${type.name.toUpperCase()}
🔗 Path: $apiPath
🔄 Method: $method
${statusCode != null ? '📟 Status Code: $statusCode' : ''}
${headers != null ? '📑 Headers: ${headers.toString()}' : ''}
${requestBody != null ? '📦 Request Body: $requestBody' : ''}
${responseBody != null ? '📨 Response Body: $responseBody' : ''}''';

    final logMessage = stackTrace != null
        ? '$baseMessage\nStackTrace: $stackTrace'
        : baseMessage;

    developer.log(logMessage, name: 'API-${type.name}');
  }
}
