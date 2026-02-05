## 2.0.1
- Added missing multipart requests method
## 2.0.0
- Fixed Firebase Crashlytics API path logging
- Resolved issues with concurrent refresh token calls
- Replaced linear retry pause with exponential backoff + jitter
- Improved overall package testability
- Added code documentation for the `DfApiClient` class
- Exposed `internetConnectionCheck` to allow custom internet check logic
- Added `onConnectivityChanged` for UI network state updates
- Fixed reported bugs

### 🌐 New Features
- Added `onConnectivityChanged` stream to notify the UI about network changes
- Added `dispose()` method for proper resource cleanup

## 1.0.1

- API Exceptions logged to the firebase crashlytics if initialized

## 1.0.0

- Added API call logs for easier tracking

## 0.0.1

- Created first version
