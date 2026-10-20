import Foundation
import Postbox

public final class AyuGramMessageHistoryAttribute: MessageAttribute {
    public let previousTexts: [String]
    public let editTimestamps: [Int32]
    public let isDeleted: Bool
    public let deletionTimestamp: Int32

    public init(previousTexts: [String], editTimestamps: [Int32], isDeleted: Bool, deletionTimestamp: Int32) {
        self.previousTexts = previousTexts
        self.editTimestamps = editTimestamps
        self.isDeleted = isDeleted
        self.deletionTimestamp = deletionTimestamp
    }

    required public init(decoder: PostboxDecoder) {
        self.previousTexts = decoder.decodeStringArrayForKey("t")
        self.editTimestamps = decoder.decodeInt32ArrayForKey("d")
        self.isDeleted = decoder.decodeBoolForKey("x", orElse: false)
        self.deletionTimestamp = decoder.decodeInt32ForKey("xd", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.previousTexts, forKey: "t")
        encoder.encodeInt32Array(self.editTimestamps, forKey: "d")
        encoder.encodeBool(self.isDeleted, forKey: "x")
        encoder.encodeInt32(self.deletionTimestamp, forKey: "xd")
    }
}

public extension Message {
    var ayuGramHistoryAttribute: AyuGramMessageHistoryAttribute? {
        return self.attributes.first(where: { $0 is AyuGramMessageHistoryAttribute }) as? AyuGramMessageHistoryAttribute
    }
}

private func ayuGramUnixTimestamp() -> Int32 {
    return Int32(clamping: Int64(Date().timeIntervalSince1970))
}

private func ayuGramStoreMessage(from message: Message, text: String, attributes: [MessageAttribute]) -> StoreMessage {
    return StoreMessage(
        id: message.id,
        customStableId: nil,
        globallyUniqueId: message.globallyUniqueId,
        groupingKey: message.groupingKey,
        threadId: message.threadId,
        timestamp: message.timestamp,
        flags: StoreMessageFlags(message.flags),
        tags: message.tags,
        globalTags: message.globalTags,
        localTags: message.localTags,
        forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init),
        authorId: message.author?.id,
        text: text,
        attributes: attributes,
        media: ayuGramAllowedDeletedMedia(message)
    )
}

private func ayuGramAllowedDeletedMedia(_ message: Message) -> [Media] {
    return message.media.filter { media in
        if media is TelegramMediaImage {
            return AyuGramSettings.saveDeletedPhotos
        } else if let file = media as? TelegramMediaFile {
            if file.isVoice {
                return AyuGramSettings.saveDeletedVoice
            } else if file.isVideo || file.isInstantVideo {
                return AyuGramSettings.saveDeletedVideos
            } else if file.isSticker || file.isAnimated || file.isAnimatedSticker {
                return AyuGramSettings.saveDeletedStickers
            } else {
                return AyuGramSettings.saveDeletedFiles
            }
        }
        return AyuGramSettings.saveDeletedText
    }
}

public func ayuGramShouldPreserveDeletedMessage(_ message: Message) -> Bool {
    guard AyuGramSettings.antiRecallEnabled, AyuGramSettings.shouldPreserve(message: message) else {
        return false
    }
    return AyuGramSettings.saveDeletedText || !ayuGramAllowedDeletedMedia(message).isEmpty
}

public func ayuGramMessagePreservingEditHistory(previous: Message, updated: StoreMessage) -> StoreMessage {
    guard AyuGramSettings.editHistoryEnabled, AyuGramSettings.shouldPreserve(message: previous) else {
        return updated
    }
    let existing = previous.ayuGramHistoryAttribute
    var previousTexts = existing?.previousTexts ?? []
    var editTimestamps = existing?.editTimestamps ?? []

    if previous.text != updated.text {
        if previousTexts.last != previous.text {
            previousTexts.append(previous.text)
            let editTimestamp = (updated.attributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute)?.date ?? ayuGramUnixTimestamp()
            editTimestamps.append(editTimestamp)
        }
        let maximumCount = 20
        if previousTexts.count > maximumCount {
            previousTexts.removeFirst(previousTexts.count - maximumCount)
        }
        if editTimestamps.count > maximumCount {
            editTimestamps.removeFirst(editTimestamps.count - maximumCount)
        }
    }

    guard existing != nil || !previousTexts.isEmpty else {
        return updated
    }

    let history = AyuGramMessageHistoryAttribute(
        previousTexts: previousTexts,
        editTimestamps: editTimestamps,
        isDeleted: existing?.isDeleted ?? false,
        deletionTimestamp: existing?.deletionTimestamp ?? 0
    )
    var attributes = updated.attributes.filter { !($0 is AyuGramMessageHistoryAttribute) }
    attributes.append(history)
    AyuGramArchiveStore.recordEdited(
        message: previous,
        currentText: updated.text,
        previousTexts: previousTexts,
        editTimestamps: editTimestamps
    )
    return updated.withUpdatedAttributes(attributes)
}

public func ayuGramMessageMarkedDeleted(_ message: Message, mediaBox: MediaBox? = nil) -> StoreMessage {
    let existing = message.ayuGramHistoryAttribute
    if existing?.isDeleted == true {
        return ayuGramStoreMessage(from: message, text: message.text, attributes: message.attributes)
    }

    var attributes = message.attributes.filter { !($0 is AyuGramMessageHistoryAttribute) }
    let history = AyuGramMessageHistoryAttribute(
        previousTexts: existing?.previousTexts ?? [],
        editTimestamps: existing?.editTimestamps ?? [],
        isDeleted: true,
        deletionTimestamp: ayuGramUnixTimestamp()
    )
    attributes.append(history)

    AyuGramArchiveStore.recordDeleted(message: message, history: history)
    if let mediaBox {
        AyuGramVaultStore.saveDeletedMediaIfAvailable(message: message, mediaBox: mediaBox)
    }

    let category = AyuGramSettings.category(message: message)
    let peerTitle = message.peers[message.id.peerId]?.debugDisplayTitle ?? "Чат"
    let authorTitle = message.author?.debugDisplayTitle ?? ""
    let preview = AyuGramSettings.saveDeletedText ? String(message.text.prefix(240)) : ""

    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: .ayuGramMessageDeleted,
            object: nil,
            userInfo: [
                "peerId": message.id.peerId.toInt64(),
                "messageId": message.id.id,
                "peerTitle": peerTitle,
                "authorTitle": authorTitle,
                "preview": preview,
                "category": category.rawValue,
                "hasMedia": !message.media.isEmpty
            ]
        )
    }

    return ayuGramStoreMessage(from: message, text: AyuGramSettings.saveDeletedText ? message.text : "", attributes: attributes)
}
