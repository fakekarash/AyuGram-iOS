import Foundation

public enum AyuGramCalculatorOperation {
    case add
    case subtract
    case multiply
    case divide
}

public enum AyuGramCalculatorConstant {
    case pi
    case e
}

public enum AyuGramCalculatorAngleUnit {
    case degrees
    case radians
}

public enum AyuGramCalculatorFunction {
    case square
    case cube
    case exponential
    case tenPower
    case reciprocal
    case squareRoot
    case cubeRoot
    case naturalLog
    case log10
    case factorial
    case percent
    case sine
    case cosine
    case tangent
    case arcSine
    case arcCosine
    case arcTangent
    case hyperbolicSine
    case hyperbolicCosine
    case hyperbolicTangent
}

/// A calculator that behaves like the system one: an expression you type, a
/// result on "=", parentheses, scientific functions, memory and history.
///
/// The engine is pure (no UI, no Telegram state) so it can be unit tested, and it
/// also recognises the disguise unlock code: a bare code followed by "=" opens
/// the app instead of being evaluated.
public final class AyuGramCalculatorEngine {
    public struct HistoryEntry {
        public let expression: String
        public let result: String

        public init(expression: String, result: String) {
            self.expression = expression
            self.result = result
        }
    }

    public private(set) var display: String = "0"
    public private(set) var expression: String = ""
    public private(set) var history: [HistoryEntry] = []
    public private(set) var isSecondFunction: Bool = false
    public private(set) var angleUnit: AyuGramCalculatorAngleUnit = .degrees
    public private(set) var hasMemory: Bool = false

    public var unlockCode: String = "2024"
    public var onUnlock: (() -> Void)?

    private enum Token {
        case number(String)
        case operation(AyuGramCalculatorOperation)
        case power
        case function(AyuGramCalculatorFunction)
        case openParenthesis
        case closeParenthesis
    }

    private var tokens: [Token] = []
    private var typing = false
    private var showingResult = false
    private var memoryValue: Double = 0.0

    public init() {
    }

    // MARK: - Input

    public func input(digit: String) {
        guard digit.count == 1, let character = digit.first, character.isNumber else {
            return
        }
        self.startNewExpressionIfShowingResult()
        if case .number(let text)? = self.tokens.last, !self.typing {
            if text == "-" {
                // The minus inserted right after "(" starts the number itself.
                self.tokens[self.tokens.count - 1] = .number("-" + digit)
                self.typing = true
                self.refreshDisplay()
                return
            }
            self.tokens.append(.operation(.multiply))
        }
        if self.typing, case .number(let text)? = self.tokens.last {
            var updated = text
            let digits = updated.filter { $0.isNumber }
            if digits.count >= 12 {
                return
            }
            updated += digit
            self.tokens[self.tokens.count - 1] = .number(updated)
        } else {
            self.tokens.append(.number(digit))
            self.typing = true
        }
        self.refreshDisplay()
    }

    public func decimalPoint() {
        self.startNewExpressionIfShowingResult()
        if self.typing, case .number(let text)? = self.tokens.last, !text.contains("."), !text.contains("e") {
            self.tokens[self.tokens.count - 1] = .number(text + ".")
        } else {
            self.tokens.append(.number("0."))
            self.typing = true
        }
        self.refreshDisplay()
    }

    public func insertExponent() {
        self.startNewExpressionIfShowingResult()
        if self.typing, case .number(let text)? = self.tokens.last, !text.contains("e"), !text.hasSuffix(".") {
            self.tokens[self.tokens.count - 1] = .number(text + "e")
            self.refreshDisplay()
        }
    }

    public func setOperation(_ operation: AyuGramCalculatorOperation) {
        self.startNewExpressionIfShowingResult()
        self.typing = false
        if let last = self.tokens.last {
            switch last {
            case .operation, .power:
                self.tokens[self.tokens.count - 1] = .operation(operation)
                self.refreshDisplay()
                return
            case .openParenthesis:
                if operation == .subtract {
                    self.tokens.append(.number("-"))
                } else {
                    return
                }
            case .function, .closeParenthesis, .number:
                self.tokens.append(.operation(operation))
            }
        } else {
            self.tokens.append(.number("0"))
            self.tokens.append(.operation(operation))
        }
        self.refreshDisplay()
    }

    public func power() {
        self.startNewExpressionIfShowingResult()
        self.typing = false
        if let last = self.tokens.last {
            switch last {
            case .operation, .power:
                self.tokens[self.tokens.count - 1] = .power
            case .openParenthesis, .function:
                return
            case .number, .closeParenthesis:
                self.tokens.append(.power)
            }
        }
        self.refreshDisplay()
    }

    public func openParenthesis() {
        self.startNewExpressionIfShowingResult()
        self.typing = false
        if case .number? = self.tokens.last, self.tokens.count > 0 {
            self.tokens.append(.operation(.multiply))
        }
        if case .closeParenthesis? = self.tokens.last {
            self.tokens.append(.operation(.multiply))
        }
        self.tokens.append(.openParenthesis)
        self.refreshDisplay()
    }

    public func closeParenthesis() {
        guard self.tokens.contains(where: {
            if case .openParenthesis = $0 {
                return true
            }
            return false
        }) else {
            return
        }
        self.typing = false
        if case .operation? = self.tokens.last {
            self.tokens.removeLast()
        }
        self.tokens.append(.closeParenthesis)
        self.refreshDisplay()
    }

    /// Prefix functions wrap what follows, like typing "sin(" on the system calculator.
    public func applyFunction(_ function: AyuGramCalculatorFunction) {
        switch function {
        case .square, .cube, .reciprocal, .squareRoot, .cubeRoot, .factorial, .percent:
            guard let last = self.tokens.last else {
                return
            }
            switch last {
            case .number, .closeParenthesis:
                self.typing = false
                self.tokens.insert(.function(function), at: self.tokens.count - 1)
                self.tokens.insert(.openParenthesis, at: self.tokens.count - 1)
                self.tokens.append(.closeParenthesis)
            case .openParenthesis:
                return
            case .operation, .power, .function:
                return
            }
        case .exponential, .tenPower, .naturalLog, .log10, .sine, .cosine, .tangent,
             .arcSine, .arcCosine, .arcTangent, .hyperbolicSine, .hyperbolicCosine, .hyperbolicTangent:
            self.startNewExpressionIfShowingResult()
            self.typing = false
            self.tokens.append(.function(function))
            self.tokens.append(.openParenthesis)
        }
        self.refreshDisplay()
    }

    public func insertConstant(_ constant: AyuGramCalculatorConstant) {
        self.startNewExpressionIfShowingResult()
        let text: String
        switch constant {
        case .pi:
            text = "π"
        case .e:
            text = "e"
        }
        if case .number? = self.tokens.last {
            self.tokens.append(.operation(.multiply))
        }
        self.tokens.append(.number(text))
        self.typing = false
        self.refreshDisplay()
    }

    public func insertRandom() {
        self.startNewExpressionIfShowingResult()
        if case .number? = self.tokens.last {
            self.tokens.append(.operation(.multiply))
        }
        let value = String(format: "0.%04d", Int.random(in: 0 ... 9999))
        self.tokens.append(.number(value))
        self.typing = false
        self.refreshDisplay()
    }

    public func toggleSign() {
        if self.showingResult, let value = Double(self.display) {
            self.tokens = [.number(AyuGramCalculatorEngine.format(-value))]
            self.typing = false
            self.showingResult = false
            self.refreshDisplay()
            return
        }
        guard case .number(let text)? = self.tokens.last else {
            return
        }
        if text.hasPrefix("-") {
            self.tokens[self.tokens.count - 1] = .number(String(text.dropFirst()))
        } else {
            self.tokens[self.tokens.count - 1] = .number("-" + text)
        }
        self.refreshDisplay()
    }

    public func backspace() {
        if self.showingResult {
            self.clear()
            return
        }
        guard let last = self.tokens.last else {
            return
        }
        switch last {
        case .number(let text):
            if text.count > 1 {
                self.tokens[self.tokens.count - 1] = .number(String(text.dropLast()))
            } else {
                self.tokens.removeLast()
                self.typing = self.tokens.last.map {
                    if case .number = $0 {
                        return true
                    }
                    return false
                } ?? false
            }
            if text.hasSuffix("e") {
                self.typing = true
            }
        default:
            self.tokens.removeLast()
            self.typing = false
        }
        self.refreshDisplay()
    }

    public func clear() {
        self.tokens = []
        self.typing = false
        self.showingResult = false
        self.refreshDisplay()
    }

    public func toggleSecondFunction() {
        self.isSecondFunction.toggle()
    }

    public func toggleAngleUnit() {
        switch self.angleUnit {
        case .degrees:
            self.angleUnit = .radians
        case .radians:
            self.angleUnit = .degrees
        }
    }

    public func memoryClear() {
        self.memoryValue = 0.0
        self.hasMemory = false
    }

    public func memoryAdd() {
        self.memoryValue += self.currentValue() ?? 0.0
        self.hasMemory = true
        self.showingResult = false
    }

    public func memorySubtract() {
        self.memoryValue -= self.currentValue() ?? 0.0
        self.hasMemory = true
        self.showingResult = false
    }

    public func memoryRecall() {
        if case .number? = self.tokens.last {
            self.tokens.append(.operation(.multiply))
        }
        self.tokens.append(.number(AyuGramCalculatorEngine.format(self.memoryValue)))
        self.typing = false
        self.showingResult = false
        self.refreshDisplay()
    }

    public func clearHistory() {
        self.history.removeAll()
    }

    // MARK: - Evaluation

    public func equals() {
        if self.tokens.isEmpty {
            return
        }

        // A bare unlock code is the disguise unlock, not arithmetic.
        if !self.showingResult, self.tokens.count == 1, case .number(let text)? = self.tokens.first {
            let digits = text.filter { $0.isNumber }
            let hasOnlyDigits = text.allSatisfy { $0.isNumber }
            if hasOnlyDigits, !digits.isEmpty, digits == self.unlockCode.filter({ $0.isNumber }) {
                self.showingResult = true
                self.typing = false
                self.onUnlock?()
                return
            }
        }

        var tokens = self.tokens
        let openCount = tokens.reduce(0) { count, token in
            if case .openParenthesis = token {
                return count + 1
            }
            if case .closeParenthesis = token {
                return count - 1
            }
            return count
        }
        if openCount > 0 {
            for _ in 0 ..< openCount {
                tokens.append(.closeParenthesis)
            }
        }
        while case .operation? = tokens.last {
            tokens.removeLast()
        }

        let renderedExpression = AyuGramCalculatorEngine.render(tokens)
        switch AyuGramCalculatorEngine.evaluate(tokens, angleUnit: self.angleUnit) {
        case .success(let value):
            let text = AyuGramCalculatorEngine.format(value)
            self.history.insert(HistoryEntry(expression: renderedExpression, result: text), at: 0)
            if self.history.count > 30 {
                self.history.removeLast(self.history.count - 30)
            }
            self.tokens = [.number(text)]
            self.typing = false
            self.showingResult = true
            self.display = text
            self.expression = renderedExpression
        case .failure:
            self.display = "Ошибка"
            self.tokens = []
            self.typing = false
            self.showingResult = true
        }
        self.expression = renderedExpression
    }

    private func currentValue() -> Double? {
        if let value = Double(self.display) {
            return value
        }
        switch AyuGramCalculatorEngine.evaluate(self.tokens, angleUnit: self.angleUnit) {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    private func startNewExpressionIfShowingResult() {
        if self.showingResult, case .number? = self.tokens.last {
            if !self.typing {
                self.tokens = []
                self.showingResult = false
            }
        }
    }

    private func refreshDisplay() {
        self.expression = self.tokens.isEmpty ? "" : AyuGramCalculatorEngine.render(self.tokens)
        // The system calculator shows the value you are entering, not the whole
        // expression; the expression itself is only carried into the history.
        var value: String?
        for token in self.tokens.reversed() {
            switch token {
            case .number(let text):
                value = text
            case .openParenthesis, .function:
                break
            default:
                if value != nil {
                    break
                }
            }
            if value != nil {
                break
            }
        }
        self.display = value ?? "0"
    }

    // MARK: - Rendering and evaluation helpers

    private static func renderNumber(_ text: String) -> String {
        if text == "π" || text == "e" {
            return text
        }
        return text
    }

    static func render(_ tokens: [Token]) -> String {
        var result = ""
        for token in tokens {
            switch token {
            case .number(let text):
                result += renderNumber(text)
            case .operation(let operation):
                switch operation {
                case .add:
                    result += "+"
                case .subtract:
                    result += "−"
                case .multiply:
                    result += "×"
                case .divide:
                    result += "÷"
                }
            case .power:
                result += "^"
            case .function(let function):
                result += functionSymbol(function) + "("
            case .openParenthesis:
                result += "("
            case .closeParenthesis:
                result += ")"
            }
        }
        return result.isEmpty ? "0" : result
    }

    static func functionSymbol(_ function: AyuGramCalculatorFunction) -> String {
        switch function {
        case .square:
            return "^(2)"
        case .cube:
            return "^(3)"
        case .exponential:
            return "e^"
        case .tenPower:
            return "10^"
        case .reciprocal:
            return "1/"
        case .squareRoot:
            return "√"
        case .cubeRoot:
            return "∛"
        case .naturalLog:
            return "ln"
        case .log10:
            return "log10"
        case .factorial:
            return "!"
        case .percent:
            return "%"
        case .sine:
            return "sin"
        case .cosine:
            return "cos"
        case .tangent:
            return "tg"
        case .arcSine:
            return "sin⁻¹"
        case .arcCosine:
            return "cos⁻¹"
        case .arcTangent:
            return "tg⁻¹"
        case .hyperbolicSine:
            return "sh"
        case .hyperbolicCosine:
            return "ch"
        case .hyperbolicTangent:
            return "th"
        }
    }

    enum EvaluationResult {
        case success(Double)
        case failure
    }

    private enum RPNItem {
        case value(Double)
        case operation(AyuGramCalculatorOperation)
        case power
        case function(AyuGramCalculatorFunction)
    }

    private static func precedence(_ token: Token) -> Int {
        switch token {
        case .operation(.add), .operation(.subtract):
            return 2
        case .operation(.multiply), .operation(.divide):
            return 3
        case .power:
            return 4
        case .function:
            return 5
        default:
            return 0
        }
    }

    private static func isRightAssociative(_ token: Token) -> Bool {
        switch token {
        case .power, .function:
            return true
        default:
            return false
        }
    }

    static func evaluate(_ tokens: [Token], angleUnit: AyuGramCalculatorAngleUnit) -> EvaluationResult {
        var output: [RPNItem] = []
        var stack: [Token] = []

        for token in tokens {
            switch token {
            case .number(let text):
                guard let value = numberValue(text) else {
                    return .failure
                }
                output.append(.value(value))
            case .function:
                stack.append(token)
            case .operation, .power:
                while let top = stack.last, precedence(top) >= precedence(token), !isRightAssociative(token) {
                    stack.removeLast()
                    appendToOutput(top, output: &output)
                }
                stack.append(token)
            case .openParenthesis:
                stack.append(token)
            case .closeParenthesis:
                var matched = false
                while let top = stack.last {
                    stack.removeLast()
                    if case .openParenthesis = top {
                        matched = true
                        break
                    }
                    appendToOutput(top, output: &output)
                }
                if !matched {
                    return .failure
                }
            }
        }
        while let top = stack.last {
            stack.removeLast()
            if case .openParenthesis = top {
                return .failure
            }
            appendToOutput(top, output: &output)
        }

        var values: [Double] = []
        for item in output {
            switch item {
            case .value(let value):
                values.append(value)
            case .operation(let operation):
                guard values.count >= 2 else {
                    return .failure
                }
                let right = values.removeLast()
                let left = values.removeLast()
                guard let result = applyOperation(operation, left: left, right: right) else {
                    return .failure
                }
                values.append(result)
            case .power:
                guard values.count >= 2 else {
                    return .failure
                }
                let exponent = values.removeLast()
                let base = values.removeLast()
                let result = pow(base, exponent)
                if !result.isFinite {
                    return .failure
                }
                values.append(result)
            case .function(let function):
                guard let value = values.last else {
                    return .failure
                }
                values.removeLast()
                guard let result = applyFunction(function, value: value, angleUnit: angleUnit) else {
                    return .failure
                }
                values.append(result)
            }
        }
        guard values.count == 1, values[0].isFinite else {
            return .failure
        }
        return .success(values[0])
    }

    private static func appendToOutput(_ token: Token, output: inout [RPNItem]) {
        switch token {
        case .operation(let operation):
            output.append(.operation(operation))
        case .power:
            output.append(.power)
        case .function(let function):
            output.append(.function(function))
        default:
            break
        }
    }

    private static func numberValue(_ text: String) -> Double? {
        switch text {
        case "π":
            return Double.pi
        case "e":
            return M_E
        case "-π":
            return -Double.pi
        case "-e":
            return -M_E
        default:
            if text.hasSuffix("e") {
                return Double(text.dropLast())
            }
            return Double(text)
        }
    }

    private static func applyOperation(_ operation: AyuGramCalculatorOperation, left: Double, right: Double) -> Double? {
        let result: Double
        switch operation {
        case .add:
            result = left + right
        case .subtract:
            result = left - right
        case .multiply:
            result = left * right
        case .divide:
            guard right != 0.0 else {
                return nil
            }
            result = left / right
        }
        guard result.isFinite else {
            return nil
        }
        return result
    }

    private static func applyFunction(
        _ function: AyuGramCalculatorFunction,
        value: Double,
        angleUnit: AyuGramCalculatorAngleUnit
    ) -> Double? {
        let toRadians: (Double) -> Double = { angle in
            switch angleUnit {
            case .degrees:
                return angle * Double.pi / 180.0
            case .radians:
                return angle
            }
        }
        let fromRadians: (Double) -> Double = { angle in
            switch angleUnit {
            case .degrees:
                return angle * 180.0 / Double.pi
            case .radians:
                return angle
            }
        }
        let result: Double
        switch function {
        case .square:
            result = value * value
        case .cube:
            result = value * value * value
        case .exponential:
            result = exp(value)
        case .tenPower:
            result = pow(10.0, value)
        case .reciprocal:
            guard value != 0.0 else {
                return nil
            }
            result = 1.0 / value
        case .squareRoot:
            guard value >= 0.0 else {
                return nil
            }
            result = sqrt(value)
        case .cubeRoot:
            result = cbrt(value)
        case .naturalLog:
            guard value > 0.0 else {
                return nil
            }
            result = log(value)
        case .log10:
            guard value > 0.0 else {
                return nil
            }
            result = log10(value)
        case .factorial:
            guard value >= 0.0, value <= 170.0, value == value.rounded() else {
                return nil
            }
            var factorial = 1.0
            if value >= 1.0 {
                for factor in 1 ... Int(value) {
                    factorial *= Double(factor)
                }
            }
            result = factorial
        case .percent:
            result = value / 100.0
        case .sine:
            result = sin(toRadians(value))
        case .cosine:
            result = cos(toRadians(value))
        case .tangent:
            let radians = toRadians(value)
            if abs(cos(radians)) < 1e-12 {
                return nil
            }
            result = tan(radians)
        case .arcSine:
            guard value >= -1.0, value <= 1.0 else {
                return nil
            }
            result = fromRadians(asin(value))
        case .arcCosine:
            guard value >= -1.0, value <= 1.0 else {
                return nil
            }
            result = fromRadians(acos(value))
        case .arcTangent:
            result = fromRadians(atan(value))
        case .hyperbolicSine:
            result = sinh(value)
        case .hyperbolicCosine:
            result = cosh(value)
        case .hyperbolicTangent:
            result = tanh(value)
        }
        guard result.isFinite else {
            return nil
        }
        return result
    }

    /// The system calculator shows at most nine significant digits and no trailing zeros.
    static func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "Ошибка"
        }
        if value == value.rounded(), abs(value) < 1_000_000_000_000_000.0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.8g", value)
    }
}
