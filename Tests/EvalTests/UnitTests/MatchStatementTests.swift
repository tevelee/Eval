@testable import Eval
import XCTest
import class Eval.Pattern

class MatchStatementTests: XCTestCase {

    func test_whenMatchingOne_returnsMatch() {
        let input = "input"
        let matcher = Pattern<Int, DummyInterpreter>([Keyword("in")]) { _ in 1 }

        let result1 = matcher.matches(string: input, interpreter: DummyInterpreter(), context: Context())
        let result2 = matchStatement(amongst: [matcher], in: input, interpreter: DummyInterpreter(), context: Context())

        XCTAssertTrue(result1 == result2)
    }

    func test_whenMatchingTwo_returnsMatch() {
        let input = "input"
        let matcher1 = Pattern<Int, DummyInterpreter>([Keyword("in")]) { _ in 1 }
        let matcher2 = Pattern<Int, DummyInterpreter>([Keyword("on")]) { _ in 2 }

        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: Context())

        XCTAssertTrue(result == MatchResult.exactMatch(length: 2, output: 1, variables: [:]))
    }

    func test_whenMatchingTwoMatches_returnsTheFirstMatch() {
        let input = "input"
        let matcher1 = Pattern<Int, DummyInterpreter>([Keyword("in")]) { _ in 1 }
        let matcher2 = Pattern<Int, DummyInterpreter>([Keyword("inp")]) { _ in 2 }

        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: Context())

        XCTAssertTrue(result == MatchResult.exactMatch(length: 2, output: 1, variables: [:]))
    }

    func test_whenMatchingInvalid_returnsNoMatch() {
        let input = "xxx"
        let matcher1 = Pattern<Int, DummyInterpreter>([Keyword("in")]) { _ in 1 }
        let matcher2 = Pattern<Int, DummyInterpreter>([Keyword("on")]) { _ in 2 }

        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: Context())

        XCTAssertTrue(result == MatchResult.noMatch)
    }

    func test_whenMatchingPrefix_returnsPossibleMatch() {
        let input = "i"
        let matcher1 = Pattern<Int, DummyInterpreter>([Keyword("in")]) { _ in 1 }
        let matcher2 = Pattern<Int, DummyInterpreter>([Keyword("on")]) { _ in 2 }

        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: Context())

        XCTAssertTrue(result == MatchResult.possibleMatch)
    }
}
