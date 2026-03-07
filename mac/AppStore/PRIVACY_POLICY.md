# Planner Privacy Policy

Effective date: March 7, 2026

Planner respects your privacy. This Privacy Policy explains what information the iOS app collects, how it is used, where it is stored, and what choices you have.

## 1. Information Planner Accesses

If you choose to sign in with Google, Planner requests access to:

- Your basic Google account identity through the `openid`, `profile`, and `email` scopes
- Your Google Calendar data through the `https://www.googleapis.com/auth/calendar.readonly` scope

Planner uses this information only to sign you in, show your account information in the app, and display your calendar events.

## 2. How Your Information Is Used

Planner uses your information to:

- authenticate your Google account
- load and refresh your calendar events
- show your profile name, email address, and profile picture in the app
- cache the most recently loaded events for offline viewing
- remember the last successful calendar refresh state

Planner is a read-only calendar client. It does not create, edit, or delete events in your Google Calendar.

## 3. Where Data Is Stored

Planner stores limited information on your device:

- Google authentication session data is stored in the iOS Keychain
- Your profile information, cached calendar events, and last refresh timestamp are stored locally in `UserDefaults`

This local storage is used to keep you signed in and to support offline viewing of previously loaded events.

## 4. Data Sharing

Planner does not operate its own backend for the iOS app and does not send your calendar data to developer-owned servers.

Your information is exchanged directly with Google services as part of sign-in and calendar loading, including:

- `accounts.google.com`
- `oauth2.googleapis.com`
- `openidconnect.googleapis.com`
- `www.googleapis.com`

Those services are governed by Google's own privacy policies and terms.

## 5. Analytics, Ads, and Tracking

Planner does not include third-party advertising SDKs.

Planner does not use in-app analytics, behavioral tracking, or profiling for advertising purposes.

## 6. Your Choices

You can:

- sign out of Planner at any time
- revoke Planner's Google access from your Google account settings
- delete the app to remove locally stored app data from your device

When you sign out, Planner clears locally stored profile data, cached events, refresh metadata, and the saved Google session from the device.

## 7. Children's Privacy

Planner is not directed to children under 13, and the app is not intended to knowingly collect personal information from children.

## 8. Changes to This Policy

This Privacy Policy may be updated in the future. If material changes are made, the updated policy will be published with a new effective date.

## 9. Contact

If you have questions about this Privacy Policy or your data, contact:

`main@ivan-b.com`
