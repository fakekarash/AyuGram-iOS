import Foundation

public enum AyuGramCalculatorOperation {
    case add
    case subtract
    case multiply
    case divide
}

/// A small, dependency-free calculator that also recognises the unlock code.
///
/// The engine is deliberately pure so it can be unit tested: the UI feeds button
/// presses in and reads `display`, and the disguise unlock is delivered through
/// `onUnlock` when "=" is pressed on a bare code entry.
public final class AyuGramCalculatorEngine {
    public private(set) var display: String = "0"
    public var unlockCode: String = "2024"
    public var onUnlock: (() -> Void)?

    /// Digits typed since the last `clear()` or `=`, if the user is currently
    /// typing a number. `nil` means the display shows a result.
    private var entry: String?
    private var accumulator: Double?
    private var pendingOperation: AyuGramCalculatorOperation?
    private var lastOperation: AyuGramCalculatorOperation?
    private var lastOperand: Double?
    private var usedOperatorSinceClear = false
    private var isError = false

    public init() {
    }

    public func input(digit: String) {
        guard digit.count == 1, let character = digit.first, character.isNumber else {
            return
        }
        if self.isError {
            self.resetEntry()
        }
        var current = self.entry ?? ""
        if current == "0" {
            current = digit
        } else if current == "-0" {
            current = "-" + digit
        } else if current.count < 12 {
            current += digit
        }
        self.entry = current
        self.display = current
    }

    public func decimalPoint() {
        if self.isError {
            self.resetEntry()
        }
        var current = self.entry ?? "0"
        if current.contains(".") {
            return
        }
        current += "."
        self.entry = current
        self.display = current
    }

    public func negate() {
        guard !self.isError else {
            return
        }
        if var current = self.entry {
            if current.hasPrefix("-") {
                current.removeFirst()
            } else if current != "0" {
                current = "-" + current
            }
            self.entry = current
            self.display = current
        } else if let value = Double(self.display) {
            let negated = -value
            self.display = AyuGramCalculatorEngine.format(negated)
            self.accumulator = nil
            self.lastOperation = nil
            self.lastOperand = nil
        }
    }

    public func percent() {
        guard !self.isError, let value = Double(self.entry ?? self.display) else {
            return
        }
        let result = value / 100.0
        let text = AyuGramCalculatorEngine.format(result)
        self.entry = text
        self.display = text
    }

    public func setOperation(_ operation: AyuGramCalculatorOperation) {
        if self.isError {
            self.resetEntry()
        }
        let operand: Double
        if let entry = self.entry {
            operand = Double(entry) ?? 0.0
        } else if let accumulator = self.accumulator {
            operand = accumulator
        } else {
            operand = Double(self.display) ?? 0.0
        }
        if let pendingOperation = self.pendingOperation, self.entry != nil {
            let result = AyuGramCalculatorEngine.apply(pendingOperation, left: self.accumulator ?? 0.0, right: operand)
            self.accumulator = result
            self.display = AyuGramCalculatorEngine.format(result)
        } else {
            self.accumulator = operand
        }
        self.entry = nil
        self.pendingOperation = operation
        self.usedOperatorSinceClear = true
        self.lastOperation = nil
        self.lastOperand = nil
    }

    public func equals() {
        if self.isError {
            self.resetEntry()
            return
        }

        // A bare code entry followed by "=" is the disguise unlock, not arithmetic.
        if let entry = self.entry, !self.usedOperatorSinceClear, self.pendingOperation == nil {
            let digits = entry.filter { $0.isNumber }
            if !digits.isEmpty, digits == self.unlockCode.filter({ $0.isNumber }) {
                self.entry = nil
                self.usedOperatorSinceClear = false
                self.onUnlock?()
                return
            }
        }

        let operation: AyuGramCalculatorOperation?
        let operand: Double
        if let pendingOperation = self.pendingOperation {
            operation = pendingOperation
            operand = Double(self.entry ?? self.display) ?? 0.0
            self.lastOperation = pendingOperation
            self.lastOperand = operand
        } else if let lastOperation = self.lastOperation, let lastOperand = self.lastOperand, self.entry == nil {
            operation = lastOperation
            operand = lastOperand
        } else {
            operation = nil
            operand = Double(self.entry ?? self.display) ?? 0.0
        }

        guard let operation = operation else {
            if let entry = self.entry {
                self.display = entry
            }
            self.entry = nil
            return
        }

        let result = AyuGramCalculatorEngine.apply(operation, left: self.accumulator ?? 0.0, right: operand)
        self.accumulator = nil
        self.pendingOperation = nil
        self.entry = nil
        self.usedOperatorSinceClear = false
        if result.isNaN || result.isInfinite {
            self.display = "Ошибка"
            self.isError = true
            self.accumulator = nil
        } else {
            self.display = AyuGramCalculatorEngine.format(result)
        }
    }

    public func clear() {
        self.display = "0"
        self.resetEntry()
    }

    private func resetEntry() {
        self.entry = nil
        self.accumulator = nil
        self.pendingOperation = nil
        self.lastOperation = nil
        self.lastOperand = nil
        self.usedOperatorSinceClear = false
        self.isError = false
        self.display = "0"
    }

    private static func apply(_ operation: AyuGramCalculatorOperation, left: Double, right: Double) -> Double {
        switch operation {
        case .add:
            return left + right
        case .subtract:
            return left - right
        case .multiply:
            return left * right
        case .divide:
            if right == 0.0 {
                return Double.nan
            }
            return left / right
        }
    }

    /// iOS calculator shows at most nine significant digits and no trailing zeros.
    static func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "Ошибка"
        }
        if value == value.rounded(), abs(value) < 1_000_000_000_000_000.0 {
            return String(format: "%.0f", value)
        }
        var text = String(format: "%.8g", value)
        if text.contains("e") {
            text = String(format: "%.8g", value)
        }
        return text
    }
}
