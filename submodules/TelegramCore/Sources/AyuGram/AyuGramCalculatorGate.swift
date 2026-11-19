import Foundation

/// Whether the calculator disguise is currently covering the app.
///
/// Lives in TelegramCore so that both the UI layer (which shows the calculator)
/// and the app lock (which must not prompt for biometrics while the calculator is
/// on screen) can read it without depending on each other.
public final class AyuGramCalculatorGateState {
    public static let shared = AyuGramCalculatorGateState()

    private let mutex = NSLock()
    private var locked: Bool = true

    public var isLocked: Bool {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        return self.locked
    }

    public func lock() {
        self.mutex.lock()
        let changed = !self.locked
        self.locked = true
        self.mutex.unlock()
        if changed {
            self.notify()
        }
    }

    public func unlock() {
        self.mutex.lock()
        let changed = self.locked
        self.locked = false
        self.mutex.unlock()
        if changed {
            self.notify()
        }
    }

    private func notify() {
        let post = {
            NotificationCenter.default.post(name: .ayuGramCalculatorLockChanged, object: nil)
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }
}

public extension Notification.Name {
    static let ayuGramCalculatorLockChanged = Notification.Name("AyuGramCalculatorLockChanged")
}
