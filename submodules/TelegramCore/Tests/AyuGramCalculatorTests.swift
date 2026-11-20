import XCTest
@testable import TelegramCore

final class AyuGramCalculatorTests: XCTestCase {
    private func engine(code: String = "2024") -> AyuGramCalculatorEngine {
        let engine = AyuGramCalculatorEngine()
        engine.unlockCode = code
        return engine
    }

    private func type(_ text: String, into engine: AyuGramCalculatorEngine) {
        for character in text {
            if character == "." {
                engine.decimalPoint()
            } else {
                engine.input(digit: String(character))
            }
        }
    }

    func testBasicArithmeticAndHistory() {
        let engine = self.engine()
        self.type("2", into: engine)
        engine.setOperation(.add)
        self.type("2", into: engine)
        XCTAssertEqual(engine.display, "2")

        engine.equals()
        XCTAssertEqual(engine.display, "4")
        XCTAssertEqual(engine.history.count, 1)
        XCTAssertEqual(engine.history[0].expression, "2+2")
        XCTAssertEqual(engine.history[0].result, "4")
    }

    func testDigitAfterResultStartsANewExpression() {
        let engine = self.engine()
        self.type("2", into: engine)
        engine.setOperation(.add)
        self.type("3", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "5")

        self.type("7", into: engine)
        XCTAssertEqual(engine.display, "7")
    }

    func testBareCodeFollowedByEqualsUnlocks() {
        let engine = self.engine()
        var unlocked = 0
        engine.onUnlock = { unlocked += 1 }

        self.type("2024", into: engine)
        XCTAssertEqual(engine.display, "2024")
        engine.equals()

        XCTAssertEqual(unlocked, 1)
        XCTAssertEqual(engine.display, "2024")
        XCTAssertTrue(engine.history.isEmpty)
    }

    func testCodeOnTopOfArithmeticDoesNotUnlock() {
        let engine = self.engine()
        var unlocked = 0
        engine.onUnlock = { unlocked += 1 }

        self.type("2024", into: engine)
        engine.setOperation(.add)
        self.type("1", into: engine)
        engine.equals()

        XCTAssertEqual(unlocked, 0)
        XCTAssertEqual(engine.display, "2025")
    }

    func testCustomUnlockCode() {
        let engine = self.engine(code: "1234")
        var unlocked = 0
        engine.onUnlock = { unlocked += 1 }

        self.type("2024", into: engine)
        engine.equals()
        XCTAssertEqual(unlocked, 0)

        engine.clear()
        self.type("1234", into: engine)
        engine.equals()
        XCTAssertEqual(unlocked, 1)
    }

    func testParentheses() {
        let engine = self.engine()
        engine.openParenthesis()
        self.type("2", into: engine)
        engine.setOperation(.add)
        self.type("3", into: engine)
        engine.closeParenthesis()
        engine.setOperation(.multiply)
        self.type("4", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "20")
    }

    func testMissingParenthesesAreClosedAutomatically() {
        let engine = self.engine()
        engine.openParenthesis()
        self.type("2", into: engine)
        engine.setOperation(.add)
        self.type("3", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "5")
    }

    func testPowerAndRoots() {
        let engine = self.engine()
        self.type("2", into: engine)
        engine.power()
        self.type("10", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "1024")

        engine.clear()
        self.type("9", into: engine)
        engine.applyFunction(.squareRoot)
        engine.equals()
        XCTAssertEqual(engine.display, "3")

        engine.clear()
        self.type("5", into: engine)
        engine.applyFunction(.square)
        engine.equals()
        XCTAssertEqual(engine.display, "25")
    }

    func testFactorialAndReciprocal() {
        let engine = self.engine()
        self.type("5", into: engine)
        engine.applyFunction(.factorial)
        engine.equals()
        XCTAssertEqual(engine.display, "120")

        engine.clear()
        self.type("4", into: engine)
        engine.applyFunction(.reciprocal)
        engine.equals()
        XCTAssertEqual(engine.display, "0.25")
    }

    func testTrigonometryRespectsTheAngleUnit() {
        let engine = self.engine()
        engine.applyFunction(.sine)
        self.type("30", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "0.5")

        engine.toggleAngleUnit()
        engine.clear()
        engine.applyFunction(.sine)
        self.type("30", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "-0.98803162")
    }

    func testSecondFunctionSwitchesToInverseTrigonometry() {
        let engine = self.engine()
        XCTAssertFalse(engine.isSecondFunction)
        engine.toggleSecondFunction()
        XCTAssertTrue(engine.isSecondFunction)

        engine.applyFunction(.arcSine)
        self.type("1", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "90")
    }

    func testLogarithms() {
        let engine = self.engine()
        engine.applyFunction(.log10)
        self.type("100", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "2")

        engine.clear()
        engine.applyFunction(.naturalLog)
        self.type("1", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "0")
    }

    func testPercent() {
        let engine = self.engine()
        self.type("50", into: engine)
        engine.applyFunction(.percent)
        engine.equals()
        XCTAssertEqual(engine.display, "0.5")
    }

    func testDivisionByZeroReportsAnErrorAndRecovers() {
        let engine = self.engine()
        self.type("1", into: engine)
        engine.setOperation(.divide)
        self.type("0", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "Ошибка")

        self.type("7", into: engine)
        XCTAssertEqual(engine.display, "7")
    }

    func testBackspace() {
        let engine = self.engine()
        self.type("123", into: engine)
        engine.backspace()
        XCTAssertEqual(engine.display, "12")
        engine.backspace()
        engine.backspace()
        XCTAssertEqual(engine.display, "0")
    }

    func testSignToggle() {
        let engine = self.engine()
        self.type("5", into: engine)
        engine.toggleSign()
        XCTAssertEqual(engine.display, "-5")
        engine.equals()
        XCTAssertEqual(engine.display, "-5")
    }

    func testMemory() {
        let engine = self.engine()
        self.type("5", into: engine)
        engine.memoryAdd()
        XCTAssertTrue(engine.hasMemory)

        engine.clear()
        self.type("2", into: engine)
        engine.setOperation(.multiply)
        engine.memoryRecall()
        engine.equals()
        XCTAssertEqual(engine.display, "10")

        engine.memoryClear()
        XCTAssertFalse(engine.hasMemory)
    }

    func testExponentEntry() {
        let engine = self.engine()
        self.type("1", into: engine)
        engine.insertExponent()
        self.type("5", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "100000")
    }

    func testDecimalsAndFormatting() {
        let engine = self.engine()
        self.type("0.1", into: engine)
        engine.setOperation(.add)
        self.type("0.2", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "0.3")

        XCTAssertEqual(AyuGramCalculatorEngine.format(4.0), "4")
        XCTAssertEqual(AyuGramCalculatorEngine.format(-12.0), "-12")
        XCTAssertEqual(AyuGramCalculatorEngine.format(0.5), "0.5")
        XCTAssertEqual(AyuGramCalculatorEngine.format(Double.nan), "Ошибка")
        XCTAssertEqual(AyuGramCalculatorEngine.format(1.0 / 3.0), "0.33333333")
    }

    func testHistoryIsCappedAndClearable() {
        let engine = self.engine()
        for _ in 0 ..< 40 {
            engine.clear()
            self.type("1", into: engine)
            engine.setOperation(.add)
            self.type("1", into: engine)
            engine.equals()
        }
        XCTAssertEqual(engine.history.count, 30)

        engine.clearHistory()
        XCTAssertTrue(engine.history.isEmpty)
    }
}
