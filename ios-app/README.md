# Insulin Resistance iOS App

This is a SwiftUI prototype with local SwiftData persistence, Apple Health import hooks, local fallback insights, and a backend-backed LightGBM risk prediction flow.

Open this Xcode project:

```text
ios-app/InsulinResistanceApp.xcodeproj
```

Run the `InsulinResistanceApp` scheme on an iPhone simulator.

## Run With The Real Model API

Start the backend from the repository root before running the iOS app:

```bash
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Then run the app in Xcode. The Progress page shows whether the current estimate is coming from:

- `LightGBM model estimate`: real backend prediction
- `Local fallback estimate`: backend unavailable or required model inputs missing
- `Updating model estimate...`: request in progress

For simulator testing, `http://127.0.0.1:8000` points to the Mac running the backend. For testing on a physical iPhone, change the API base URL in `RiskPredictionAPI.swift` to the Mac's local network IP address and make sure the phone and Mac are on the same Wi-Fi network.

## Accounts And Cloud Sync

The welcome screen now supports real account registration and login against the backend API.

After signing in:

- Profile saves are synced to `PUT /me/profile`
- Check-ins are synced to `POST /me/checkins`
- Login loads saved cloud profile data and the latest check-in
- The auth token is stored locally in the iOS Keychain
- Profile includes sign out, privacy notice review, and account deletion

The backend development database is `backend/app.db`. This is the local stand-in for a cloud database while developing.

## Privacy And Safety

The welcome flow now requires the user to acknowledge a Privacy & Safety notice before logging in, creating an account, or continuing locally. The notice explains:

- The app is for screening and reflection only, not diagnosis or treatment.
- Profile, check-in, model input, and optional Apple Health data may be used for estimates and insights.
- Apple Health data is imported only after the user grants HealthKit permission.
- Backend/cloud sync is still a development prototype and should use HTTPS and managed infrastructure before deployment.

Implemented flows:

- Welcome
- Create profile
- Home
- Check-in method selection
- Manual daily check-in
- AI-style Cloudy check-in
- Completion
- Daily insights
- Weekly risk and trends
- Backend LightGBM risk prediction with local fallback
- Apple Health import sheet
- Account registration, login, and cloud sync
- Privacy & Safety acknowledgement
- Keychain-backed auth token storage
- Account deletion from Profile
