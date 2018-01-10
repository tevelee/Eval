import XCTest
@testable import Eval

class LiteralTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialisedWithBlock_thenParameterIsSaved() {
        let block : (String, TypedInterpreter) -> Double? = { value, _ in Double(value) }
        
        let literal = Literal(convert: block)
        
        XCTAssertNotNil(literal.convert)
    }
    
    func test_whenInitialisedWithValue_thenConvertBlockIsSaved() {
        let literal = Literal("true", convertsTo: false)
        
        XCTAssertNotNil(literal.convert)
    }
    
    //MARK: convert
    
    func test_whenConverting_thenCallsBlock() {
        let block : (String, TypedInterpreter) -> Int? = { _, _ in 123 }
        let literal = Literal(convert: block)
        
        let result = literal.convert(input: "asd", interpreter: TypedInterpreter())
        
        XCTAssertEqual(result!, 123)
    }
}
