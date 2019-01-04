@testable import Eval
import XCTest

class TypedInterpreterTests: XCTestCase {

    // MARK: init

    func test_whenInitialised_thenPropertiesAreSaved() {
        let dataTypes = [DataType(type: String.self, literals: []) { $0.value }]
        let functions = [Function([Keyword("a")]) { _ in "a" } ]
        let context = Context()

        let interpreter = TypedInterpreter(dataTypes: dataTypes,
                                           functions: functions,
                                           context: context)

        XCTAssertEqual(interpreter.dataTypes.count, 1)
        XCTAssertTrue(dataTypes[0] === interpreter.dataTypes[0] as! DataType<String>)

        XCTAssertEqual(interpreter.functions.count, 1)
        XCTAssertTrue(functions[0] === interpreter.functions[0] as! Function<String>)

        XCTAssertTrue(context === interpreter.context)
    }

    // MARK: evaluate

    func test_whenEvaluates_thenTransformationHappens() {
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }],
                                           functions: [Function([Variable<Int>("lhs"), Keyword("plus"), Variable<Int>("rhs")]) { ($0.variables["lhs"] as! Int) + ($0.variables["rhs"] as! Int) } ],
                                           context: Context())

        let result = interpreter.evaluate("1 plus 2")

        XCTAssertEqual(result as! Int, 3)
    }

    func test_whenEvaluates_thenUsesGlobalContext() {
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }],
                                           functions: [Function([Variable<Int>("lhs"), Keyword("plus"), Variable<Int>("rhs")]) { ($0.variables["lhs"] as! Int) + ($0.variables["rhs"] as! Int) } ],
                                           context: Context(variables: ["a": 2]))

        let result = interpreter.evaluate("1 plus a")

        XCTAssertEqual(result as! Int, 3)
    }

    // MARK: evaluate with context

    func test_whenEvaluatesWithContext_thenUsesLocalContext() {
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }],
                                           functions: [Function([Variable<Int>("lhs"), Keyword("plus"), Variable<Int>("rhs")]) { ($0.variables["lhs"] as! Int) + ($0.variables["rhs"] as! Int) } ],
                                           context: Context())

        let result = interpreter.evaluate("1 plus a", context: Context(variables: ["a": 2]))

        XCTAssertEqual(result as! Int, 3)
    }

    func test_whenEvaluatesWithContext_thenLocalOverridesGlobalContext() {
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }],
                                           functions: [Function([Variable<Int>("lhs"), Keyword("plus"), Variable<Int>("rhs")]) { ($0.variables["lhs"] as! Int) + ($0.variables["rhs"] as! Int) } ],
                                           context: Context(variables: ["a": 1]))

        let result = interpreter.evaluate("1 plus a", context: Context(variables: ["a": 2]))

        XCTAssertEqual(result as! Int, 3)
    }

    // MARK: print

    func test_whenPrintingDataType_thenReturnsItsBlock() {
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }],
                                           functions: [],
                                           context: Context())

        let result = interpreter.print(1)

        XCTAssertEqual(result, "1")
    }

    func test_whenPrintingUnknownDataType_thenReturnsDescription() {
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }],
                                           functions: [],
                                           context: Context())

        let result = interpreter.print(true)

        XCTAssertEqual(result, true.description)
    }
}
