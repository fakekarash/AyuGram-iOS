import Foundation
import Security
import CryptoKit

/// Encryption for the AyuGram archive metadata.
///
/// The archive and the vault store message text and chat titles, so their JSON
/// on disk is sealed with AES-GCM using a 256-bit key that only exists in this
/// device's keychain (never synced, never backed up). Media files in the vault
/// stay plain files protected by the iOS data protection class and the sandbox.
public enum AyuGramStorageCrypto {
    private static let service = "org.ayugram.ios.storage"
    private static let account = "archive-key"

    private static func loadKey() -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            return data
        }
        guard status == errSecItemNotFound || status == errSecSuccess else {
            return nil
        }

        var bytes = Data(count: 32)
        let randomStatus = bytes.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else {
                return errSecAllocate
            }
            return SecRandomCopyBytes(kSecRandomDefault, 32, base)
        }
        guard randomStatus == errSecSuccess else {
            return nil
        }

        query[kSecValueData as String] = bytes
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return bytes
        }

        // Another process in the same app group may have created the key first.
        let retryQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var retryResult: CFTypeRef?
        if SecItemCopyMatching(retryQuery as CFDictionary, &retryResult) == errSecSuccess, let data = retryResult as? Data, data.count == 32 {
            return data
        }
        return nil
    }

    private static let cachedKey: SymmetricKey? = {
        guard let data = AyuGramStorageCrypto.loadKey() else {
            return nil
        }
        return SymmetricKey(data: data)
    }()

    public static var isAvailable: Bool {
        return self.cachedKey != nil
    }

    public static func encrypt(_ data: Data) -> Data? {
        guard let key = self.cachedKey else {
            return nil
        }
        guard let combined = try? AES.GCM.seal(data, using: key).combined else {
            return nil
        }
        return combined
    }

    public static func decrypt(_ data: Data) -> Data? {
        guard let key = self.cachedKey else {
            return nil
        }
        guard let box = try? AES.GCM.SealedBox(combined: data) else {
            return nil
        }
        return try? AES.GCM.open(box, using: key)
    }

    /// Decodes a stored payload that may still be a plain-text JSON file written
    /// by an older build.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data, decoder: JSONDecoder = JSONDecoder()) -> T? {
        if let decrypted = self.decrypt(data), let value = try? decoder.decode(type, from: decrypted) {
            return value
        }
        return try? decoder.decode(type, from: data)
    }

    /// Encodes and seals a value. Falls back to plain JSON only when the keychain
    /// is unavailable, so older builds can still read the archive.
    public static func encode<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) -> Data? {
        guard let plain = try? encoder.encode(value) else {
            return nil
        }
        return self.encrypt(plain) ?? plain
    }
}
