import XCTest
@testable import Interpreter
import class Interpreter.Pattern

class TemplateTests: XCTestCase {
    func testVariable() {
        let renderer = ContextAwareRenderer(context: RenderingContext(variables: ["variable": "asd"]))
        let interpreter = StringExpressionInterpreter(statements: [ifStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("x{{ variable }}y"), "xasdy")
    }
    
    func testSet() {
        let renderer = ContextAwareRenderer(context: RenderingContext())
        let interpreter = StringExpressionInterpreter(statements: [setStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   setAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("{% set var1 %}123{% endset %}x{{ var1 }}y"), "x123y")
        XCTAssertEqual(interpreter.evaluate("{% set var2 = asd %}x{{ var2 }}y"), "xasdy")
    }
    
    func testLoop() {
        let context = RenderingContext(variables: ["array": [1, 2, 3, 4, 5]])
        let interpreter = TestInterpreterFactory().stringExpressionInterpreter(context: context)
        XCTAssertEqual(interpreter.evaluate("x{% for x from 1 to 3 %}{{ x }}{% endfor %}y"), "x123y")
        XCTAssertEqual(interpreter.evaluate("x {% for y in array %}{{ y }} {% endfor %}y"), "x 1 2 3 4 5 y")
    }
    
    func testFunctions() {
        let renderer = ContextAwareRenderer(context: RenderingContext(variables: ["x": 1]))
        let interpreter = StringExpressionInterpreter(statements: [printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer),
                                                                   inc(renderer: renderer),
                                                                   incFilter(renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("-inc(x)-"), "-2-")
        XCTAssertEqual(interpreter.evaluate("x|inc"), "2")
    }
    
    static var allTests = [
        ("testVariable", testVariable),
        ("testSet", testSet),
        ("testLoop", testLoop),
        ("testFunctions", testFunctions),
    ]
}
