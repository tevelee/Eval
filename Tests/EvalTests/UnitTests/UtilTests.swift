@testable import Eval
import XCTest

class UtilTests: XCTestCase {

    // MARK: plus operator on Elements

    class DummyX: PatternElement, Equatable {
        func matches(prefix: String, options: PatternOptions) -> MatchResult<Any> { return .noMatch }
        static func == (lhs: DummyX, rhs: DummyX) -> Bool { return true }
    }

    class DummyY: PatternElement, Equatable {
        func matches(prefix: String, options: PatternOptions) -> MatchResult<Any> { return .possibleMatch }
        static func == (lhs: DummyY, rhs: DummyY) -> Bool { return true }
    }

    func test_whenApplyingPlusOperatorOnElements_thenItCreatedAnArray() {
        let element1 = DummyX()
        let element2 = DummyY()

        let result = element1 + element2

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0] as! DummyX, element1)
        XCTAssertEqual(result[1] as! DummyY, element2)
    }

    // MARK: plus operator on Array

    func test_whenApplyingPlusOperatorOnArrayWithItem_thenItCreatesAMergedArray() {
        let result = [1, 2, 3] + 4

        XCTAssertEqual(result, [1, 2, 3, 4])
    }

    func test_whenApplyingPlusEqualsOperatorOnArrayWithItem_thenItCreatesAMergedArray() {
        var array = [1, 2, 3]
        array += 4

        XCTAssertEqual(array, [1, 2, 3, 4])
    }

    // MARK: String trim

    func test_whenTrimminString_thenRemovesWhitespaces() {
        XCTAssertEqual("   asd   ".trim(), "asd")
        XCTAssertEqual(" \t  asd \n  ".trim(), "asd")
    }
}
