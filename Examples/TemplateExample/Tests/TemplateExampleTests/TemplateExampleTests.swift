import XCTest
import Eval
@testable import TemplateExample

class TemplateExampleTests: XCTestCase {
    let interpreter = TemplateLanguage()
    
    func testExample() {
        XCTAssertEqual(eval("{% if x in [1,2,3] %}Hello{% else %}Bye{% endif %} {{ name }}!", ["x": 2, "name": "Teve"]), "Hello Teve!")
    }
    
    func testContextModification() {
        _ = eval("{% set x = 4.0 %}")
        XCTAssertEqual(eval("{{ x }}"), "4.0")
    }
    
    func testDictionary() {
        XCTAssertEqual(eval("{{ {'a': 1, 'b': 2} }}"), "[a: 1, b: 2]")
        XCTAssertEqual(eval("{{ dict.b }}", ["dict": ["a": 1, "b": 2]]), "2")
        XCTAssertEqual(eval("{{ {'a': 1, 'b': 2}.b }}"), "2")
    }
    
    func testArray() {
        XCTAssertEqual(eval("{{ [1,2,3] }}"), "1,2,3")
        XCTAssertEqual(eval("{{ array.1 }}", ["array": [1,2,3]]), "2")
        XCTAssertEqual(eval("{{ [1,2,3].1 }}"), "2")
    }
    
    func testRange() {
        XCTAssertEqual(eval("{{ range(start=1, end=7, step=2) }}"), "1,3,5,7")
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
