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
    
    func testSimple2Example() {
        let shortest = Pattern(Variable("lhs") + Keyword(".") + Variable("rhs", shortest: true)) { _,_ in "z" }
        XCTAssertEqual(shortest.matches(prefix: "asd"), .possibleMatch)
        XCTAssertEqual(shortest.matches(prefix: "asd."), .possibleMatch)
        XCTAssertEqual(shortest.matches(prefix: "asd.a"), .possibleMatch)
        XCTAssertEqual(shortest.matches(prefix: "asd.as", isLast: true), .exactMatch(length: 6, output: "z", variables: ["lhs": "asd", "rhs": "as"]))
        
        let pattern = Pattern(Variable("lhs") + Keyword(".") + Variable("rhs", shortest: false)) { _,_ in "z" }
        XCTAssertEqual(pattern.matches(prefix: "asd"), .possibleMatch)
        XCTAssertEqual(pattern.matches(prefix: "asd."), .possibleMatch)
        XCTAssertEqual(pattern.matches(prefix: "asd.a"), .possibleMatch)
        XCTAssertEqual(pattern.matches(prefix: "asd.as", isLast: true), .exactMatch(length: 6, output: "z", variables: ["lhs": "asd", "rhs": "as"]))
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

    func testGenericInterpreter() {
        let number = DataType(name: "number", type: Double.self, literals: [Literal { v,_ in Double(v) },
                                                                            Literal { v,_ in v == "pi" ? Double.pi : nil } ]) { String(describing: $0) }
        
        let singleQuotesLiteral = Literal { (input, _) -> String? in
            guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
            return input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
        }
        let string = DataType(name: "string", type: String.self, literals: [singleQuotesLiteral]) { $0 }
        
        let arrayLiteral = Literal { (input, interpreter) -> [CustomStringConvertible]? in
            guard let first = input.first, let last = input.last, first == "[", last == "]" else { return nil }
            return input
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: Character(","))
                .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map{ interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        let array = DataType(name: "array", type: [CustomStringConvertible].self, literals: [arrayLiteral]) { $0.map{ $0.description }.joined(separator: ",") }
        
        let boolean = DataType(name: "boolean", type: Bool.self, literals: [Literal { v,_ in v == "false" ? false : nil },
                                                                            Literal { v,_ in v == "true" ? true : nil }]) { $0 ? "true" : "false" }
        
        let add = Function(name: "add", patterns: [
            Matcher<Double>([Static("add"), Static("("), Placeholder("lhs", shortest: true), Static(","), Placeholder("rhs", shortest: true), Static(")")]) { arguments in
                if let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double {
                    return Double(lhs) + Double(rhs)
                }
                return nil
            }
        ])
        
        let multipicationOperator = Function(name: "*", patterns: [
            Matcher<Double>([Placeholder("lhs", shortest: true), Static("*"), Placeholder("rhs", shortest: false)]) { arguments in
                if let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double {
                    return Double(lhs) * Double(rhs)
                }
                return nil
            }
        ])
        
        let methodCall = Function(name: "methodCall", patterns: [
            Matcher<Double>([Placeholder("lhs", shortest: true), Static("."), Placeholder("rhs", shortest: false, interpreted: false)]) { arguments in
                if let lhs = arguments["lhs"] as? NSObjectProtocol,
                    let rhs = arguments["rhs"] as? String,
                    let result = lhs.perform(Selector(rhs)) {
                    return Double(Int(bitPattern: result.toOpaque()))
                }
                return nil
            }
        ])
        
        let max = Function(name: "max", patterns: [
            Matcher<Double>([Placeholder("lhs", shortest: true), Static("."), Placeholder("rhs", shortest: false)]) { arguments in
                if let lhs = arguments["lhs"] as? [Double], let rhs = arguments["rhs"] as? String, rhs == "max" {
                    return lhs.max()
                }
                return nil
            }
        ])
        
        let interpreter = GenericInterpreter(dataTypes: [number, string, boolean, array],
                                             functions: [multipicationOperator, add, max, methodCall])
        XCTAssertEqual(interpreter.evaluate("123") as! Double, 123)
        XCTAssertEqual(interpreter.evaluate("'hello'") as! String, "hello")
        XCTAssertEqual(interpreter.evaluate("false") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("true") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("add(1,2)") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("[1,2]") as! [Double], [1, 2])
        XCTAssertEqual(interpreter.evaluate("['1','2']") as! [String], ["1", "2"])
        XCTAssertEqual(interpreter.evaluate("[true, false]") as! [Bool], [true, false])
        XCTAssertEqual(interpreter.evaluate("[1,2].count") as! Double, 2)
        XCTAssertEqual(interpreter.evaluate("'hello'.length") as! Double, 5)
        XCTAssertEqual(interpreter.evaluate("[0,3,1,2].max") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("pi * 2") as! Double, Double.pi * 2)
        XCTAssertNil(interpreter.evaluate("add(1,'a')"))
        XCTAssertNil(interpreter.evaluate("hello"))
    }
}
