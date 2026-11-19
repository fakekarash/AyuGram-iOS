import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore

/// Full-screen calculator shown while the disguise is locked.
///
/// Plain UIKit inside a `Display.ViewController` on purpose: the screen must work
/// before any Telegram state is loaded, it has no navigation, no input and no
/// dependency on the account.
public final class AyuGramCalculatorController: ViewController {
    private enum Key {
        case digit(String)
        case operation(AyuGramCalculatorOperation)
        case clear
        case negate
        case percent
        case decimal
        case equals
    }

    private let engine = AyuGramCalculatorEngine()
    private let displayLabel = UILabel()
    private let keypadView = UIView()
    private var keyButtons: [UIButton] = []
    private var keyModels: [Key] = []
    private var keyFrames: [CGRect] = []

    private let rowCount: CGFloat = 5.0
    private let columnCount: CGFloat = 4.0
    private let keySpacing: CGFloat = 12.0

    public init() {
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let digitColor = UIColor(red: 0.20, green: 0.20, blue: 0.21, alpha: 1.0)
    private static let functionColor = UIColor(red: 0.65, green: 0.65, blue: 0.66, alpha: 1.0)
    private static let operationColor = UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1.0)

    override public func loadDisplayNode() {
        let node = ASDisplayNode()
        node.backgroundColor = .black
        self.displayNode = node
        self.displayNodeDidLoad()

        self.statusBar.updateStatusBarStyle(.White, animated: false)

        self.engine.unlockCode = AyuGramSettings.calculatorUnlockCode
        self.engine.onUnlock = { [weak self] in
            self?.handleUnlock()
        }

        self.displayLabel.text = self.engine.display
        self.displayLabel.textColor = .white
        self.displayLabel.textAlignment = .right
        self.displayLabel.adjustsFontSizeToFitWidth = true
        self.displayLabel.minimumScaleFactor = 0.35
        self.displayLabel.numberOfLines = 1
        self.displayLabel.font = UIFont.systemFont(ofSize: 72.0, weight: .light)
        node.view.addSubview(self.displayLabel)

        self.keypadView.backgroundColor = .clear
        node.view.addSubview(self.keypadView)

        self.keyModels = [
            .clear, .negate, .percent, .operation(.divide),
            .digit("7"), .digit("8"), .digit("9"), .operation(.multiply),
            .digit("4"), .digit("5"), .digit("6"), .operation(.subtract),
            .digit("1"), .digit("2"), .digit("3"), .operation(.add),
            .digit("0"), .decimal, .equals
        ]

        for model in self.keyModels {
            let button = self.makeButton(for: model)
            button.addTarget(self, action: #selector(self.keyTapped(_:)), for: .touchUpInside)
            self.keypadView.addSubview(button)
            self.keyButtons.append(button)
        }

        if ProcessInfo.processInfo.arguments.contains(AyuGramCalculatorGate.simulateUnlockArgument) {
            // Simulator smoke test: drive the real unlock path without a human tap.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.simulateUnlockEntry()
            }
        }
    }

    private func simulateUnlockEntry() {
        for digit in AyuGramSettings.calculatorUnlockCode {
            self.apply(.digit(String(digit)))
        }
        self.apply(.equals)
    }

    private func makeButton(for model: Key) -> UIButton {
        let button = UIButton(type: .custom)
        button.clipsToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 30.0, weight: .regular)

        let title: String
        let background: UIColor
        let titleColor: UIColor
        switch model {
        case let .digit(value):
            title = value
            background = AyuGramCalculatorController.digitColor
            titleColor = .white
        case .decimal:
            title = "."
            background = AyuGramCalculatorController.digitColor
            titleColor = .white
        case let .operation(operation):
            switch operation {
            case .add:
                title = "+"
            case .subtract:
                title = "−"
            case .multiply:
                title = "×"
            case .divide:
                title = "÷"
            }
            background = AyuGramCalculatorController.operationColor
            titleColor = .white
        case .equals:
            title = "="
            background = AyuGramCalculatorController.operationColor
            titleColor = .white
        case .clear:
            title = "C"
            background = AyuGramCalculatorController.functionColor
            titleColor = .black
        case .negate:
            title = "±"
            background = AyuGramCalculatorController.functionColor
            titleColor = .black
        case .percent:
            title = "%"
            background = AyuGramCalculatorController.functionColor
            titleColor = .black
        }

        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.backgroundColor = background
        return button
    }

    @objc private func keyTapped(_ sender: UIButton) {
        guard let index = self.keyButtons.firstIndex(of: sender), index < self.keyModels.count else {
            return
        }
        self.apply(self.keyModels[index])
    }

    private func apply(_ key: Key) {
        switch key {
        case let .digit(value):
            self.engine.input(digit: value)
        case let .operation(operation):
            self.engine.setOperation(operation)
        case .clear:
            self.engine.clear()
        case .negate:
            self.engine.negate()
        case .percent:
            self.engine.percent()
        case .decimal:
            self.engine.decimalPoint()
        case .equals:
            self.engine.equals()
        }
        self.displayLabel.text = self.engine.display
    }

    private func handleUnlock() {
        AyuGramCalculatorGate.shared.handleUnlock()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        let size = layout.size
        let safeInsets = layout.safeInsets
        let topInset = max(safeInsets.top, layout.statusBarHeight ?? 0.0)
        let bottomInset = safeInsets.bottom

        let horizontalInset: CGFloat = 18.0
        let availableWidth = max(1.0, size.width - horizontalInset * 2.0)
        let displayHeight = max(120.0, size.height * 0.24)

        self.displayLabel.frame = CGRect(
            x: horizontalInset,
            y: topInset + 8.0,
            width: availableWidth,
            height: displayHeight
        )

        let keypadTop = topInset + displayHeight + 12.0
        let keypadHeight = max(1.0, size.height - bottomInset - 16.0 - keypadTop)
        self.keypadView.frame = CGRect(x: horizontalInset, y: keypadTop, width: availableWidth, height: keypadHeight)

        let columnWidth = (availableWidth - self.keySpacing * (self.columnCount - 1.0)) / self.columnCount
        let rowHeight = (keypadHeight - self.keySpacing * (self.rowCount - 1.0)) / self.rowCount
        // iOS calculator keys are circles; keep them round and vertically centred
        // inside their row, with "0" drawn as a wide pill.
        let keySide = min(columnWidth, rowHeight)
        let verticalOffset = (rowHeight - keySide) / 2.0

        var frames: [CGRect] = []
        var index = 0
        for row in 0 ..< Int(self.rowCount) {
            var column = 0
            while column < Int(self.columnCount) {
                var span = 1
                if index < self.keyModels.count, case .digit("0") = self.keyModels[index], row == Int(self.rowCount) - 1 {
                    span = 2
                }
                let x = CGFloat(column) * (columnWidth + self.keySpacing)
                let y = CGFloat(row) * (rowHeight + self.keySpacing) + verticalOffset
                let width = span == 1 ? keySide : columnWidth * 2.0 + self.keySpacing
                frames.append(CGRect(x: x, y: y, width: width, height: keySide))
                index += 1
                column += span
            }
        }
        self.keyFrames = frames

        for (keyIndex, button) in self.keyButtons.enumerated() {
            guard keyIndex < self.keyFrames.count else {
                button.isHidden = true
                continue
            }
            button.isHidden = false
            let frame = self.keyFrames[keyIndex]
            button.frame = frame
            button.layer.cornerRadius = min(frame.width, frame.height) / 2.0
        }
    }
}
