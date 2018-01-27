import XCTest
@testable import Eval

class FunctionTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialised_thenPatternsAreSaved() {
        let pattern = Pattern<Int, TypedInterpreter>([Keyword("in")]) { _, _, _ in 1 }
        
        let function = Function(patterns: [pattern])
        
        XCTAssertEqual(function.patterns.count, 1)
        XCTAssertTrue(pattern === function.patterns[0])
    }
    
    func test_whenInitialisedWithOnePatters_thenPatternIsSaved() {
        let pattern = [Keyword("in")]
        
        let function = Function(pattern) { _, _, _ in 1 }
        
        XCTAssertEqual(function.patterns.count, 1)
        XCTAssertEqual(function.patterns[0].elements.count, 1)
        XCTAssertTrue(pattern[0] === function.patterns[0].elements[0] as! Keyword)
    }
    
    //MARK: convert
    
    func test_whenConverting_thenResultIsValid() {
        let function = Function([Keyword("in")]) { _, _, _ in 1 }
        
        let result = function.convert(input: "input", interpreter: TypedInterpreter(), context: Context())
        
        XCTAssertEqual(result as! Int, 1)
    }
    
    func test_whenConvertingInvalidValue_thenConversionReturnsNil() {
        let function = Function([Keyword("in")]) { _, _, _ in 1 }
        
        let result = function.convert(input: "example", interpreter: TypedInterpreter(), context: Context())
        
        XCTAssertNil(result)
    }
}
