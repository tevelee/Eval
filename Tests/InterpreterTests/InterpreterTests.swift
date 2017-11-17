import XCTest
@testable import Interpreter
import struct Interpreter.Pattern

class InterpreterTests: XCTestCase {
    func testSimpleExample() {
        let keyword = Keyword("if")
        XCTAssertEqual(keyword.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(keyword.matches(prefix: "i"), .possibleMatch)
        XCTAssertEqual(keyword.matches(prefix: "if"), .exactMatch(length: 2, output: "if", variables: [:]))

        let pattern = Pattern([keyword]) { _ in "x" }
        XCTAssertEqual(pattern.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(pattern.matches(prefix: "i"), .possibleMatch)
        XCTAssertEqual(pattern.matches(prefix: "if"), .exactMatch(length: 2, output: "x", variables: [:]))

        let interpreter = Interpreter(language: TemplateLanguage(statements: [pattern], filters: []))
        XCTAssertEqual(interpreter.interpret("aifb"), "axb")

        let pattern2 = Pattern(keyword + Keyword("fi")) { _ in "y" }
        XCTAssertEqual(pattern2.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(pattern2.matches(prefix: "i"), .possibleMatch)
        XCTAssertEqual(pattern2.matches(prefix: "if"), .possibleMatch)
        XCTAssertEqual(pattern2.matches(prefix: "iff"), .possibleMatch)
        XCTAssertEqual(pattern2.matches(prefix: "iffi"), .exactMatch(length: 4, output: "y", variables: [:]))

        let interpreter2 = Interpreter(language: TemplateLanguage(statements: [pattern2], filters: []))
        XCTAssertEqual(interpreter2.interpret("aiffib"), "ayb")
        
        let pattern3 = Pattern(Keyword("{%") + Variable("any") + Keyword("%}")) { _ in "z" }
        XCTAssertEqual(pattern3.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%aaa"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a a"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a a %"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a a %}"), .exactMatch(length: 8, output: "z", variables: ["any": "a a"]))
        
        let interpreter3 = Interpreter(language: TemplateLanguage(statements: [pattern3], filters: []))
        XCTAssertEqual(interpreter3.interpret("a{%a a %}b"), "azb")
    }
    
    func testCompositeExample1() {
        let tagPrefix = "{%"
        let tagSuffix = "%}"
        let pattern = ifStatement(tagPrefix: tagPrefix, tagSuffix: tagSuffix)
        XCTAssertEqual(pattern.matches(prefix: "{% if 12 > 5 %}x{% endif %}"), .exactMatch(length: 27, output: "x", variables: ["condition": "12 > 5",
                                                                                                                                "body": "x"]))

        let interpreter = Interpreter(language: TemplateLanguage(statements: [pattern], filters: []))
        XCTAssertEqual(interpreter.interpret("123 {% if 12 > 5 %}x{% endif %}"), "123 x")
    }
    
    func testCompositeExample2() {
        let tagPrefix = "{%"
        let tagSuffix = "%}"

        let interpreter = Interpreter(language: TemplateLanguage(statements: [ifStatement(tagPrefix: tagPrefix, tagSuffix: tagSuffix),
                                                                              commentBlock()],
                                                                 filters: []))
        XCTAssertEqual(interpreter.interpret("a{# asd asd #}sd 123 {% if 12 > 5 %}x{% endif %}"), "asd 123 x")
    }

    static var allTests = [
        ("testSimpleExample", testSimpleExample),
        ("testCompositeExample1", testCompositeExample1),
        ("testCompositeExample2", testCompositeExample2),
        ]
    
    func ifStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        let ifOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("if") + Variable("condition") + Keyword(tagSuffix))
        let ifClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endif") + Keyword(tagSuffix))
        return Pattern(ifOpeningTag + Variable("body") + ifClosingTag) { variables in
            if let condition = variables["condition"], BooleanExpression(condition).evaluate() {
                return variables["body"]
            } else {
                return nil
            }
        }
    }
    
    func commentBlock() -> Pattern {
        return Pattern(Keyword("{#") + Variable("body") + Keyword("#}"))
    }
}
