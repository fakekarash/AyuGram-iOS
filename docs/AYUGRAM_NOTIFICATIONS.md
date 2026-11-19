# AyuGram iOS: notifications

## Why push notifications never arrived

A sideloaded AyuGram build cannot receive Telegram's push notifications. This is
not a bug in the app; it is how APNs and the Telegram backend are wired.

Two independent blockers:

1. **No `aps-environment` in the effective signature.** The IPA ships with the
   upstream *fake* profile and a stale signature made for
   `C67CF9S4VU.ph.telegra.Telegraph`. When AltStore, SideStore or Sideloadly
   re-signs the app, the entitlements come from *your* provisioning profile. A
   free Apple account cannot enable the Push Notifications capability, so iOS
   never returns a device token and `account.registerDevice` is never called.
   The only trace is a log line from `didFailToRegisterForRemoteNotifications`.

2. **The APNs topic is Telegram's, not ours.** APNs requires `apns-topic` to be
   the receiving app's bundle ID, and the sender chooses it.
   `account.registerDevice` has no topic parameter. Telegram's push service
   sends with the certificate configured for the API application
   (`api_id`), which for the official app is `ph.telegra.Telegraph`. A token
   minted for `com.fakekarash.ayugram` is rejected with
   `DeviceTokenNotForTopic`. No client change can override that.

Missing extensions only degrade content (a push without the Notification
Service extension shows the generic "You have a new message").

## What the app does instead

Everything is generated on the device from messages the app has already
processed:

| Piece | File | Behaviour |
| --- | --- | --- |
| Local notification on arrival | `submodules/TelegramUI/Sources/AyuGramLocalNotifications.swift`, hooked in `ApplicationContext.swift` | When a message arrives while the app is not in the foreground, a `UNNotification` is posted with the chat, author and text |
| Background keep-alive (opt-in) | `SharedWakeupManager.swift`, `AyuGramSettings.backgroundKeepAliveEnabled` | Holds a silent `.ambient` audio session so iOS does not suspend the process; messages are noticed within seconds |
| Best-effort wake-up | `AyuGramLocalNotifications.registerBackgroundRefresh()` | A `BGAppRefreshTask` using the `.refresh` identifier the app plist already declares; iOS decides whether it runs (minutes to hours) |

Settings live in **AyuGram → Шпион → УВЕДОМЛЕНИЯ**: local notifications,
background keep-alive and a test button.

Behaviour:

- App open: nothing is notified (you see the message anyway).
- App backgrounded with keep-alive on: notification within seconds.
- App backgrounded with keep-alive off: notification only while the process
  still gets background time, then nothing until the next launch or refresh.
- App force-quit: no notifications; iOS does not launch killed apps.
- Muted chats, disabled categories and "hide notification content" are honoured.

Cost of keep-alive: an active audio session. Expect noticeable battery use;
it is off by default on purpose.

## How to get real APNs push (optional, paid setup)

This is the only way to receive notifications while the app is suspended or
closed. It requires a paid Apple Developer account and your own Telegram API
application. You already build with your own `TELEGRAM_API_ID`/`HASH`, which is
a prerequisite; the public Telegram API ID cannot be used for this.

1. Apple Developer Program, then **Identifiers → App IDs → +**: explicit App ID
   `com.fakekarash.ayugram` with **Push Notifications** enabled. Wildcard App IDs
   cannot use push.
2. Create an APNs certificate for that App ID (use "Sandbox & Production" for an
   ad-hoc build, "Sandbox" for a development build). Export the certificate and
   key as `.p12`, then:

   ```bash
   openssl pkcs12 -in apns.p12 -out apns.pem -nodes -clcerts
   ```

3. Upload `apns.pem` at `https://my.telegram.org/apps/apns_cert` for the API
   application that matches the `api_id` baked into the build.
4. Sign the IPA with a provisioning profile that carries Push Notifications, and
   make sure the signed entitlements really contain `aps-environment`:

   ```bash
   security cms -D -i profile.mobileprovision > profile.plist
   /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' profile.plist > app.entitlements
   codesign -f -s "Apple Development: …" --entitlements app.entitlements Payload/Telegram.app
   codesign -d --entitlements :- Payload/Telegram.app
   ```

   AltStore/SideStore cannot be relied on here: their signing library does not
   model the push entitlement. Sideloadly supports custom entitlements on a paid
   account; manual `codesign` plus `xcrun devicectl device install` is the
   dependable path.
5. Match the APNs environment. The app sends `app_sandbox` from `#if DEBUG`
   (`SharedAccountContext.updateNotificationTokensRegistration`): a release build
   reports production, a debug build sandbox. A sandbox token registered as
   production produces `BadDeviceToken`.
6. Without the Notification Service extension the banner is the generic
   "You have a new message". Proper content needs the extension plus an App
   Group, and reliably suppressing service pushes needs Apple's
   `com.apple.developer.usernotifications.filtering` entitlement (Apple approval).

Until that is done, the local notifications above are the honest best effort.

## What was verified

- The `aps-environment` string present inside the shipped binary belongs to the
  stale upstream signature for `ph.telegra.Telegraph`; it is not valid after
  re-signing.
- `Make.py` requires `aps-environment` in the supplied profiles, so the *build*
  has the entitlement; the *re-sign* is where it is lost.
- `account.registerDevice` (layer 225) has no bundle-ID/topic parameter.
- The main app previously contained no message-notification path at all: the
  notification pipeline only produced in-app banners while the app was active.
