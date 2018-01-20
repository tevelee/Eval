import XCTest
@testable import Eval

class DataTypeTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialised_then() {
        let type = Double.self
        let literal = Literal { value, _ in Double(value) }
        let print : (Double, Printer) -> String = { value, _ in String(value) }
        
        let dataType = DataType(type: type, literals: [literal], print: print)
        
        XCTAssertTrue(type == dataType.type.self)
        XCTAssertTrue(literal === dataType.literals[0])
        XCTAssertNotNil(dataType.print)
    }
    
    //MARK: convert
    
    func test_whenConverting_thenGeneratesStringValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { value, _ in Double(value) }]) { value, _ in String(value) }
        
        let result = dataType.convert(input: "1", interpreter: TypedInterpreter())
        
        XCTAssertEqual(result as! Double, 1)
    }
    
    func test_whenConvertingInvalidValue_thenGeneratesNilValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { value,_ in Double(value) }]) { value, _ in String(value) }
        
        let result = dataType.convert(input: "a", interpreter: TypedInterpreter())
        
        XCTAssertNil(result)
    }
    
    //MARK: print
    
    func test_whenPrinting_thenGeneratesStringValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { value, _ in Double(value) }]) { value, _ in "printed value" }
        
        let result = dataType.print(1, TypedInterpreter())
        
        XCTAssertEqual(result, "printed value")
    }
}
