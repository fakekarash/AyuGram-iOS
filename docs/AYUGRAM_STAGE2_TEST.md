# AyuGram iOS Stage 2 device test

Stage 2 adds Anti-Recall and local edit history on top of the verified Stage 1 build.

## Anti-Recall

1. Open **Settings → AyuGram** and keep **Сохранять удалённые сообщения** enabled.
2. Receive a text message in a private chat, group and channel, then delete it for everyone from another client.
3. Confirm the message remains and contains the `AyuGram: удалено отправителем` marker.
4. Force-close AyuGram after receiving another message, delete it from another client, reopen AyuGram and confirm it remains.
5. Confirm a message deleted before this iPhone ever received it is not claimed as recoverable.

## Edit history

1. Receive a text message and edit it twice from another client.
2. Long-press the message and open **AyuGram: история изменений**.
3. Confirm both previous versions and the current version are shown.
4. Restart AyuGram and confirm the history is still available.
5. Disable **История редактирования**, perform another edit and confirm no new revision is appended.

## Media

1. Download a photo or file before deleting it from another client.
2. Confirm the retained message still references the downloaded media.
3. Repeat with media that was never downloaded and record the expected server-unavailable behavior.

The GitHub Actions build validates compilation and IPA packaging. These behavior checks require a re-signed installation on a real iPhone.
