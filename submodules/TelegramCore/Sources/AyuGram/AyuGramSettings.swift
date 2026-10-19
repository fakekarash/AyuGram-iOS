import Foundation

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
