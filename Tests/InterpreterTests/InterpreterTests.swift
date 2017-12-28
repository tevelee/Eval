import XCTest
@testable import Interpreter
import class Interpreter.Pattern

class InterpreterTests: XCTestCase {
    func testSimpleExample() {
        let keyword = Keyword("if")
        XCTAssertEqual(keyword.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(keyword.matches(prefix: "i"), .possibleMatch)
        XCTAssertEqual(keyword.matches(prefix: "if"), .exactMatch(length: 2, output: "if", variables: [:]))

        let pattern = Pattern([keyword]) { _,_ in "x" }
        XCTAssertEqual(pattern.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(pattern.matches(prefix: "i"), .possibleMatch)
        XCTAssertEqual(pattern.matches(prefix: "if"), .exactMatch(length: 2, output: "x", variables: [:]))

        let interpreter = StringExpressionInterpreter(statements: [pattern])
        XCTAssertEqual(try! interpreter.evaluate("aifb"), "axb")

        let pattern2 = Pattern(keyword + Keyword("fi")) { _,_ in "y" }
        XCTAssertEqual(pattern2.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(pattern2.matches(prefix: "i"), .possibleMatch)
        XCTAssertEqual(pattern2.matches(prefix: "if"), .possibleMatch)
        XCTAssertEqual(pattern2.matches(prefix: "iff"), .possibleMatch)
        XCTAssertEqual(pattern2.matches(prefix: "iffi"), .exactMatch(length: 4, output: "y", variables: [:]))

        let interpreter2 = StringExpressionInterpreter(statements: [pattern2])
        XCTAssertEqual(try! interpreter2.evaluate("aiffib"), "ayb")
        
        let pattern3 = Pattern(Keyword("{%") + Variable("any") + Keyword("%}")) { _,_ in "z" }
        XCTAssertEqual(pattern3.matches(prefix: "asd"), .noMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%aaa"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a a"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a a %"), .possibleMatch)
        XCTAssertEqual(pattern3.matches(prefix: "{%a a %}"), .exactMatch(length: 8, output: "z", variables: ["any": "a a "]))
        
        let interpreter3 = StringExpressionInterpreter(statements: [pattern3])
        XCTAssertEqual(try! interpreter3.evaluate("a{%a a %}b"), "azb")
    }
    
    func testCompositeExample1() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let _ = platform.add(capability: BooleanInterpreterFactory.self)
        let _ = platform.add(capability: NumericInterpreterFactory.self)
        let pattern = stringInterpreterFactory.ifStatement(tagPrefix: "{%", tagSuffix: "%}")
        XCTAssertEqual(pattern.matches(prefix: "{% if 12 > 5 %}x{% endif %}"), .exactMatch(length: 27,
                                                                                           output: "x",
                                                                                           variables: ["condition": "12 > 5 ", "body": "x"]))

        let interpreter = stringInterpreterFactory.stringExpressionInterpreter()
        XCTAssertEqual(try! interpreter.evaluate("123 {% if 3 * 2 == 6 %}x{% endif %}"), "123 x")
    }
    
    func testCompositeExample2() {
        let platform = RenderingPlatform()
        let stringInterpreterFactory = platform.add(capability: StringInterpreterFactory.self)
        let _ = platform.add(capability: BooleanInterpreterFactory.self)
        let _ = platform.add(capability: NumericInterpreterFactory.self)
        let interpreter = stringInterpreterFactory.stringExpressionInterpreter()
        XCTAssertEqual(try! interpreter.evaluate("a{# asd asd #}sd 123 {% if 12 > 5 %}x{% else %}y{% endif %}"), "asd 123 x")
    }

    static var allTests = [
        ("testSimpleExample", testSimpleExample),
        ("testCompositeExample1", testCompositeExample1),
        ("testCompositeExample2", testCompositeExample2),
        ]
}
