import XCTest
@testable import Eval

class MatchStatementTests: XCTestCase {

    func test_whenMatchingOne_returnsMatch() {
        let input = "input"
        let matcher = Matcher<Int, DummyInterpreter>([Keyword("in")]) { _,_,_ in 1 }
        
        let result1 = matcher.matches(string: input, interpreter: DummyInterpreter(), context: InterpreterContext())
        let result2 = matchStatement(amongst: [matcher], in: input, interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertTrue(result1 == result2)
    }
    
    func test_whenMatchingTwo_returnsMatch() {
        let input = "input"
        let matcher1 = Matcher<Int, DummyInterpreter>([Keyword("in")]) { _,_,_ in 1 }
        let matcher2 = Matcher<Int, DummyInterpreter>([Keyword("on")]) { _,_,_ in 2 }
        
        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertTrue(result == MatchResult.exactMatch(length: 2, output: 1, variables: [:]))
    }
    
    func test_whenMatchingTwoMatches_returnsTheFirstMatch() {
        let input = "input"
        let matcher1 = Matcher<Int, DummyInterpreter>([Keyword("in")]) { _,_,_ in 1 }
        let matcher2 = Matcher<Int, DummyInterpreter>([Keyword("inp")]) { _,_,_ in 2 }
        
        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertTrue(result == MatchResult.exactMatch(length: 2, output: 1, variables: [:]))
    }
    
    func test_whenMatchingInvalid_returnsNoMatch() {
        let input = "xxx"
        let matcher1 = Matcher<Int, DummyInterpreter>([Keyword("in")]) { _,_,_ in 1 }
        let matcher2 = Matcher<Int, DummyInterpreter>([Keyword("on")]) { _,_,_ in 2 }
        
        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertTrue(result == MatchResult.noMatch)
    }
    
    func test_whenMatchingPrefix_returnsPossibleMatch() {
        let input = "i"
        let matcher1 = Matcher<Int, DummyInterpreter>([Keyword("in")]) { _,_,_ in 1 }
        let matcher2 = Matcher<Int, DummyInterpreter>([Keyword("on")]) { _,_,_ in 2 }
        
        let result = matchStatement(amongst: [matcher1, matcher2], in: input, interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertTrue(result == MatchResult.possibleMatch)
    }
}
