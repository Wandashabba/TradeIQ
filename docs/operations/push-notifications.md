# Push notifications — switching them on (#67)

Push notifications are **built but off**. The backend, the Android build, the
iOS project and `flutter build web` all work with **no Firebase project**: the
server uses a no-op sender, and the app a no-op push client. Nothing is sent
until you complete the steps below. Nothing needs changing in code.

## What gets pushed

| Category (`/push/preferences`) | Event | Who receives it | Opens |
|---|---|---|---|
| `alerts` | A visit raises alerts (`alert.raised`) | Managers and admins of the tenant | `/alerts` |
| `tasks` | A task is assigned to someone other than its creator | The assignee | `/today` (agent), `/tasks` (manager) |
| `messages` | A direct message, a team (broadcast) message, or an announcement | The recipient, or everyone in the tenant except the sender | `/messages` |
| `sla` | An open task passes its SLA deadline (checked every 5 minutes; breaches older than 24h are not announced) | The task owner, plus managers and admins | `/today` (agent), `/tasks` (manager) |

Everyone can switch each category off from the bell icon: the agent app bar,
or the manager console's top bar. Pushes carry only what the recipient can
already see in the app: an outlet name, a task's required fix, or a message
they were sent.

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and click **Add project**.
2. Name it (for example `tradeiq-prod`). Google Analytics is not needed, so
   turn it off.
3. Once it is created, open **Project settings → General** and note the
   **Project ID**. Then open **Project settings → Cloud Messaging** and note the
   **Sender ID**. Check that **Firebase Cloud Messaging API (V1)** shows as
   *Enabled*. If it does not, click its menu and enable it in Google Cloud.

## 2. Add the apps

In **Project settings → General → Your apps**:

- **Android**: click the Android icon and enter the package name
  `com.tradeiq.tradeiq_app`. The nickname is optional, and the SHA-1 is not
  needed for messaging. Click **Register app**.
- **iOS**: click the Apple icon and enter the bundle ID
  `com.tradeiq.tradeiqApp`. Click **Register app**.
- **Web** (only for push in the manager console): click the `</>` icon, give it
  a nickname, and leave Hosting unticked.

Skip the "Add Firebase SDK" and "Add the Google Services plugin" steps the
wizard shows. This app is configured without them (see step 5).

## 3. Download the config files, and read the values out of them

The app does **not** use `google-services.json` or `GoogleService-Info.plist`
at build time, and they must not be committed. Download them anyway, because
they are the easiest place to copy the values from:

| Value | Android (`google-services.json`) | iOS (`GoogleService-Info.plist`) | Web (config snippet in the console) |
|---|---|---|---|
| `FIREBASE_API_KEY` | `client[].api_key[0].current_key` | `API_KEY` | `apiKey` |
| `FIREBASE_APP_ID` | `client[].client_info.mobilesdk_app_id` | `GOOGLE_APP_ID` | `appId` |
| `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` | `GCM_SENDER_ID` | `messagingSenderId` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` | `PROJECT_ID` | `projectId` |
| `FIREBASE_IOS_BUNDLE_ID` | — | `BUNDLE_ID` (optional) | — |
| `FIREBASE_VAPID_KEY` | — | — | **Cloud Messaging → Web Push certificates → Generate key pair**, the public key (web only, required) |

Keep them in one JSON file per platform, outside git. For example
`app/firebase.android.json`:

```json
{
  "FIREBASE_API_KEY": "AIza...",
  "FIREBASE_APP_ID": "1:1234567890:android:abc123",
  "FIREBASE_MESSAGING_SENDER_ID": "1234567890",
  "FIREBASE_PROJECT_ID": "tradeiq-prod"
}
```

These are client identifiers, not secrets: they ship inside every app binary.
Keeping them out of git just keeps environments from being mixed up.

## 4. Service account for the backend (`FIREBASE_SERVICE_ACCOUNT`)

1. **Project settings → Service accounts → Generate new private key**. This
   downloads a JSON file, which **is** a secret. Never commit it, and delete
   the download once step 3 below is done.
2. Base64-encode it on one line:

   ```sh
   base64 -i tradeiq-prod-firebase-adminsdk.json | tr -d '\n' > sa.b64
   ```

3. Set it on Fly and delete both local files:

   ```sh
   fly secrets set FIREBASE_SERVICE_ACCOUNT="$(cat sa.b64)" -a tradeiq-backend
   rm sa.b64 tradeiq-prod-firebase-adminsdk.json
   ```

`fly secrets set` restarts the machines. On boot the log shows
`[push] FCM enabled for Firebase project tradeiq-prod`. If the value is not
valid base64 of a service-account JSON, the log says `push stays off` instead,
and the API keeps working without push.

Optional: `SLA_BREACH_SWEEP_ENABLED=false` turns off the SLA-breach sweep
without turning off the other pushes.

## 5. Build flags (dart-defines)

Pass the values from step 3 to every build that should have push. With no
defines, the build is identical to today's: push is simply off.

```sh
cd app
# Android
flutter build apk --release \
  --dart-define=API_BASE_URL=https://tradeiq-backend.fly.dev \
  --dart-define-from-file=firebase.android.json
# iOS
flutter build ipa \
  --dart-define=API_BASE_URL=https://tradeiq-backend.fly.dev \
  --dart-define-from-file=firebase.ios.json
# Web (manager console)
flutter build web --release \
  --dart-define=API_BASE_URL=https://tradeiq-backend.fly.dev \
  --dart-define-from-file=firebase.web.json
```

`flutter run` takes the same flags.

**Do not add the Google Services Gradle plugin** (`com.google.gms.google-services`)
or the config files to the Android and iOS projects. Firebase is initialised
from the dart-defines with `FirebaseOptions`, which is what keeps unconfigured
builds green.

**Web only.** Firebase Messaging on the web needs a service worker. Create
`app/web/firebase-messaging-sw.js` with the web app's values (the same values
as `firebase.web.json`) before building:

```js
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey: '...', appId: '...', messagingSenderId: '...', projectId: '...',
});
firebase.messaging();
```

Without that file, web push fails quietly, with a console message and no
registration. Nothing else in the console is affected.

## 6. APNs key (iOS only)

iOS pushes go through Apple, so Firebase needs a key from Apple:

1. In <https://developer.apple.com/account/resources/authkeys/list>, create a
   key with **Apple Push Notifications service (APNs)** ticked. Download the
   `.p8` file (it can only be downloaded once) and note the **Key ID** and your
   **Team ID**.
2. In Firebase, go to **Project settings → Cloud Messaging → Apple app
   configuration → APNs Authentication Key → Upload**, and enter the `.p8`,
   Key ID and Team ID.
3. In Xcode (`app/ios/Runner.xcworkspace`), open **Runner → Signing &
   Capabilities** and add **Push Notifications**. Then add **Background Modes**
   and tick **Remote notifications**. Commit the resulting `Runner.entitlements`
   and `Info.plist` changes.
4. Firebase's iOS SDK needs iOS 15 or later. If `pod install` complains, set
   `platform :ios, '15.0'` in `app/ios/Podfile`.

## 7. Test it

1. **Backend is live**: check the boot log line from step 4.
2. **Device registers**: install a build with the dart-defines on a real phone
   (the Android emulator works with a Google Play image; the iOS simulator
   cannot receive APNs pushes). Sign in and allow notifications. Then check the
   table:

   ```sql
   SELECT platform, last_seen_at FROM device_tokens ORDER BY last_seen_at DESC LIMIT 5;
   ```

3. **Delivery from Firebase alone**: go to **Firebase console → Messaging →
   New campaign → Notifications → Send test message**. Paste the token (from
   `device_tokens.token`) and send it. If this arrives, the device side is
   right.
4. **End to end**: with the phone signed in as a field agent and the app in
   the background, have a manager assign that agent a task (`POST /tasks` with
   `ownerId`) or send them a message. The push should arrive within seconds.
   Tapping it opens `/today` or `/messages`.
5. **Preferences**: switch *Tasks assigned to you* off from the bell icon,
   assign another task, and confirm nothing arrives.
6. **Sign-out**: sign out and check that the row has left `device_tokens`.
7. **Stale tokens**: uninstall the app and trigger a push to that user. The
   next send deletes the token (FCM reports it unregistered).

## Where the code is

- Backend: `backend/src/modules/push/` (sender, service, routes, triggers, SLA
  sweep), and the `DeviceToken` and `NotificationPreference` models
  (migration `20260915152000_push_notifications`).
- App: `app/lib/core/push/` (config, client, registration) and
  `app/lib/features/notifications/` (the preferences screen).
- API: `/push/devices` and `/push/preferences` in `backend/openapi.yaml`.
