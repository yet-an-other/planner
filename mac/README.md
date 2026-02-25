# Planner iOS (SwiftUI)

This folder contains a native iOS SwiftUI app mirroring the web planner's core behavior:
- Google sign-in / sign-out
- Year calendar grid (Mon-Sun)
- Multi-day bar events and short timed events
- Event details sheet
- Year navigation

## Setup

1. Open `mac/Planner.xcodeproj` in Xcode.
2. In `Planner/Info.plist`, set:
- `GOOGLE_CLIENT_ID` to an iOS OAuth client ID
- `GOOGLE_OAUTH_REDIRECT_URI` to your custom redirect URI (for example `plannerios:/oauth2redirect`)
- `GOOGLE_CALENDAR_ID` (or keep `primary`)
3. In your Google Cloud OAuth client, add the same custom URL scheme/redirect and scopes used by the app.
4. Ensure `CFBundleURLTypes` in `Info.plist` includes the URL scheme used by `GOOGLE_OAUTH_REDIRECT_URI`.

## Notes

- This project is intentionally standalone under `mac/`.
- The OAuth flow uses `ASWebAuthenticationSession` with PKCE.
