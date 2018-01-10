import XCTest
@testable import Eval

class DataTypeTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialised_then() {
        let type = Double.self
        let literal = Literal { value, _ in Double(value) }
        let print : (Double) -> String = { String($0) }
        
        let dataType = DataType(type: type, literals: [literal], print: print)
        
        XCTAssertTrue(type == dataType.type.self)
        XCTAssertTrue(literal === dataType.literals[0])
        XCTAssertNotNil(dataType.print)
    }
    
    //MARK: convert
    
    func test_whenConverting_thenGeneratesStringValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { value, _ in Double(value) }]) { String($0) }
        
        let result = dataType.convert(input: "1", interpreter: TypedInterpreter())
        
        XCTAssertEqual(result as! Double, 1)
    }
    
    func test_whenConvertingInvalidValue_thenGeneratesNilValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { value, _ in Double(value) }]) { String($0) }
        
        let result = dataType.convert(input: "a", interpreter: TypedInterpreter())
        
        XCTAssertNil(result)
    }
    
    //MARK: print
    
    func test_whenPrinting_thenGeneratesStringValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { value, _ in Double(value) }]) { _ in "printed value" }
        
        let result = dataType.print(1)
        
        XCTAssertEqual(result, "printed value")
    }
}
