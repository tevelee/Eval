@testable import Eval
import XCTest

class MatcherTests: XCTestCase {

    // MARK: isEmbedded

    func test_whenEmbedding_thenIsEmbeddedReturnsTrue() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(pattern: pattern([opening, closing]), processor: processor)

        let input = "(input(random))"
        let result = matcher.isEmbedded(element: closing, in: input, at: input.startIndex)

        XCTAssertTrue(result)
    }

    func test_whenNotEmbedding_thenIsEmbeddedReturnsFalse() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(pattern: pattern([opening, closing]), processor: processor)

        let input = "input"
        let result = matcher.isEmbedded(element: opening, in: input, at: input.startIndex)

        XCTAssertFalse(result)
    }

    func test_whenEmbeddingButLate_thenIsEmbeddedReturnsFalse() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(pattern: pattern([opening, closing]), processor: processor)

        let input = "input(random)"
        let result = matcher.isEmbedded(element: closing, in: input, at: input.index(input.startIndex, offsetBy: 12))

        XCTAssertFalse(result)
    }

    // MARK: positionOfClosingTag

    func test_whenEmbedding_thenClosingPositionIsValid() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(pattern: pattern([opening, closing]), processor: processor)

        let input = "(input(random))"
        XCTAssertEqual(matcher.positionOfClosingTag(in: input, from: input.startIndex), input.index(input.startIndex, offsetBy: 14))
        XCTAssertEqual(matcher.positionOfClosingTag(in: input, from: input.index(after: input.startIndex)), input.index(input.startIndex, offsetBy: 13))
    }

    func test_whenNotEmbedding_thenClosingPositionIsNil() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(pattern: pattern([opening, closing]), processor: processor)

        let input = "input"
        XCTAssertNil(matcher.positionOfClosingTag(in: input, from: input.startIndex))
    }

    func test_whenEmbeddingButLate_thenClosingPositionIsNil() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())
        let matcher = Matcher(pattern: pattern([opening, closing]), processor: processor)

        let input = "(input(random))"
        XCTAssertNil(matcher.positionOfClosingTag(in: input, from: input.index(input.startIndex, offsetBy: 8)))
    }

    private func pattern(_ elements: [PatternElement]) -> Eval.Pattern<Any, DummyInterpreter> {
        return Pattern(elements) { _ in "" }
    }
}
