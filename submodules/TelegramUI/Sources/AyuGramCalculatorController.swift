import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore

/// Full-screen calculator shown while the disguise is locked.
///
/// Styled after the system Calculator: black background, a top bar with history
/// and basic/scientific switch, a right-aligned display and pill keys. Plain
/// UIKit inside a `Display.ViewController`, because the screen must work before
/// any Telegram state exists.
public final class AyuGramCalculatorController: ViewController {
    private enum CalcKey {
        case digit(String)
        case decimal
        case operation(AyuGramCalculatorOperation)
        case power
        case equals
        case clear
        case backspace
        case sign
        case percent
        case openParenthesis
        case closeParenthesis
        case constant(AyuGramCalculatorConstant)
        case random
        case exponent
        case function(AyuGramCalculatorFunction)
        case second
        case angleUnit
        case memoryClear
        case memoryAdd
        case memorySubtract
        case memoryRecall
        case toggleScientific
        case toggleHistory
    }

    private let engine = AyuGramCalculatorEngine()

    private let topBarView = UIView()
    private let historyButton = UIButton(type: .custom)
    private let scientificButton = UIButton(type: .custom)
    private let displayLabel = UILabel()
    private let scientificView = UIView()
    private let keypadView = UIView()
    private let historyView = UIView()
    private let historyTextView = UITextView()

    private var keyButtons: [UIButton] = []
    private var keyModels: [CalcKey] = []
    private var keyFrames: [CGRect] = []
    private var keyIsScientific: [Bool] = []

    private var isScientific = false
    private var isHistoryVisible = false

    private let keySpacing: CGFloat = 10.0
    private let scientificSpacing: CGFloat = 8.0
    private let scientificRows: CGFloat = 6.0
    private let basicRows: CGFloat = 5.0
    private let keypadColumns: CGFloat = 4.0
    private let scientificColumns: CGFloat = 6.0

    private static let backgroundColor = UIColor.black
    private static let numberColor = UIColor(red: 0.20, green: 0.20, blue: 0.21, alpha: 1.0)
    private static let functionColor = UIColor(red: 0.35, green: 0.35, blue: 0.36, alpha: 1.0)
    private static let scientificColor = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
    private static let operationColor = UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1.0)

    public init() {
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = ASDisplayNode()
        node.backgroundColor = AyuGramCalculatorController.backgroundColor
        self.displayNode = node
        self.displayNodeDidLoad()

        self.statusBar.updateStatusBarStyle(.White, animated: false)

        self.engine.unlockCode = AyuGramSettings.calculatorUnlockCode
        self.engine.onUnlock = { [weak self] in
            self?.handleUnlock()
        }

        let root = node.view
        root.backgroundColor = AyuGramCalculatorController.backgroundColor

        self.topBarView.backgroundColor = .clear
        root.addSubview(self.topBarView)

        self.configureTopBarButton(self.historyButton, symbol: "clock")
        self.historyButton.addTarget(self, action: #selector(self.historyTapped), for: .touchUpInside)
        self.topBarView.addSubview(self.historyButton)

        self.configureTopBarButton(self.scientificButton, symbol: "function")
        self.scientificButton.addTarget(self, action: #selector(self.scientificTapped), for: .touchUpInside)
        self.topBarView.addSubview(self.scientificButton)

        self.displayLabel.text = "0"
        self.displayLabel.textColor = .white
        self.displayLabel.textAlignment = .right
        self.displayLabel.adjustsFontSizeToFitWidth = true
        self.displayLabel.minimumScaleFactor = 0.3
        self.displayLabel.numberOfLines = 1
        self.displayLabel.font = UIFont.systemFont(ofSize: 78.0, weight: .light)
        root.addSubview(self.displayLabel)

        self.scientificView.backgroundColor = .clear
        root.addSubview(self.scientificView)

        self.keypadView.backgroundColor = .clear
        root.addSubview(self.keypadView)

        self.historyView.backgroundColor = UIColor(white: 0.0, alpha: 0.94)
        self.historyView.isHidden = true
        self.historyView.layer.cornerRadius = 18.0
        root.addSubview(self.historyView)

        self.historyTextView.backgroundColor = .clear
        self.historyTextView.textColor = .white
        self.historyTextView.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
        self.historyTextView.isEditable = false
        self.historyTextView.showsVerticalScrollIndicator = false
        self.historyView.addSubview(self.historyTextView)

        if ProcessInfo.processInfo.arguments.contains(AyuGramCalculatorGate.showScientificArgument) {
            self.isScientific = true
        }

        self.rebuildKeys()
        self.updateDisplay()

        if ProcessInfo.processInfo.arguments.contains(AyuGramCalculatorGate.simulateUnlockArgument) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.simulateUnlockEntry()
            }
        }
    }

    private func simulateUnlockEntry() {
        for digit in AyuGramSettings.calculatorUnlockCode {
            self.engine.input(digit: String(digit))
        }
        self.engine.equals()
        self.updateDisplay()
    }

    private func configureTopBarButton(_ button: UIButton, symbol: String) {
        button.backgroundColor = AyuGramCalculatorController.functionColor
        button.tintColor = .white
        button.layer.cornerRadius = 22.0
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
    }

    // MARK: - Keypad construction

    private func rebuildKeys() {
        for button in self.keyButtons {
            button.removeFromSuperview()
        }
        self.keyButtons = []
        self.keyModels = []
        self.keyIsScientific = []

        if self.isScientific {
            let rows: [[CalcKey]] = [
                [.openParenthesis, .closeParenthesis, .memoryClear, .memoryAdd, .memorySubtract, .memoryRecall],
                [.second, .function(.square), .function(.cube), .power, .function(.exponential), .function(.tenPower)],
                [.function(.reciprocal), .function(.squareRoot), .function(.cubeRoot),
                 .function(.squareRoot), .function(.naturalLog), .function(.log10)],
                [.function(.factorial), .function(.sine), .function(.cosine), .function(.tangent),
                 .constant(.e), .exponent],
                [.random, .function(.hyperbolicSine), .function(.hyperbolicCosine), .function(.hyperbolicTangent),
                 .constant(.pi), .angleUnit]
            ]
            for row in rows {
                for key in row {
                    self.appendKey(key, isScientific: true)
                }
            }
        }

        let basicRows: [[CalcKey]] = [
            [.backspace, .clear, .percent, .operation(.divide)],
            [.digit("7"), .digit("8"), .digit("9"), .operation(.multiply)],
            [.digit("4"), .digit("5"), .digit("6"), .operation(.subtract)],
            [.digit("1"), .digit("2"), .digit("3"), .operation(.add)],
            [.sign, .digit("0"), .decimal, .equals]
        ]
        for row in basicRows {
            for key in row {
                self.appendKey(key, isScientific: false)
            }
        }
    }

    private func appendKey(_ key: CalcKey, isScientific: Bool) {
        let button = UIButton(type: .custom)
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(self.keyTapped(_:)), for: .touchUpInside)
        let title = self.title(for: key)
        button.setTitle(title, for: .normal)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.5
        button.titleLabel?.font = UIFont.systemFont(
            ofSize: isScientific ? 15.0 : 30.0,
            weight: isScientific ? .regular : .regular
        )
        let colors = self.colors(for: key, isScientific: isScientific)
        button.backgroundColor = colors.background
        button.setTitleColor(colors.title, for: .normal)
        (isScientific ? self.scientificView : self.keypadView).addSubview(button)
        self.keyButtons.append(button)
        self.keyModels.append(key)
        self.keyIsScientific.append(isScientific)
    }

    private func title(for key: CalcKey) -> String {
        switch key {
        case let .digit(value):
            return value
        case .decimal:
            return ","
        case .operation(let operation):
            switch operation {
            case .add:
                return "+"
            case .subtract:
                return "−"
            case .multiply:
                return "×"
            case .divide:
                return "÷"
            }
        case .power:
            return "xʸ"
        case .equals:
            return "="
        case .clear:
            return "AC"
        case .backspace:
            return "⌫"
        case .sign:
            return "±"
        case .percent:
            return "%"
        case .openParenthesis:
            return "("
        case .closeParenthesis:
            return ")"
        case .constant(let constant):
            switch constant {
            case .pi:
                return "π"
            case .e:
                return "e"
            }
        case .random:
            return "Rand"
        case .exponent:
            return "EE"
        case .function(let function):
            return self.functionTitle(function)
        case .second:
            return "2nd"
        case .angleUnit:
            switch self.engine.angleUnit {
            case .degrees:
                return "Rad"
            case .radians:
                return "Deg"
            }
        case .memoryClear:
            return "mc"
        case .memoryAdd:
            return "m+"
        case .memorySubtract:
            return "m−"
        case .memoryRecall:
            return "mr"
        case .toggleScientific, .toggleHistory:
            return ""
        }
    }

    private func functionTitle(_ function: AyuGramCalculatorFunction) -> String {
        switch function {
        case .square:
            return "x²"
        case .cube:
            return "x³"
        case .exponential:
            return "eˣ"
        case .tenPower:
            return "10ˣ"
        case .reciprocal:
            return "1/x"
        case .squareRoot:
            return "√x"
        case .cubeRoot:
            return "∛x"
        case .naturalLog:
            return "ln"
        case .log10:
            return "log₁₀"
        case .factorial:
            return "x!"
        case .percent:
            return "%"
        case .sine:
            return self.engine.isSecondFunction ? "sin⁻¹" : "sin"
        case .cosine:
            return self.engine.isSecondFunction ? "cos⁻¹" : "cos"
        case .tangent:
            return self.engine.isSecondFunction ? "tg⁻¹" : "tg"
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

    private func colors(for key: CalcKey, isScientific: Bool) -> (background: UIColor, title: UIColor) {
        if isScientific {
            return (AyuGramCalculatorController.scientificColor, .white)
        }
        switch key {
        case .operation, .equals:
            return (AyuGramCalculatorController.operationColor, .white)
        case .clear, .backspace, .percent:
            return (AyuGramCalculatorController.functionColor, .white)
        default:
            return (AyuGramCalculatorController.numberColor, .white)
        }
    }

    // MARK: - Actions

    @objc private func keyTapped(_ sender: UIButton) {
        guard let index = self.keyButtons.firstIndex(of: sender), index < self.keyModels.count else {
            return
        }
        self.perform(self.keyModels[index])
    }

    @objc private func historyTapped() {
        self.isHistoryVisible.toggle()
        self.historyView.isHidden = !self.isHistoryVisible
        if self.isHistoryVisible {
            self.reloadHistory()
        }
        self.requestLayout(transition: .immediate)
    }

    @objc private func scientificTapped() {
        self.isScientific.toggle()
        self.rebuildKeys()
        self.updateDisplay()
        self.requestLayout(transition: .immediate)
    }

    private func reloadHistory() {
        if self.engine.history.isEmpty {
            self.historyTextView.text = "История пуста"
        } else {
            self.historyTextView.text = self.engine.history.map { entry in
                entry.expression + " = " + entry.result
            }.joined(separator: "\n")
        }
    }

    private func perform(_ key: CalcKey) {
        switch key {
        case .digit(let value):
            self.engine.input(digit: value)
        case .decimal:
            self.engine.decimalPoint()
        case .operation(let operation):
            self.engine.setOperation(operation)
        case .power:
            self.engine.power()
        case .equals:
            self.engine.equals()
        case .clear:
            self.engine.clear()
        case .backspace:
            self.engine.backspace()
        case .sign:
            self.engine.toggleSign()
        case .percent:
            self.engine.applyFunction(.percent)
        case .openParenthesis:
            self.engine.openParenthesis()
        case .closeParenthesis:
            self.engine.closeParenthesis()
        case .constant(let constant):
            self.engine.insertConstant(constant)
        case .random:
            self.engine.insertRandom()
        case .exponent:
            self.engine.insertExponent()
        case .function(let function):
            switch function {
            case .sine where self.engine.isSecondFunction:
                self.engine.applyFunction(.arcSine)
            case .cosine where self.engine.isSecondFunction:
                self.engine.applyFunction(.arcCosine)
            case .tangent where self.engine.isSecondFunction:
                self.engine.applyFunction(.arcTangent)
            default:
                self.engine.applyFunction(function)
            }
        case .second:
            self.engine.toggleSecondFunction()
            self.rebuildKeys()
            self.requestLayout(transition: .immediate)
        case .angleUnit:
            self.engine.toggleAngleUnit()
            self.rebuildKeys()
            self.requestLayout(transition: .immediate)
        case .memoryClear:
            self.engine.memoryClear()
        case .memoryAdd:
            self.engine.memoryAdd()
        case .memorySubtract:
            self.engine.memorySubtract()
        case .memoryRecall:
            self.engine.memoryRecall()
        case .toggleScientific:
            self.isScientific.toggle()
            self.rebuildKeys()
        case .toggleHistory:
            self.historyTapped()
            return
        }
        self.updateDisplay()
    }

    private func updateDisplay() {
        self.displayLabel.text = self.engine.display
        if self.isHistoryVisible {
            self.reloadHistory()
        }
    }

    private func handleUnlock() {
        AyuGramCalculatorGate.shared.handleUnlock()
    }

    // MARK: - Layout

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        let size = layout.size
        let safeInsets = layout.safeInsets
        let topInset = max(safeInsets.top, layout.statusBarHeight ?? 0.0)
        let bottomInset = safeInsets.bottom
        let horizontalInset: CGFloat = 16.0
        let availableWidth = max(1.0, size.width - horizontalInset * 2.0)

        let topBarHeight: CGFloat = 44.0
        self.topBarView.frame = CGRect(x: horizontalInset, y: topInset + 4.0, width: availableWidth, height: topBarHeight)
        self.historyButton.frame = CGRect(x: 0.0, y: 0.0, width: topBarHeight, height: topBarHeight)
        self.historyButton.layer.cornerRadius = topBarHeight / 2.0
        self.scientificButton.frame = CGRect(x: availableWidth - topBarHeight, y: 0.0, width: topBarHeight, height: topBarHeight)
        self.scientificButton.layer.cornerRadius = topBarHeight / 2.0

        let scientificHeight: CGFloat = self.isScientific ? 6.0 * 40.0 + 5.0 * scientificSpacing + 10.0 : 0.0
        let basicRowHeight = max(48.0, min(74.0, (size.height - topInset - bottomInset - 150.0 - scientificHeight) / 5.6))
        let basicHeight = 5.0 * basicRowHeight + 4.0 * keySpacing
        let keypadBottom = size.height - bottomInset - 12.0
        let keypadTop = keypadBottom - basicHeight
        let displayTop = topInset + topBarHeight + 12.0
        let displayHeight = max(80.0, keypadTop - (self.isScientific ? scientificHeight + 10.0 : 0.0) - displayTop)

        self.displayLabel.frame = CGRect(x: horizontalInset, y: displayTop, width: availableWidth, height: displayHeight)

        if self.isScientific {
            self.scientificView.isHidden = false
            self.scientificView.frame = CGRect(
                x: horizontalInset,
                y: keypadTop - scientificHeight,
                width: availableWidth,
                height: scientificHeight
            )
        } else {
            self.scientificView.isHidden = true
            self.scientificView.frame = .zero
        }

        self.keypadView.frame = CGRect(x: horizontalInset, y: keypadTop, width: availableWidth, height: basicHeight)

        self.historyView.frame = CGRect(
            x: horizontalInset,
            y: displayTop,
            width: availableWidth,
            height: max(120.0, keypadTop - displayTop - 8.0)
        )
        self.historyTextView.frame = self.historyView.bounds.insetBy(dx: 16.0, dy: 16.0)

        self.layoutKeys(availableWidth: availableWidth, basicRowHeight: basicRowHeight)
    }

    private func layoutKeys(availableWidth: CGFloat, basicRowHeight: CGFloat) {
        let columnWidth = (availableWidth - self.keySpacing * (self.keypadColumns - 1.0)) / self.keypadColumns
        let scientificWidth = (availableWidth - self.scientificSpacing * (self.scientificColumns - 1.0)) / self.scientificColumns
        let scientificHeight: CGFloat = 40.0

        var basicIndex = 0
        var scientificIndex = 0
        for (index, button) in self.keyButtons.enumerated() {
            if self.keyIsScientific[index] {
                let row = scientificIndex / Int(self.scientificColumns)
                let column = scientificIndex % Int(self.scientificColumns)
                button.frame = CGRect(
                    x: CGFloat(column) * (scientificWidth + self.scientificSpacing),
                    y: CGFloat(row) * (scientificHeight + self.scientificSpacing),
                    width: scientificWidth,
                    height: scientificHeight
                )
                button.layer.cornerRadius = scientificHeight * 0.34
                scientificIndex += 1
            } else {
                let row = basicIndex / Int(self.keypadColumns)
                let column = basicIndex % Int(self.keypadColumns)
                let isOperatorColumn = (column == Int(self.keypadColumns) - 1)
                button.frame = CGRect(
                    x: CGFloat(column) * (columnWidth + self.keySpacing),
                    y: CGFloat(row) * (basicRowHeight + self.keySpacing),
                    width: columnWidth,
                    height: basicRowHeight
                )
                button.layer.cornerRadius = basicRowHeight * 0.34
                button.titleLabel?.font = UIFont.systemFont(ofSize: isOperatorColumn ? 34.0 : 30.0, weight: .regular)
                basicIndex += 1
            }
        }
    }
}
