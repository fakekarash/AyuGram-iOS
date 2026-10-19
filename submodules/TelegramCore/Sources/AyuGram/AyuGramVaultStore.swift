import Foundation
import Postbox

public enum AyuGramVaultKind: String, Codable {
    case viewOnce
    case deletedMedia

    public var title: String {
        switch self {
        case .viewOnce:
            return "Одноразовое медиа"
        case .deletedMedia:
            return "Удалённое вложение"
        }
    }
}

public struct AyuGramVaultItem: Codable, Equatable {
    public let id: String
    public let peerId: Int64
    public let messageId: Int32
    public let timestamp: Int32
    public let kind: AyuGramVaultKind
    public let storedFilename: String
    public let originalFilename: String?

    public var fileURL: URL {
        return AyuGramVaultStore.rootURL.appendingPathComponent(self.storedFilename, isDirectory: false)
    }

    public var byteCount: Int64 {
        let values = try? self.fileURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}

public enum AyuGramVaultStore {
    private static let metadataSuffix = ".ayugram.json"
    private static let queue = DispatchQueue(label: "org.ayugram.ios.vault")

    public static var rootURL: URL {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("AyuGram Vault", isDirectory: true)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    private static func metadataURL(for item: AyuGramVaultItem) -> URL {
        return self.rootURL.appendingPathComponent(item.storedFilename + self.metadataSuffix, isDirectory: false)
    }

    @discardableResult
    public static func save(
        sourcePath: String,
        message: Message,
        fileExtension: String,
        originalFilename: String?,
        kind: AyuGramVaultKind
    ) throws -> AyuGramVaultItem {
        return try self.queue.sync {
            try self.ensureDirectory()

            let cleanExtension = fileExtension
                .lowercased()
                .filter { $0.isLetter || $0.isNumber }
            let resolvedExtension = cleanExtension.isEmpty ? "bin" : cleanExtension
            let peerId = message.id.peerId.toInt64()
            let id = "\(peerId)_\(message.id.namespace)_\(message.id.id)_\(kind.rawValue)"
            let storedFilename = "\(id).\(resolvedExtension)"
            let destination = self.rootURL.appendingPathComponent(storedFilename, isDirectory: false)
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: destination)

            let item = AyuGramVaultItem(
                id: id,
                peerId: peerId,
                messageId: message.id.id,
                timestamp: Int32(clamping: Int64(Date().timeIntervalSince1970)),
                kind: kind,
                storedFilename: storedFilename,
                originalFilename: originalFilename
            )
            let data = try JSONEncoder().encode(item)
            try data.write(to: self.metadataURL(for: item), options: .atomic)

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .ayuGramVaultChanged, object: nil)
            }
            return item
        }
    }

    public static func items() -> [AyuGramVaultItem] {
        return self.queue.sync {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: self.rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var result: [AyuGramVaultItem] = []
            var knownFiles = Set<String>()
            for url in urls where url.lastPathComponent.hasSuffix(self.metadataSuffix) {
                guard let data = try? Data(contentsOf: url), let item = try? JSONDecoder().decode(AyuGramVaultItem.self, from: data) else {
                    continue
                }
                guard FileManager.default.fileExists(atPath: item.fileURL.path) else {
                    try? FileManager.default.removeItem(at: url)
                    continue
                }
                result.append(item)
                knownFiles.insert(item.storedFilename)
            }

            for url in urls {
                let filename = url.lastPathComponent
                guard !filename.hasSuffix(self.metadataSuffix), !knownFiles.contains(filename) else {
                    continue
                }
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                guard values?.isRegularFile == true else {
                    continue
                }
                let timestamp = Int32(clamping: Int64((values?.contentModificationDate ?? Date()).timeIntervalSince1970))
                result.append(AyuGramVaultItem(
                    id: "legacy_\(filename)",
                    peerId: 0,
                    messageId: 0,
                    timestamp: timestamp,
                    kind: .viewOnce,
                    storedFilename: filename,
                    originalFilename: nil
                ))
            }

            return result.sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp > rhs.timestamp
                }
                return lhs.storedFilename < rhs.storedFilename
            }
        }
    }

    public static func remove(_ item: AyuGramVaultItem) {
        self.queue.sync {
            try? FileManager.default.removeItem(at: item.fileURL)
            try? FileManager.default.removeItem(at: self.metadataURL(for: item))
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ayuGramVaultChanged, object: nil)
        }
    }

    public static func removeAll() {
        self.queue.sync {
            try? FileManager.default.removeItem(at: self.rootURL)
            try? self.ensureDirectory()
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .ayuGramVaultChanged, object: nil)
        }
    }

    public static func totalByteCount() -> Int64 {
        return self.items().reduce(0) { partial, item in
            partial + item.byteCount
        }
    }
}
