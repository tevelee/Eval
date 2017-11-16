import XCTest
@testable import Interpreter

class InterpreterTests: XCTestCase {
    func testExample() {
        let tagPrefix = "{%"
        let tagSuffix = "%}"
        
        let ifOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("if") + Variable("condition") + Keyword(tagSuffix))
        let ifClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endif") + Keyword(tagSuffix))
        let ifStatement = Pattern(ifOpeningTag + Variable("body") + ifClosingTag) { variables in
            if let condition = variables["condition"], BooleanExpression(condition).evaluate() {
                return variables["body"]
            } else {
                return nil
            }
        }
        
        //TODO: solve embedded tags
        //TODO: solve context with variables and methods in a given scope
        //TODO: boolean expression with operators
        //TODO: < is applied only to numerics
        //TODO: pipe operator instead of filter (left: any, right: function)
        
        let commentBlock = Pattern(Keyword("{#") + Variable("body") + Keyword("#}"))
        
        let interpreter = Interpreter(language: TemplateLanguage(statements: [ifStatement, commentBlock], filters: []))
        XCTAssertEqual(interpreter.interpret("asd 123 {% if 12 > 5 %}x{% endif %}{# asd asd #}"), "asd 123 x")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
