import XCTest
@testable import TelegramCore

final class AyuGramCalculatorTests: XCTestCase {
    private func engine(code: String = "2024") -> AyuGramCalculatorEngine {
        let engine = AyuGramCalculatorEngine()
        engine.unlockCode = code
        return engine
    }

    private func type(_ digits: String, into engine: AyuGramCalculatorEngine) {
        for character in digits {
            if character == "." {
                engine.decimalPoint()
            } else {
                engine.input(digit: String(character))
            }
        }
    }

    func testAdditionAndRepeatedEquals() {
        let engine = self.engine()
        self.type("2", into: engine)
        engine.setOperation(.add)
        self.type("2", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "4")

        // A second "=" repeats the last operation, like the iOS calculator.
        engine.equals()
        XCTAssertEqual(engine.display, "6")
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

    func testCodeAfterClearUnlocksOnce() {
        let engine = self.engine()
        var unlocked = 0
        engine.onUnlock = { unlocked += 1 }

        self.type("2024", into: engine)
        engine.equals()
        engine.clear()
        self.type("2024", into: engine)
        engine.equals()

        XCTAssertEqual(unlocked, 2)
    }

    func testWrongCodeStaysACalculator() {
        let engine = self.engine()
        var unlocked = 0
        engine.onUnlock = { unlocked += 1 }

        self.type("2023", into: engine)
        engine.equals()

        XCTAssertEqual(unlocked, 0)
        XCTAssertEqual(engine.display, "2023")
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

    func testDecimalsNegateAndPercent() {
        let engine = self.engine()
        self.type("0.1", into: engine)
        engine.setOperation(.add)
        self.type("0.2", into: engine)
        engine.equals()
        XCTAssertEqual(engine.display, "0.3")

        engine.clear()
        self.type("50", into: engine)
        engine.percent()
        XCTAssertEqual(engine.display, "0.5")

        engine.clear()
        self.type("12", into: engine)
        engine.negate()
        XCTAssertEqual(engine.display, "-12")
        engine.negate()
        XCTAssertEqual(engine.display, "12")
    }

    func testLeadingZeroIsReplaced() {
        let engine = self.engine()
        self.type("0", into: engine)
        self.type("5", into: engine)
        XCTAssertEqual(engine.display, "5")
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

    func testFormatting() {
        XCTAssertEqual(AyuGramCalculatorEngine.format(4.0), "4")
        XCTAssertEqual(AyuGramCalculatorEngine.format(-12.0), "-12")
        XCTAssertEqual(AyuGramCalculatorEngine.format(0.5), "0.5")
        XCTAssertEqual(AyuGramCalculatorEngine.format(Double.nan), "Ошибка")
        XCTAssertEqual(AyuGramCalculatorEngine.format(1.0 / 3.0), "0.33333333")
    }
}
