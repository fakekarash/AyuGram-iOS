# AyuGram iOS — Stage 1 device checklist

This stage deliberately excludes Anti-Recall and edit history. Those features belong to the second device build.

## Identity and settings

- The Home Screen icon uses the AyuGram logo and the app name is `AyuGram`.
- Open **Settings → AyuGram**.
- Verify that the GitHub and Telegram channel links open correctly.
- Verify that every switch keeps its value after closing and reopening the app.

## Ghost Mode

Enable **Ghost Mode**, then test with a second Telegram account:

1. Open an unread direct message. It should remain unread for the sender.
2. Open a channel or forum topic. The remote read state should not advance.
3. Type without sending. The second account should not see a typing indicator.
4. View a story. The second account should not receive the story view.
5. Leave the app open for at least 30 seconds. The second account should not see the AyuGram account online.

Repeat each check after disabling its individual switch to verify the normal Telegram behavior returns.

## Protected and one-time media

1. In a channel with content protection enabled, long-press a photo or video and save it.
2. Open a view-once photo, video, voice message, and video message.
3. Reopen the same item. It should remain available locally.
4. In the Files app, open **On My iPhone → AyuGram → AyuGram Vault** and verify the copied media.
5. Disable **Local AyuGram Vault**, open another view-once item, and verify that no new file is added.

## Expected sideload limitations

- The re-signable package contains only the main application. Share, notification-service, widget, and watch extensions are removed.
- Push notifications and other restricted entitlements depend on the signing method and are not guaranteed.
- A free Apple Account normally requires signing again every seven days and is subject to Apple's active App ID limits.
