@testable import Eval
import XCTest

class MatcherTests: XCTestCase {

    // MARK: isEmbedded

    func test_whenEmbedding_thenIsEmbeddedReturnsTrue() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(elements: [opening, closing], processor: processor, options: [])

        let result = matcher.isEmbedded(element: closing, in: "(input(random))", at: 0)

        XCTAssertTrue(result)
    }

    func test_whenNotEmbedding_thenIsEmbeddedReturnsFalse() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(elements: [opening, closing], processor: processor, options: [])

        let result = matcher.isEmbedded(element: opening, in: "input", at: 0)

        XCTAssertFalse(result)
    }

    func test_whenEmbeddingButLate_thenIsEmbeddedReturnsFalse() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(elements: [opening, closing], processor: processor, options: [])

        let result = matcher.isEmbedded(element: closing, in: "input(random)", at: 25)

        XCTAssertFalse(result)
    }

    // MARK: positionOfClosingTag

    func test_whenEmbedding_thenClosingPositionIsValid() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(elements: [opening, closing], processor: processor, options: [])

        XCTAssertEqual(matcher.positionOfClosingTag(in: "(input(random))", from: 0), 14)
        XCTAssertEqual(matcher.positionOfClosingTag(in: "(input(random))", from: 1), 13)
    }

    func test_whenNotEmbedding_thenClosingPositionIsNil() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(elements: [opening, closing], processor: processor, options: [])

        XCTAssertNil(matcher.positionOfClosingTag(in: "input", from: 0))
    }

    func test_whenEmbeddingButLate_thenClosingPositionIsNil() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(elements: [opening, closing], processor: processor, options: [])

        XCTAssertNil(matcher.positionOfClosingTag(in: "(input(random))", from: 8))
    }
}
