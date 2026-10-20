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
    public let peerTitle: String?
    public let authorTitle: String?

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
        kind: AyuGramVaultKind,
        uniqueSuffix: String? = nil
    ) throws -> AyuGramVaultItem {
        return try self.queue.sync {
            try self.ensureDirectory()

            let cleanExtension = fileExtension
                .lowercased()
                .filter { $0.isLetter || $0.isNumber }
            let resolvedExtension = cleanExtension.isEmpty ? "bin" : cleanExtension
            let peerId = message.id.peerId.toInt64()
            let suffix = uniqueSuffix.flatMap { value -> String? in
                let filtered = String(value.filter { $0.isLetter || $0.isNumber }.prefix(24))
                return filtered.isEmpty ? nil : filtered
            }
            let id = "\(peerId)_\(message.id.namespace)_\(message.id.id)_\(kind.rawValue)" + (suffix.map { "_" + $0 } ?? "")
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
                originalFilename: originalFilename,
                peerTitle: message.peers[message.id.peerId]?.debugDisplayTitle,
                authorTitle: message.author?.debugDisplayTitle
            )
            let data = try JSONEncoder().encode(item)
            try data.write(to: self.metadataURL(for: item), options: .atomic)

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .ayuGramVaultChanged, object: nil)
            }
            DispatchQueue.global(qos: .utility).async {
                self.performMaintenance()
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
                    originalFilename: nil,
                    peerTitle: nil,
                    authorTitle: nil
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

    public static func remove(peerId: Int64) {
        for item in self.items() where item.peerId == peerId {
            self.remove(item)
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

    public static func saveDeletedMediaIfAvailable(message: Message, mediaBox: MediaBox) {
        guard AyuGramSettings.vaultEnabled, AyuGramSettings.shouldPreserve(message: message) else {
            return
        }

        for media in message.media {
            if let image = media as? TelegramMediaImage, AyuGramSettings.saveDeletedPhotos, let representation = largestImageRepresentation(image.representations), let path = mediaBox.completedResourcePath(representation.resource) {
                let resourceId = representation.resource.id.stringRepresentation
                DispatchQueue.global(qos: .utility).async {
                    _ = try? self.save(sourcePath: path, message: message, fileExtension: "jpg", originalFilename: nil, kind: .deletedMedia, uniqueSuffix: resourceId)
                }
            } else if let file = media as? TelegramMediaFile {
                let allowed: Bool
                if file.isVoice {
                    allowed = AyuGramSettings.saveDeletedVoice
                } else if file.isVideo || file.isInstantVideo {
                    allowed = AyuGramSettings.saveDeletedVideos
                } else if file.isSticker || file.isAnimated || file.isAnimatedSticker {
                    allowed = AyuGramSettings.saveDeletedStickers
                } else {
                    allowed = AyuGramSettings.saveDeletedFiles
                }
                guard allowed, let path = mediaBox.completedResourcePath(file.resource) else {
                    continue
                }
                let ext: String
                if let filename = file.fileName, !URL(fileURLWithPath: filename).pathExtension.isEmpty {
                    ext = URL(fileURLWithPath: filename).pathExtension
                } else if file.isVoice {
                    ext = "ogg"
                } else if file.isVideo || file.isInstantVideo {
                    ext = "mp4"
                } else {
                    ext = "bin"
                }
                let resourceId = file.resource.id.stringRepresentation
                DispatchQueue.global(qos: .utility).async {
                    _ = try? self.save(sourcePath: path, message: message, fileExtension: ext, originalFilename: file.fileName, kind: .deletedMedia, uniqueSuffix: resourceId)
                }
            }
        }
    }

    public static func performMaintenance() {
        let retentionDays = AyuGramSettings.retentionDays
        let maximumBytes = Int64(AyuGramSettings.vaultLimitMB) * 1024 * 1024
        var items = self.items().sorted { $0.timestamp < $1.timestamp }
        if retentionDays > 0 {
            let cutoff = Int32(clamping: Int64(Date().timeIntervalSince1970) - Int64(retentionDays * 24 * 60 * 60))
            for item in items where item.timestamp < cutoff {
                self.remove(item)
            }
            items.removeAll { $0.timestamp < cutoff }
        }
        if maximumBytes > 0 {
            var total = items.reduce(Int64(0)) { $0 + $1.byteCount }
            for item in items where total > maximumBytes {
                let size = item.byteCount
                self.remove(item)
                total -= size
            }
        }
    }
}
