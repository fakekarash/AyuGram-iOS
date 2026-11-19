import Foundation
import Postbox

/// Holds read positions that Ghost Mode decided not to report yet.
///
/// With "read after reply" enabled, opening a chat marks messages read only on
/// this device; the position is remembered here and reported to the server once
/// the user actually sends a message in that chat.
public final class AyuGramDeferredReadRegistry {
    public static let shared = AyuGramDeferredReadRegistry()

    private var pending: [PeerId: MessageIndex] = [:]
    private let lock = NSLock()

    public func store(peerId: PeerId, index: MessageIndex) {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let current = self.pending[peerId], current.id.id >= index.id.id {
            return
        }
        self.pending[peerId] = index
    }

    public func take(peerId: PeerId) -> MessageIndex? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.pending.removeValue(forKey: peerId)
    }

    public func clear() {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.pending.removeAll()
    }
}
