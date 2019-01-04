@testable import Eval
import XCTest

class LiteralTests: XCTestCase {

    // MARK: init

    func test_whenInitialisedWithBlock_thenParameterIsSaved() {
        let block: (LiteralBody) -> Double? = { Double($0.value) }

        let literal = Literal(convert: block)

        XCTAssertNotNil(literal.convert)
    }

    func test_whenInitialisedWithValue_thenConvertBlockIsSaved() {
        let literal = Literal("true", convertsTo: false)

        XCTAssertNotNil(literal.convert)
    }

    // MARK: convert

    func test_whenConverting_thenCallsBlock() {
        let block: (LiteralBody) -> Int? = { _ in 123 }
        let literal = Literal(convert: block)

        let result = literal.convert(input: "asd", interpreter: TypedInterpreter())

        XCTAssertEqual(result!, 123)
    }
}
