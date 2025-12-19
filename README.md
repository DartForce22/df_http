# df_http

A robust, production-ready HTTP client wrapper for Dart and Flutter. Built on top of the `http` package, `df_http` simplifies complex networking tasks like **automated token refreshing**, **exponential backoff retries**, and **connectivity-aware recovery**.

## 🚀 Features

- **Single-Flight Token Refresh**: Prevents "thundering herd" issues. If multiple requests trigger a token refresh simultaneously, only one refresh call is made while others wait securely via a `Completer` lock.
- **Exponential Backoff with Jitter**: Retry logic for gateway/server errors (502, 503, 504) to reduce server strain and increase success rates.
- **Decoupled Connectivity Logic**: Inject your own internet connection checks, making the client highly testable and adaptable to custom VPN or firewall environments.
- **Stream-Based Status**: Real-time broadcast stream (`onConnectivityChanged`) to notify your UI when the device goes offline or comes back online.
- **Firebase Crashlytics Integration**: Built-in non-fatal error reporting.
- **Test-First Design**: Fully injectable dependencies (`http.Client`, `Random`, `internetConnectionCheck`) for deterministic unit testing.

## Getting Started

### 1. Add Dependency

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  df_http: latest_version
```

### 2. Basic Configuration
Create a DfHttpClientConfig instance. This object holds all your API settings, retry logic, and authentication callbacks.

```dart
import 'package:df_http/df_http.dart';

final config = DfHttpClientConfig(
  baseApiUrl: 'https://api.example.com',
  timeout: 15, // seconds
  maxRetryAttempts: 3,
  headers: {
    'Accept': 'application/json',
  },
  // This is called automatically when a 401 is detected or token expires
  refreshToken: () async {
    final result = await myAuthService.refresh();
    return Success(result.accessToken);
  },
);
```

### 3. Initialize the Client
Pass the configuration to the DfApiClient. You can also inject a custom http.Client for testing.

```dart
final apiClient = DfApiClient(httpApiConfig: config);
```

### 4. Make Your First Call
Use the built-in HTTP methods. df_http handles JSON encoding and common error retries under the hood.

```dart
void fetchUserData() async {
  final response = await apiClient.get('/v1/profile');

  if (response?.statusCode == 200) {
    print('User Data: ${response?.body}');
  }
}
```

### 5. Listen for Connectivity Changes
If you want to update your UI when the connection drops or recovers, listen to the broadcast stream:

```dart
DfApiClient.onConnectivityChanged.listen((isConnected) {
  if (isConnected) {
    showSnackBar("Back Online!");
  } else {
    showSnackBar("Connection Lost. Retrying...");
  }
});
```

## Pro-Tip: Custom Internet Checks
By default, the package pings example.com. For custom environments (like internal corporate networks), provide your own check logic in the config:

```dart
internetConnectionCheck: () async {
  // Use your own heartbeat endpoint
  final res = await http.get(Uri.parse('https://my-status-page.com'));
  return res.statusCode == 200;
},
```
