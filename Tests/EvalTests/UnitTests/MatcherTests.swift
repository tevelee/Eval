import XCTest
@testable import Eval

class MatcherTests: XCTestCase {

    //MARK: init
    
    class DummyElement : MatchElement {
        func matches(prefix: String) -> MatchResult<Any> {
            return .noMatch
        }
    }
    
    func test_whenInitialised_thenElementsAndMatcherAreSet() {
        let element = DummyElement()
        let matcherBlock : MatcherBlock<Int, DummyInterpreter> = { _,_,_ in 1 }
        
        let matcher = Matcher<Int, DummyInterpreter>([element], matcher: matcherBlock)
        
        XCTAssertTrue(element === matcher.elements[0] as! DummyElement)
        //XCTAssertTrue(matcherBlock === matcher.matcher)
    }
    
    func test_whenInitialisedWithVariableOnTheLastPlace_thenLastVariableBecomesNotShortest() {
        let element = DummyElement()
        let variable = GenericVariable<String, DummyInterpreter>("name", shortest: true)
        
        let matcher = Matcher<String, DummyInterpreter>([element, variable]) { _,_,_ in "x" }
        
        let result = matcher.elements[1] as! GenericVariable<String, DummyInterpreter>
        XCTAssertTrue(element === matcher.elements[0] as! DummyElement)
        XCTAssertFalse(variable === result)
        XCTAssertTrue(result.shortest == false)
    }
    
    //MARK: matches
    
    func test_whenMatching_thenExpectingAppropriateResults() {
        typealias TestCase = (elements: [MatchElement], input: String, expectedResult: MatchResult<Int>)
        
        let keyword = Keyword("ok")
        let variable = GenericVariable<String, DummyInterpreter>("name", shortest: true, interpreted: false)
        let variableLongest = GenericVariable<String, DummyInterpreter>("name", shortest: false, interpreted: false)
        let variable2 = GenericVariable<String, DummyInterpreter>("last", shortest: true, interpreted: false)
        
        let testCases : [TestCase] = [
            ([keyword], "invalid", .noMatch),
            ([keyword], "o", .possibleMatch),
            ([keyword], "ok", .exactMatch(length: 2, output: 1, variables: [:])),
            ([keyword], "okokok", .exactMatch(length: 2, output: 1, variables: [:])),

            ([variable], "anything", .exactMatch(length: 8, output: 1, variables: ["name": "anything"])),
            ([variableLongest], "anything", .exactMatch(length: 8, output: 1, variables: ["name": "anything"])),

            ([variable, keyword], "invalid", .possibleMatch),
            ([variable, keyword], "invalid o", .possibleMatch),
            ([variable, keyword], "invalid ok", .exactMatch(length: 10, output: 1, variables: ["name": "invalid"])),
            ([variable, keyword], "invalidxok", .exactMatch(length: 10, output: 1, variables: ["name": "invalidx"])),
            ([variable, keyword], "invalidxok extra", .exactMatch(length: 10, output: 1, variables: ["name": "invalidx"])),

            ([keyword, variable], "xokthen", .noMatch),
            ([keyword, variable], "o", .possibleMatch),
            ([keyword, variable], "oi", .noMatch),
            ([keyword, variable], "ok", .exactMatch(length: 2, output: 1, variables: ["name": ""])),
            ([keyword, variable], "ok then", .exactMatch(length: 7, output: 1, variables: ["name": "then"])),
            ([keyword, variable], "ok,then", .exactMatch(length: 7, output: 1, variables: ["name": ",then"])),
            
            ([keyword, variable, keyword], "o", .possibleMatch),
            ([keyword, variable, keyword], "ok", .possibleMatch),
            ([keyword, variable, keyword], "oko", .possibleMatch),
            ([keyword, variable, keyword], "okok", .exactMatch(length: 4, output: 1, variables: ["name": ""])),
            ([keyword, variable, keyword], "okxok", .exactMatch(length: 5, output: 1, variables: ["name": "x"])),
            ([keyword, variable, keyword], "okokok", .exactMatch(length: 4, output: 1, variables: ["name": ""])),
            ([keyword, variableLongest, keyword], "ok", .possibleMatch),
            ([keyword, variableLongest, keyword], "okx", .possibleMatch),
            ([keyword, variableLongest, keyword], "oko", .possibleMatch),

//FIXME: Don't know why. Need to evaluate
//            ([keyword, variableLongest, keyword], "okok", .exactMatch(length: 4, output: 1, variables: ["name": ""])),
//            ([keyword, variableLongest, keyword], "okxok", .exactMatch(length: 5, output: 1, variables: ["name": "x"])),
            
            ([variable, keyword, variable2], "xo", .possibleMatch),
            ([variable, keyword, variable2], "xok", .exactMatch(length: 3, output: 1, variables: ["name": "x", "last": ""])),
            ([variable, keyword, variable2], "xoky", .exactMatch(length: 4, output: 1, variables: ["name": "x", "last": "y"])),
            ([variable, keyword, variable2], "xoky and rest", .exactMatch(length: 13, output: 1, variables: ["name": "x", "last": "y and rest"])),
            ([variable, keyword, variable2], "xokoky", .exactMatch(length: 6, output: 1, variables: ["name": "x", "last": "oky"])),
        ]
        
        for testCase in testCases {
            let matcher = Matcher<Int, DummyInterpreter>(testCase.elements) { _,_,_ in 1 }
            let result = matcher.matches(string: testCase.input, interpreter: DummyInterpreter(), context: InterpreterContext())
            XCTAssertTrue(result == testCase.expectedResult, "\(testCase.input) should have resulted in \(testCase.expectedResult) but got \(result) instead")
        }
    }
    
    //MARK: finaliseVariable
    
    func test_whenFinalisingValue_thenItCorrectlyReturnsValue() {
        let matcher = Matcher<Int, DummyInterpreter>([]) { _,_,_ in 1 }
        let variable = GenericVariable<String, DummyInterpreter>("name", interpreted: false)
        
        let result = matcher.finaliseVariable((metadata: variable, value: "value"), interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertEqual(result as! String, "value")
    }
    
    func test_whenFinalisingInterpretedValue_thenItReturnsInterpretation() {
        let matcher = Matcher<Int, DummyInterpreter>([]) { _,_,_ in 1 }
        let variable = GenericVariable<String, DummyInterpreter>("name", interpreted: true)
        
        let result = matcher.finaliseVariable((metadata: variable, value: "value"), interpreter: DummyInterpreter(), context: InterpreterContext())
        
        XCTAssertEqual(result as! String, "a")
    }
    
    //MARK: isEmbedded
    
    func test_whenEmbedding_thenIsEmbeddedReturnsTrue() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let matcher = Matcher<Int, DummyInterpreter>([opening, closing]) { _,_,_ in 1 }
        
        let result = matcher.isEmbedded(element: closing, in: "(input(random))", at: 0)
        
        XCTAssertTrue(result)
    }
    
    func test_whenNotEmbedding_thenIsEmbeddedReturnsFalse() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let matcher = Matcher<Int, DummyInterpreter>([opening, closing]) { _,_,_ in 1 }
        
        let result = matcher.isEmbedded(element: opening, in: "input", at: 0)
        
        XCTAssertFalse(result)
    }
    
    func test_whenEmbeddingButLate_thenIsEmbeddedReturnsFalse() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let matcher = Matcher<Int, DummyInterpreter>([opening, closing]) { _,_,_ in 1 }
        
        let result = matcher.isEmbedded(element: closing, in: "input(random)", at: 25)
        
        XCTAssertFalse(result)
    }
    
    //MARK: positionOfClosingTag
    
    func test_whenEmbedding_thenClosingPositionIsValid() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let matcher = Matcher<Int, DummyInterpreter>([opening, closing]) { _,_,_ in 1 }
        
        XCTAssertEqual(matcher.positionOfClosingTag(in: "(input(random))", from: 0), 14)
        XCTAssertEqual(matcher.positionOfClosingTag(in: "(input(random))", from: 1), 13)
    }
    
    func test_whenNotEmbedding_thenClosingPositionIsNil() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let matcher = Matcher<Int, DummyInterpreter>([opening, closing]) { _,_,_ in 1 }
        
        XCTAssertNil(matcher.positionOfClosingTag(in: "input", from: 0))
    }
    
    func test_whenEmbeddingButLate_thenClosingPositionIsNil() {
        let opening = Keyword("(", type: .openingStatement)
        let closing = Keyword(")", type: .closingStatement)
        let matcher = Matcher<Int, DummyInterpreter>([opening, closing]) { _,_,_ in 1 }
        
        XCTAssertNil(matcher.positionOfClosingTag(in: "(input(random))", from: 8))
    }
}
