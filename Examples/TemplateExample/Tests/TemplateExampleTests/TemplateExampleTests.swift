import XCTest
import Eval
@testable import TemplateExample

class TemplateExampleTests: XCTestCase {
    func testExample() {
        XCTAssertEqual(eval("{% if x in [1,2,3] %}Hello{% else %}Bye{% endif %} {{ name }}!", ["x": 2.0, "name": "Teve"]), "Hello Teve!")
    }
    
    func eval(_ template: String, _ variables: [String: Any]) -> String {
        return TemplateLanguage().evaluate(template, context: InterpreterContext(variables: variables))
    }
}
