import Foundation
import Postbox

public enum AyuGramPeerRule: Int, Codable {
    case inherit = 0
    case always = 1
    case never = 2
}

public enum AyuGramChatCategory: String, Codable {
    case privateChat
    case group
    case channel
    case bot
    case unknown
}

public enum AyuGramSettings {
    private static let prefix = "ayugram.settings."

    private static func value(_ key: String, default defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        let fullKey = self.prefix + key
        if defaults.object(forKey: fullKey) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: fullKey)
    }

    private static func setValue(_ value: Bool, _ key: String) {
        UserDefaults.standard.set(value, forKey: self.prefix + key)
        NotificationCenter.default.post(name: .ayuGramSettingsChanged, object: nil)
    }

    private static func doubleValue(_ key: String, default defaultValue: Double) -> Double {
        let defaults = UserDefaults.standard
        let fullKey = self.prefix + key
        guard defaults.object(forKey: fullKey) != nil else {
            return defaultValue
        }
        return defaults.double(forKey: fullKey)
    }

    private static func setDoubleValue(_ value: Double, _ key: String) {
        UserDefaults.standard.set(value, forKey: self.prefix + key)
        NotificationCenter.default.post(name: .ayuGramSettingsChanged, object: nil)
    }

    private static func integerValue(_ key: String, default defaultValue: Int) -> Int {
        let defaults = UserDefaults.standard
        let fullKey = self.prefix + key
        guard defaults.object(forKey: fullKey) != nil else {
            return defaultValue
        }
        return defaults.integer(forKey: fullKey)
    }

    private static func setIntegerValue(_ value: Int, _ key: String) {
        UserDefaults.standard.set(value, forKey: self.prefix + key)
        NotificationCenter.default.post(name: .ayuGramSettingsChanged, object: nil)
    }

    private static var peerRules: [String: Int] {
        get {
            guard let data = UserDefaults.standard.data(forKey: self.prefix + "peerRules"),
                  let result = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return result
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: self.prefix + "peerRules")
            }
            NotificationCenter.default.post(name: .ayuGramSettingsChanged, object: nil)
        }
    }

    public static var ghostModeEnabled: Bool {
        get { self.value("ghostModeEnabled", default: false) }
        set { self.setValue(newValue, "ghostModeEnabled") }
    }

    public static var hideReadReceiptsOption: Bool {
        get { self.value("hideReadReceipts", default: true) }
        set { self.setValue(newValue, "hideReadReceipts") }
    }

    public static var hideStoryViewsOption: Bool {
        get { self.value("hideStoryViews", default: true) }
        set { self.setValue(newValue, "hideStoryViews") }
    }

    public static var hideTypingOption: Bool {
        get { self.value("hideTyping", default: true) }
        set { self.setValue(newValue, "hideTyping") }
    }

    public static var stayOfflineOption: Bool {
        get { self.value("stayOffline", default: true) }
        set { self.setValue(newValue, "stayOffline") }
    }

    public static var saveRestrictedContent: Bool {
        get { self.value("saveRestrictedContent", default: true) }
        set { self.setValue(newValue, "saveRestrictedContent") }
    }

    public static var preserveViewOnceMedia: Bool {
        get { self.value("preserveViewOnceMedia", default: true) }
        set { self.setValue(newValue, "preserveViewOnceMedia") }
    }

    public static var vaultEnabled: Bool {
        get { self.value("vaultEnabled", default: true) }
        set { self.setValue(newValue, "vaultEnabled") }
    }

    public static var antiRecallEnabled: Bool {
        get { self.value("antiRecallEnabled", default: true) }
        set { self.setValue(newValue, "antiRecallEnabled") }
    }

    public static var editHistoryEnabled: Bool {
        get { self.value("editHistoryEnabled", default: true) }
        set { self.setValue(newValue, "editHistoryEnabled") }
    }

    public static var showDeletedMessageMarker: Bool {
        get { self.value("showDeletedMessageMarker", default: true) }
        set { self.setValue(newValue, "showDeletedMessageMarker") }
    }

    public static var deletionNotificationsEnabled: Bool {
        get { self.value("deletionNotificationsEnabled", default: true) }
        set { self.setValue(newValue, "deletionNotificationsEnabled") }
    }

    public static var systemDeletionNotificationsEnabled: Bool {
        get { self.value("systemDeletionNotificationsEnabled", default: false) }
        set { self.setValue(newValue, "systemDeletionNotificationsEnabled") }
    }

    public static var savePrivateChats: Bool {
        get { self.value("savePrivateChats", default: true) }
        set { self.setValue(newValue, "savePrivateChats") }
    }

    public static var saveGroups: Bool {
        get { self.value("saveGroups", default: true) }
        set { self.setValue(newValue, "saveGroups") }
    }

    public static var saveChannels: Bool {
        get { self.value("saveChannels", default: true) }
        set { self.setValue(newValue, "saveChannels") }
    }

    public static var saveBots: Bool {
        get { self.value("saveBots", default: true) }
        set { self.setValue(newValue, "saveBots") }
    }

    public static var saveDeletedText: Bool {
        get { self.value("saveDeletedText", default: true) }
        set { self.setValue(newValue, "saveDeletedText") }
    }

    public static var saveDeletedPhotos: Bool {
        get { self.value("saveDeletedPhotos", default: true) }
        set { self.setValue(newValue, "saveDeletedPhotos") }
    }

    public static var saveDeletedVideos: Bool {
        get { self.value("saveDeletedVideos", default: true) }
        set { self.setValue(newValue, "saveDeletedVideos") }
    }

    public static var saveDeletedFiles: Bool {
        get { self.value("saveDeletedFiles", default: true) }
        set { self.setValue(newValue, "saveDeletedFiles") }
    }

    public static var saveDeletedVoice: Bool {
        get { self.value("saveDeletedVoice", default: true) }
        set { self.setValue(newValue, "saveDeletedVoice") }
    }

    public static var saveDeletedStickers: Bool {
        get { self.value("saveDeletedStickers", default: true) }
        set { self.setValue(newValue, "saveDeletedStickers") }
    }

    public static var notifyPrivateChats: Bool {
        get { self.value("notifyPrivateChats", default: true) }
        set { self.setValue(newValue, "notifyPrivateChats") }
    }

    public static var notifyGroups: Bool {
        get { self.value("notifyGroups", default: true) }
        set { self.setValue(newValue, "notifyGroups") }
    }

    public static var notifyChannels: Bool {
        get { self.value("notifyChannels", default: true) }
        set { self.setValue(newValue, "notifyChannels") }
    }

    public static var notifyBots: Bool {
        get { self.value("notifyBots", default: true) }
        set { self.setValue(newValue, "notifyBots") }
    }

    public static var hideNotificationContent: Bool {
        get { self.value("hideNotificationContent", default: false) }
        set { self.setValue(newValue, "hideNotificationContent") }
    }

    public static var vaultBiometricLockEnabled: Bool {
        get { self.value("vaultBiometricLockEnabled", default: false) }
        set { self.setValue(newValue, "vaultBiometricLockEnabled") }
    }

    public static var retentionDays: Int {
        get { self.integerValue("retentionDays", default: 0) }
        set { self.setIntegerValue(max(0, newValue), "retentionDays") }
    }

    public static var vaultLimitMB: Int {
        get { self.integerValue("vaultLimitMB", default: 1024) }
        set { self.setIntegerValue(max(0, newValue), "vaultLimitMB") }
    }

    public static func peerRule(_ peerId: PeerId) -> AyuGramPeerRule {
        return AyuGramPeerRule(rawValue: self.peerRules[String(peerId.toInt64())] ?? 0) ?? .inherit
    }

    public static func setPeerRule(_ rule: AyuGramPeerRule, peerId: PeerId) {
        var rules = self.peerRules
        let key = String(peerId.toInt64())
        if rule == .inherit {
            rules.removeValue(forKey: key)
        } else {
            rules[key] = rule.rawValue
        }
        self.peerRules = rules
    }

    public static func peerIds(rule: AyuGramPeerRule) -> [PeerId] {
        return self.peerRules.compactMap { key, value in
            guard value == rule.rawValue, let rawValue = Int64(key) else {
                return nil
            }
            return PeerId(rawValue)
        }.sorted()
    }

    public static func category(message: Message) -> AyuGramChatCategory {
        if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
            return .privateChat
        }
        guard let peer = message.peers[message.id.peerId] else {
            return .unknown
        }
        if let user = peer as? TelegramUser {
            return user.botInfo == nil ? .privateChat : .bot
        } else if peer is TelegramGroup || peer is TelegramCommunity {
            return .group
        } else if let channel = peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                return .channel
            case .group:
                return .group
            }
        }
        return .unknown
    }

    public static func categoryEnabled(_ category: AyuGramChatCategory) -> Bool {
        switch category {
        case .privateChat: return self.savePrivateChats
        case .group: return self.saveGroups
        case .channel: return self.saveChannels
        case .bot: return self.saveBots
        case .unknown: return true
        }
    }

    public static func notificationEnabled(_ category: AyuGramChatCategory) -> Bool {
        switch category {
        case .privateChat: return self.notifyPrivateChats
        case .group: return self.notifyGroups
        case .channel: return self.notifyChannels
        case .bot: return self.notifyBots
        case .unknown: return true
        }
    }

    public static func shouldPreserve(message: Message) -> Bool {
        switch self.peerRule(message.id.peerId) {
        case .always:
            return true
        case .never:
            return false
        case .inherit:
            return self.categoryEnabled(self.category(message: message))
        }
    }

    public static var deletedMessageOpacity: Double {
        get {
            return min(0.7, max(0.4, self.doubleValue("deletedMessageOpacity", default: 0.55)))
        }
        set {
            self.setDoubleValue(min(0.7, max(0.4, newValue)), "deletedMessageOpacity")
        }
    }

    public static var hideReadReceipts: Bool {
        self.ghostModeEnabled && self.hideReadReceiptsOption
    }

    public static var hideStoryViews: Bool {
        self.ghostModeEnabled && self.hideStoryViewsOption
    }

    public static var hideTyping: Bool {
        self.ghostModeEnabled && self.hideTypingOption
    }

    public static var stayOffline: Bool {
        self.ghostModeEnabled && self.stayOfflineOption
    }
}

public extension Notification.Name {
    static let ayuGramSettingsChanged = Notification.Name("AyuGramSettingsChanged")
    static let ayuGramMessageDeleted = Notification.Name("AyuGramMessageDeleted")
    static let ayuGramVaultChanged = Notification.Name("AyuGramVaultChanged")
    static let ayuGramArchiveChanged = Notification.Name("AyuGramArchiveChanged")
}
