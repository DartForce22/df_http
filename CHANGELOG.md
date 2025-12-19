## 0.0.1

- Created first version

## 1.0.0

- Added API call logs for easier tracking

## 1.0.1

- API Exceptions logged to the firebase crashlytics if initialized

## 2.0.0

- Fixed firebase crashlytics API path logging
- Added code docs for the df_api_client class
- Replaced linear pause with exponential backoff + jitter
- Added the dispose method
- Changed refresh token logic to fix concurrent calls issue
