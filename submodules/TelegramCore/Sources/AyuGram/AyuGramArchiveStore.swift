import Foundation
import Postbox

public struct AyuGramArchiveRecord: Codable, Equatable {
    public let id: String
    public let peerId: Int64
    public let messageId: Int32
    public let authorId: Int64?
    public let messageTimestamp: Int32
    public let text: String
    public let previousTexts: [String]
    public let editTimestamps: [Int32]
    public let isDeleted: Bool
    public let deletionTimestamp: Int32
}

public enum AyuGramArchiveStore {
    private static let queue = DispatchQueue(label: "org.ayugram.ios.archive")

    public static var rootURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("AyuGram Archive", isDirectory: true)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    private static func recordId(message: Message) -> String {
        return "\(message.id.peerId.toInt64())_\(message.id.namespace)_\(message.id.id)"
    }

    private static func url(id: String) -> URL {
        return self.rootURL.appendingPathComponent(id + ".json", isDirectory: false)
    }

    private static func read(id: String) -> AyuGramArchiveRecord? {
        guard let data = try? Data(contentsOf: self.url(id: id)) else {
            return nil
        }
        return try? JSONDecoder().decode(AyuGramArchiveRecord.self, from: data)
    }

    private static func write(_ record: AyuGramArchiveRecord) {
        do {
            try self.ensureDirectory()
            let data = try JSONEncoder().encode(record)
            try data.write(to: self.url(id: record.id), options: .atomic)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .ayuGramArchiveChanged, object: nil)
            }
        } catch {
        }
    }

    public static func recordDeleted(message: Message, history: AyuGramMessageHistoryAttribute) {
        self.queue.async {
            let id = self.recordId(message: message)
            let existing = self.read(id: id)
            self.write(AyuGramArchiveRecord(
                id: id,
                peerId: message.id.peerId.toInt64(),
                messageId: message.id.id,
                authorId: message.author?.id.toInt64(),
                messageTimestamp: message.timestamp,
                text: message.text,
                previousTexts: history.previousTexts.isEmpty ? (existing?.previousTexts ?? []) : history.previousTexts,
                editTimestamps: history.editTimestamps.isEmpty ? (existing?.editTimestamps ?? []) : history.editTimestamps,
                isDeleted: true,
                deletionTimestamp: history.deletionTimestamp
            ))
        }
    }

    public static func recordEdited(
        message: Message,
        currentText: String,
        previousTexts: [String],
        editTimestamps: [Int32]
    ) {
        self.queue.async {
            let id = self.recordId(message: message)
            let existing = self.read(id: id)
            self.write(AyuGramArchiveRecord(
                id: id,
                peerId: message.id.peerId.toInt64(),
                messageId: message.id.id,
                authorId: message.author?.id.toInt64(),
                messageTimestamp: message.timestamp,
                text: currentText,
                previousTexts: previousTexts,
                editTimestamps: editTimestamps,
                isDeleted: existing?.isDeleted ?? false,
                deletionTimestamp: existing?.deletionTimestamp ?? 0
            ))
        }
    }

    public static func records() -> [AyuGramArchiveRecord] {
        return self.queue.sync {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: self.rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            return urls.compactMap { url -> AyuGramArchiveRecord? in
                guard url.pathExtension.lowercased() == "json",
                      let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return try? JSONDecoder().decode(AyuGramArchiveRecord.self, from: data)
            }.sorted { lhs, rhs in
                let lhsTimestamp = lhs.isDeleted ? lhs.deletionTimestamp : (lhs.editTimestamps.last ?? lhs.messageTimestamp)
                let rhsTimestamp = rhs.isDeleted ? rhs.deletionTimestamp : (rhs.editTimestamps.last ?? rhs.messageTimestamp)
                return lhsTimestamp > rhsTimestamp
            }
        }
    }

    public static func remove(_ record: AyuGramArchiveRecord) {
        self.queue.sync {
            try? FileManager.default.removeItem(at: self.url(id: record.id))
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ayuGramArchiveChanged, object: nil)
        }
    }

    public static func removeAll() {
        self.queue.sync {
            try? FileManager.default.removeItem(at: self.rootURL)
            try? self.ensureDirectory()
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ayuGramArchiveChanged, object: nil)
        }
    }
}
