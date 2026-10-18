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
        media: message.media
    )
}

public func ayuGramMessagePreservingEditHistory(previous: Message, updated: StoreMessage) -> StoreMessage {
    let existing = previous.ayuGramHistoryAttribute
    var previousTexts = existing?.previousTexts ?? []
    var editTimestamps = existing?.editTimestamps ?? []

    if AyuGramSettings.editHistoryEnabled && previous.text != updated.text {
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

    var attributes = updated.attributes.filter { !($0 is AyuGramMessageHistoryAttribute) }
    attributes.append(AyuGramMessageHistoryAttribute(
        previousTexts: previousTexts,
        editTimestamps: editTimestamps,
        isDeleted: existing?.isDeleted ?? false,
        deletionTimestamp: existing?.deletionTimestamp ?? 0
    ))
    return updated.withUpdatedAttributes(attributes)
}

public func ayuGramMessageMarkedDeleted(_ message: Message) -> StoreMessage {
    let existing = message.ayuGramHistoryAttribute
    if existing?.isDeleted == true {
        return ayuGramStoreMessage(from: message, text: message.text, attributes: message.attributes)
    }

    var attributes = message.attributes.filter { !($0 is AyuGramMessageHistoryAttribute) }
    attributes.append(AyuGramMessageHistoryAttribute(
        previousTexts: existing?.previousTexts ?? [],
        editTimestamps: existing?.editTimestamps ?? [],
        isDeleted: true,
        deletionTimestamp: ayuGramUnixTimestamp()
    ))

    var text = message.text
    if AyuGramSettings.showDeletedMessageMarker {
        let marker = "🛡 AyuGram: удалено отправителем"
        if text.isEmpty {
            text = marker
        } else if !text.contains(marker) {
            text += "\n\n" + marker
        }
    }
    return ayuGramStoreMessage(from: message, text: text, attributes: attributes)
}
