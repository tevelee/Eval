import XCTest
import Eval
@testable import TemplateExample

class TemplateExampleComponentTests: XCTestCase {
    let interpreter = TemplateLanguage()
    
    func testComplexExample() {
        XCTAssertEqual(eval(
"""
    {% if greet %}Hello{% else %}Bye{% endif %} {{ name }}!
    {% set works = true %}
    {% for i in [3,2,1] %}{{ i }}, {% endfor %}go!
    
    This template engine {% if !works %}does not {% endif %}work{% if works %}s{% endif %}!
""", ["greet": true, "name": "Laszlo"]),
"""
    Hello Laszlo!
    
    3, 2, 1, go!
    
    This template engine works!
""")
    }
    
    //MARK: Helpers
    
    func eval(_ template: String, _ variables: [String: Any] = [:]) -> String {
        let context = InterpreterContext(variables: variables)
        let result = interpreter.evaluate(template, context: context)
        if !context.debugInfo.isEmpty {
            print(context.debugInfo)
        }
        return result
    }
}

