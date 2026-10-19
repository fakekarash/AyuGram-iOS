# AyuGram iOS Stage 3 device check

Install the newly signed IPA over the current AyuGram build, then check these items before publishing a release.

1. In **Settings → AyuGram**, confirm that Anti-Recall, deletion notices, deleted-message visibility, view-once preservation and the local vault controls are present.
2. Delete a received text message from another account while the chat is open. The original text must remain, the bubble must become semi-transparent, and its status must show `🛡 AyuGram: удалено` without changing the message body.
3. Delete several received messages together. A grouped AyuGram bulletin must appear inside the app.
4. Enable **System notifications**, grant permission, put AyuGram in the background, and delete a message from another account. A local notification can appear only while iOS still lets the app process the Telegram update.
5. Edit a received message two or more times. Long-press still shows the edit history; **Settings → AyuGram → Open storage** must also contain a persistent history entry.
6. Open a view-once photo or video and press **Save to AyuGram**. Confirm the success message, then open the storage screen and preview or share the file.
7. In the storage screen, open a deleted-message entry, copy its text, delete a single entry, then test **Clear storage**.
8. Force-quit AyuGram and delete a message from another account. Record the result separately: without a working Telegram push entitlement, a sideloaded build may receive the deletion only after it is opened again.

Do not publish a release until the installed build passes the applicable checks above.
