import XCTest
@testable import Interpreter
import class Interpreter.Pattern

class TemplateTests: XCTestCase {
    func testVariable() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        
        contextHandler.context.variables["variable"] = "asd"
        
        let interpreter = StringExpressionInterpreter(statements: [stringInterpreterFactory.ifStatement(tagPrefix: "{%", tagSuffix: "%}"),
                                                                   stringInterpreterFactory.printStatement(tagPrefix: "{{", tagSuffix: "}}")])
        XCTAssertEqual(try! interpreter.evaluate("x{{ variable }}y"), "xasdy")
    }
    
    func testSet() {
        let platform = RenderingPlatform()
        _ = platform.add(capability: ContextHandler.self)
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        
        let interpreter = StringExpressionInterpreter(statements: [stringInterpreterFactory.setStatement(tagPrefix: "{%", tagSuffix: "%}"),
                                                                   stringInterpreterFactory.setAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}"),
                                                                   stringInterpreterFactory.printStatement(tagPrefix: "{{", tagSuffix: "}}")])
        XCTAssertEqual(try! interpreter.evaluate("{% set var1 %}123{% endset %}x{{ var1 }}y"), "x123y")
        XCTAssertEqual(try! interpreter.evaluate("{% set var2 = asd %}x{{ var2 }}y"), "xasdy")
    }
    
    func testLoop() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        
        contextHandler.context.variables["array"] = [1, 2, 3, 4, 5]
        
        let interpreter = stringInterpreterFactory.stringExpressionInterpreter()
        XCTAssertEqual(try! interpreter.evaluate("x{% for x from 1 to 3 %}{{ x }}{% endfor %}y"), "x123y")
        XCTAssertEqual(try! interpreter.evaluate("x {% for y in array %}{{ y }} {% endfor %}y"), "x 1 2 3 4 5 y")
    }
    
    func testFunctions() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        
        contextHandler.context.variables["x"] = 1
        
        let interpreter = StringExpressionInterpreter(statements: [stringInterpreterFactory.printStatement(tagPrefix: "{{", tagSuffix: "}}"),
                                                                   stringInterpreterFactory.inc(),
                                                                   stringInterpreterFactory.incFilter()])
        XCTAssertEqual(try! interpreter.evaluate("-inc(x)-"), "-2-")
        XCTAssertEqual(try! interpreter.evaluate("x|inc"), "2")
    }
    
    func testComputations() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        let _ = platform.add(capability: BooleanInterpreterFactory.self)
        let _ = platform.add(capability: NumericInterpreterFactory.self)
        
        let interpreter = stringInterpreterFactory.stringExpressionInterpreter()
        XCTAssertEqual(try! interpreter.evaluate("{{ 5 * 17 }}"), "85")
        XCTAssertEqual(try! interpreter.evaluate("The answer is: {{ 2 * 3.6 }}!"), "The answer is: 7.2!")
        XCTAssertEqual(try! interpreter.evaluate("{% if 12 >= 5 %}asd{% endif %}"), "asd")
        XCTAssertEqual(try! interpreter.evaluate("{% if 12 / 2 + 1 >= 6 % 2 %}asd{% endif %}"), "asd")
        XCTAssertEqual(try! interpreter.evaluate("{% set var = 12 %}x{{ var * 2 }}y"), "x24y")
        
        contextHandler.context.variables["test"] = 13
        XCTAssertEqual(try! interpreter.evaluate("{{ test + 2 }}"), "15")
        XCTAssertEqual(try! interpreter.evaluate("{{ sqrt(max(test, 25)) }}"), "5")
        XCTAssertEqual(try! interpreter.evaluate("{{ -1 }}"), "-1")
    }
    
    func testConditions() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        let _ = platform.add(capability: BooleanInterpreterFactory.self)
        let _ = platform.add(capability: NumericInterpreterFactory.self)
        
        let interpreter = stringInterpreterFactory.stringExpressionInterpreter()
        
        contextHandler.context.variables["c"] = "0"
        XCTAssertEqual(try! interpreter.evaluate("{% if !c %}asd{% endif %}"), "asd")
        XCTAssertEqual(try! interpreter.evaluate("{% if 0 == c %}asd{% endif %}"), "asd")
    }
    
    static var allTests = [
        ("testVariable", testVariable),
        ("testSet", testSet),
        ("testLoop", testLoop),
        ("testFunctions", testFunctions),
    ]
}
