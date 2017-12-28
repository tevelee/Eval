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
        XCTAssertEqual(interpreter.evaluate("x{{ variable }}y"), "xasdy")
    }
    
    func testSet() {
        let platform = RenderingPlatform()
        _ = platform.add(capability: ContextHandler.self)
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        
        let interpreter = StringExpressionInterpreter(statements: [stringInterpreterFactory.setStatement(tagPrefix: "{%", tagSuffix: "%}"),
                                                                   stringInterpreterFactory.setAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}"),
                                                                   stringInterpreterFactory.printStatement(tagPrefix: "{{", tagSuffix: "}}")])
        XCTAssertEqual(interpreter.evaluate("{% set var1 %}123{% endset %}x{{ var1 }}y"), "x123y")
        XCTAssertEqual(interpreter.evaluate("{% set var2 = asd %}x{{ var2 }}y"), "xasdy")
    }
    
    func testLoop() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        
        contextHandler.context.variables["array"] = [1, 2, 3, 4, 5]
        
        let interpreter = stringInterpreterFactory.stringExpressionInterpreter()
        XCTAssertEqual(interpreter.evaluate("x{% for x from 1 to 3 %}{{ x }}{% endfor %}y"), "x123y")
        XCTAssertEqual(interpreter.evaluate("x {% for y in array %}{{ y }} {% endfor %}y"), "x 1 2 3 4 5 y")
    }
    
    func testFunctions() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let contextHandler = platform.add(capability: ContextHandler.self)
        
        contextHandler.context.variables["x"] = 1
        
        let interpreter = StringExpressionInterpreter(statements: [stringInterpreterFactory.printStatement(tagPrefix: "{{", tagSuffix: "}}"),
                                                                   stringInterpreterFactory.inc(),
                                                                   stringInterpreterFactory.incFilter()])
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
