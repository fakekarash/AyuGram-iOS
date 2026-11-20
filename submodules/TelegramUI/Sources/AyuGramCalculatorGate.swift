import Foundation
import UIKit
import Display
import TelegramCore
import AccountContext

/// Owns the calculator disguise: presents the calculator above everything at
/// launch (and again after backgrounding when configured) and removes it when the
/// unlock code is entered.
public final class AyuGramCalculatorGate {
    public static let shared = AyuGramCalculatorGate()

    /// Used by the simulator smoke test to reach the app behind the disguise.
    public static let skipLaunchArgument = "-ayugram-skip-calculator-lock"
    /// Used by the simulator smoke test to type the unlock code through the engine.
    public static let simulateUnlockArgument = "-ayugram-simulate-unlock"
    /// Used by the simulator smoke test to screenshot the scientific keypad.
    public static let showScientificArgument = "-ayugram-show-scientific"

    private weak var controller: AyuGramCalculatorController?

    private init() {
    }

    public var isCalculatorVisible: Bool {
        return self.controller != nil
    }

    public func installIfNeeded(window: Window1) {
        if ProcessInfo.processInfo.arguments.contains(AyuGramCalculatorGate.skipLaunchArgument) {
            AyuGramCalculatorGateState.shared.unlock()
        }
        guard AyuGramSettings.calculatorLockEnabled else {
            // Turning the disguise off must also release the lock, otherwise local
            // notifications would stay suppressed for the rest of the session.
            AyuGramCalculatorGateState.shared.unlock()
            self.dismissCalculator()
            return
        }
        guard AyuGramCalculatorGateState.shared.isLocked else {
            self.dismissCalculator()
            return
        }
        guard self.controller == nil else {
            return
        }

        let controller = AyuGramCalculatorController()
        controller.presentedOverCoveringView = true
        controller.isOpaqueWhenInOverlay = true
        self.controller = controller
        window.present(controller, on: .calculator, blockInteraction: true)
    }

    /// Re-arms the disguise, e.g. when the app resigns active so that the app
    /// switcher snapshot shows the calculator instead of the chat list.
    public func lockNow(window: Window1) {
        AyuGramCalculatorGateState.shared.lock()
        self.installIfNeeded(window: window)
    }

    public func handleUnlock() {
        AyuGramCalculatorGateState.shared.unlock()
        self.dismissCalculator()
    }

    private func dismissCalculator() {
        guard let controller = self.controller else {
            return
        }
        self.controller = nil
        controller.dismiss()
    }
}
