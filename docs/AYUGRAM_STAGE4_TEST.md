# AyuGram iOS Stage 4 device check

Install the newly signed IPA over the current AyuGram build. Keep one other Telegram account available for delete and edit tests.

1. Open **Settings → AyuGram → Sources, exceptions and notifications**. Check the four chat categories, each content type, retention, storage limit and notification category controls.
2. Add one chat to **Always preserve** and another to **Never preserve**. Long-press a message in either chat and verify the AyuGram rule action cycles through always, never and common settings.
3. Delete received text and media in private chats, groups and channels. Only enabled categories and content types must remain. A deleted cached attachment must appear in the AyuGram Vault.
4. Delete a message while AyuGram is open. The bulletin must identify the chat and include the message preview unless **Hide notification text** is enabled. Several quick deletions must be combined.
5. Enable **System notifications**, grant iOS permission, leave AyuGram in the background and delete a message. The local notification should use the chat name and follow category/privacy settings while iOS still lets the sideloaded app process updates.
6. Force-quit AyuGram and delete a message. Without a valid Telegram push entitlement, the event may only be processed after the app is opened again; this is an iOS signing limitation rather than a notification UI failure.
7. In **AyuGram Vault**, cycle all filters, search by chat/text/file, preview and share media, share/copy an archive record, remove a single record and clear one chat.
8. Set a short retention or small media limit and confirm the oldest matching data is removed. Enable Face ID protection, close the vault and confirm authentication is required to reopen it.
9. Open a view-once photo or video. Automatic preservation must follow the chat rule; the explicit **Save to AyuGram** action must still work when the user requests it.

Do not publish a release until the installed build passes the applicable checks above.
