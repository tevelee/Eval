import XCTest
import Interpreter
@testable import TemplateExample

class TemplateExampleTests: XCTestCase {
    func testExample() {
        XCTAssertEqual(eval("{% if x < 5 %}Hello{% endif %}!", ["x": 2.0]), "Hello!")
    }
    
    func eval(_ template: String, _ variables: [String: Any]) -> String {
        return TemplateLanguage().evaluate(template, context: InterpreterContext(variables: variables))
    }
}
