import XCTest
import TelegramCore
@testable import SettingsUI

/// Pins the AyuGram defaults and the small pure helpers around them. These run in
/// their own container, so the local defaults are cleared first and again at the
/// end to keep the suite independent from whatever the host app stored.
final class AyuGramSettingsTests: XCTestCase {
    private func clearSettings() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("ayugram.settings.") {
            defaults.removeObject(forKey: key)
        }
    }

    override func setUp() {
        super.setUp()
        self.clearSettings()
    }

    override func tearDown() {
        self.clearSettings()
        super.tearDown()
    }

    func testPrivacyFirstDefaults() {
        XCTAssertFalse(AyuGramSettings.ghostModeEnabled)

        XCTAssertTrue(AyuGramSettings.hideReadReceiptsOption)
        XCTAssertTrue(AyuGramSettings.hideStoryViewsOption)
        XCTAssertTrue(AyuGramSettings.hideTypingOption)
        XCTAssertTrue(AyuGramSettings.stayOfflineOption)
        XCTAssertFalse(AyuGramSettings.markReadAfterSend)

        XCTAssertTrue(AyuGramSettings.antiRecallEnabled)
        XCTAssertTrue(AyuGramSettings.editHistoryEnabled)
        XCTAssertTrue(AyuGramSettings.showDeletedMessageMarker)
        XCTAssertEqual(AyuGramSettings.deletedMessageOpacity, 0.55, accuracy: 0.0001)

        XCTAssertFalse(AyuGramSettings.saveRestrictedContent)
        XCTAssertFalse(AyuGramSettings.preserveViewOnceMedia)
        XCTAssertFalse(AyuGramSettings.savePublicChannels)
        XCTAssertFalse(AyuGramSettings.savePublicGroups)
        XCTAssertTrue(AyuGramSettings.savePrivateChats)
        XCTAssertTrue(AyuGramSettings.saveChannels)

        XCTAssertFalse(AyuGramSettings.vaultBiometricLockEnabled)
        XCTAssertEqual(AyuGramSettings.retentionDays, 0)
        XCTAssertEqual(AyuGramSettings.vaultLimitMB, 1024)

        XCTAssertTrue(AyuGramSettings.localNotificationsEnabled)
        XCTAssertFalse(AyuGramSettings.backgroundKeepAliveEnabled)
        XCTAssertTrue(AyuGramSettings.disableAds)
        XCTAssertFalse(AyuGramSettings.showEditedMessageMark)

        XCTAssertTrue(AyuGramSettings.calculatorLockEnabled)
        XCTAssertEqual(AyuGramSettings.calculatorUnlockCode, "2024")
        XCTAssertTrue(AyuGramSettings.calculatorLockOnBackground)
        XCTAssertTrue(AyuGramSettings.calculatorHideNotifications)
    }

    func testCalculatorUnlockCodeIsDigitsOnlyAndNeverEmpty() {
        AyuGramSettings.calculatorUnlockCode = "12ab34"
        XCTAssertEqual(AyuGramSettings.calculatorUnlockCode, "1234")

        AyuGramSettings.calculatorUnlockCode = ""
        XCTAssertEqual(AyuGramSettings.calculatorUnlockCode, "2024")

        AyuGramSettings.calculatorUnlockCode = " 99 88 "
        XCTAssertEqual(AyuGramSettings.calculatorUnlockCode, "9988")
    }

    func testTogglesRoundTrip() {
        AyuGramSettings.disableAds = false
        XCTAssertFalse(AyuGramSettings.disableAds)
        AyuGramSettings.disableAds = true
        XCTAssertTrue(AyuGramSettings.disableAds)

        AyuGramSettings.preserveViewOnceMedia = true
        XCTAssertTrue(AyuGramSettings.preserveViewOnceMedia)
        AyuGramSettings.preserveViewOnceMedia = false
        XCTAssertFalse(AyuGramSettings.preserveViewOnceMedia)

        AyuGramSettings.deletedMessageOpacity = 1000.0
        XCTAssertEqual(AyuGramSettings.deletedMessageOpacity, 0.7, accuracy: 0.0001)
        AyuGramSettings.deletedMessageOpacity = -1.0
        XCTAssertEqual(AyuGramSettings.deletedMessageOpacity, 0.4, accuracy: 0.0001)

        AyuGramSettings.retentionDays = -5
        XCTAssertEqual(AyuGramSettings.retentionDays, 0)
    }

    func testGhostModeGatesItsSwitches() {
        AyuGramSettings.hideReadReceiptsOption = true
        AyuGramSettings.ghostModeEnabled = false
        XCTAssertFalse(AyuGramSettings.hideReadReceipts)
        XCTAssertFalse(AyuGramSettings.hideTyping)
        XCTAssertFalse(AyuGramSettings.stayOffline)

        AyuGramSettings.ghostModeEnabled = true
        XCTAssertTrue(AyuGramSettings.hideReadReceipts)
        XCTAssertTrue(AyuGramSettings.hideTyping)
        XCTAssertTrue(AyuGramSettings.stayOffline)

        AyuGramSettings.hideReadReceiptsOption = false
        XCTAssertFalse(AyuGramSettings.hideReadReceipts)
        XCTAssertTrue(AyuGramSettings.hideTyping)
    }

    func testDeletedMarkPresetsAreClamped() {
        let count = AyuGramSettings.deletedMarkPresetCount
        XCTAssertGreaterThan(count, 1)

        AyuGramSettings.deletedMarkPreset = 0
        XCTAssertEqual(AyuGramSettings.deletedMark, "🛡 AyuGram")

        AyuGramSettings.deletedMarkPreset = count - 1
        XCTAssertEqual(AyuGramSettings.deletedMark, "")

        AyuGramSettings.deletedMarkPreset = count
        XCTAssertEqual(AyuGramSettings.deletedMarkPreset, count - 1)

        AyuGramSettings.deletedMarkPreset = -3
        XCTAssertEqual(AyuGramSettings.deletedMarkPreset, 0)
    }

    func testPeerRulesRoundTrip() {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4242))
        XCTAssertEqual(AyuGramSettings.peerRule(peerId), .inherit)

        AyuGramSettings.setPeerRule(.always, peerId: peerId)
        XCTAssertEqual(AyuGramSettings.peerRule(peerId), .always)
        XCTAssertEqual(AyuGramSettings.peerIds(rule: .always), [peerId])

        AyuGramSettings.setPeerRule(.never, peerId: peerId)
        XCTAssertEqual(AyuGramSettings.peerRule(peerId), .never)
        XCTAssertEqual(AyuGramSettings.peerIds(rule: .always), [])
        XCTAssertEqual(AyuGramSettings.peerIds(rule: .never), [peerId])

        AyuGramSettings.setPeerRule(.inherit, peerId: peerId)
        XCTAssertEqual(AyuGramSettings.peerRule(peerId), .inherit)
        XCTAssertEqual(AyuGramSettings.peerIds(rule: .never), [])
    }

    func testStringsFollowTheLanguage() {
        let russian = AyuGramStrings(languageCode: "ru")
        let english = AyuGramStrings(languageCode: "en")

        XCTAssertEqual(russian.appName, english.appName)
        XCTAssertNotEqual(russian.ghostMode, english.ghostMode)
        XCTAssertNotEqual(russian.categories, english.categories)

        XCTAssertEqual(AyuGramStrings(languageCode: "de-DE").categories, english.categories)
        XCTAssertEqual(AyuGramStrings(languageCode: "uk-UA").categories, russian.categories)
        XCTAssertEqual(AyuGramStrings(languageCode: "RU").spy, russian.spy)
    }

    func testNothingIsPublicByDefault() {
        XCTAssertFalse(AyuGramSettings.isPublicPeer(nil))
    }
}
