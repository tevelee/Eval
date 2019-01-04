@testable import Eval
import XCTest

class DataTypeTests: XCTestCase {

    // MARK: init

    func test_whenInitialised_then() {
        let type = Double.self
        let literal = Literal { Double($0.value) }
        let print: (DataTypeBody<Double>) -> String = { String($0.value) }

        let dataType = DataType(type: type, literals: [literal], print: print)

        XCTAssertTrue(type == dataType.type.self)
        XCTAssertTrue(literal === dataType.literals[0])
        XCTAssertNotNil(dataType.print)
    }

    // MARK: convert

    func test_whenConverting_thenGeneratesStringValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { Double($0.value) }]) { String($0.value) }

        let result = dataType.convert(input: "1", interpreter: TypedInterpreter())

        XCTAssertEqual(result as! Double, 1)
    }

    func test_whenConvertingInvalidValue_thenGeneratesNilValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { Double($0.value) }]) { String($0.value) }

        let result = dataType.convert(input: "a", interpreter: TypedInterpreter())

        XCTAssertNil(result)
    }

    // MARK: print

    func test_whenPrinting_thenGeneratesStringValue() {
        let dataType = DataType(type: Double.self, literals: [Literal { Double($0.value) }]) { _ in "printed value" }

        let result = dataType.print(value: 1.0, printer: TypedInterpreter())

        XCTAssertEqual(result, "printed value")
    }
}
