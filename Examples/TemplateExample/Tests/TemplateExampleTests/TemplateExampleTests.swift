import XCTest
import Eval
@testable import TemplateExample

class TemplateExampleTests: XCTestCase {
    let interpreter = TemplateLanguage()
    
    func testExample() {
        XCTAssertEqual(eval("{% if x in [1,2,3] %}Hello{% else %}Bye{% endif %} {{ name }}!", ["x": 2.0, "name": "Teve"]), "Hello Teve!")
    }
    
    func testContextModification() {
        _ = eval("{% set x = 4.0 %}")
        XCTAssertEqual(eval("{{ x }}"), "4.0")
    }
    
    func eval(_ template: String, _ variables: [String: Any] = [:]) -> String {
        return interpreter.evaluate(template, context: InterpreterContext(variables: variables))
    }
}
