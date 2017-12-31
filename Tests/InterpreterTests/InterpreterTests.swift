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
        let number = DataType(type: Double.self, literals: [Literal { v,_ in Double(v) },
                                                            Literal(for: Double.pi, when: "pi") ]) { String(describing: $0) }
        
        let singleQuotesLiteral = Literal { (input, _) -> String? in
            guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
            return input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
        }
        let string = DataType(type: String.self, literals: [singleQuotesLiteral]) { $0 }
        
        let arrayLiteral = Literal { (input, interpreter) -> [CustomStringConvertible]? in
            guard let first = input.first, let last = input.last, first == "[", last == "]" else { return nil }
            return input
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: Character(","))
                .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map{ interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        let array = DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { $0.map{ $0.description }.joined(separator: ",") }
        
        let boolean = DataType(type: Bool.self, literals: [Literal(for: false, when: "false"),
                                                           Literal(for: true, when: "true")]) { $0 ? "true" : "false" }
        
        let add = Function(patterns: [
            Matcher<Double>([Static("add"), Static("("), Placeholder("lhs", shortest: true), Static(","), Placeholder("rhs", shortest: true), Static(")")]) { arguments in
                if let lhs = arguments["lhs"] as? Double, let rhs = arguments["rhs"] as? Double {
                    return Double(lhs) + Double(rhs)
                }
                return nil
            }
        ])
        
        let methodCall = Function(patterns: [
            Matcher<Double>([Placeholder("lhs", shortest: true), Static("."), Placeholder("rhs", shortest: false, interpreted: false)]) { arguments in
                if let lhs = arguments["lhs"] as? NSObjectProtocol,
                    let rhs = arguments["rhs"] as? String,
                    let result = lhs.perform(Selector(rhs)) {
                    return Double(Int(bitPattern: result.toOpaque()))
                }
                return nil
            }
        ])
        
        let max = Function(patterns: [
            Matcher<Double>([Placeholder("lhs", shortest: true), Static("."), Placeholder("rhs", shortest: false) {
                guard let value = $0 as? String, value == "max" else { return nil }
                return value
            }]) { arguments in
                guard let lhs = arguments["lhs"] as? [Double], arguments["rhs"] != nil else { return nil }
                return lhs.max()
            }
        ])
        
        let isOdd = Function(patterns: [
            Matcher<Bool>([Placeholder("value", shortest: true), Static("is"), Static("odd")]) { arguments in
                if let value = arguments["value"] as? Double {
                    return Int(value) % 2 == 0
                }
                return nil
            }
        ])
        
        let plusOperator = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
        let multipicationOperator = infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs }
        let inArrayNumber = infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
        let inArrayString = infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
        let range = infixOperator("...") { (lhs: Double, rhs: Double) in CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) } }
        let parenthesis = Function([Static("("), Placeholder("body"), Static(")")]) { $0["body"] }
        
        let interpreter = GenericInterpreter(dataTypes: [number, string, boolean, array],
                                             functions: [concat, parenthesis, methodCall, multipicationOperator, plusOperator, inArrayNumber, inArrayString, isOdd, range, add, max],
                                             variables: ["test": 2.0, "name": "Teve"])
        XCTAssertEqual(interpreter.evaluate("123") as! Double, 123)
        XCTAssertEqual(interpreter.evaluate("1 + 2 + 3") as! Double, 6)
        XCTAssertEqual(interpreter.evaluate("2 + 3 * 4") as! Double, 14)
        XCTAssertEqual(interpreter.evaluate("2 * 3 + 4") as! Double, 10)
        XCTAssertEqual(interpreter.evaluate("2 * (3 + 4)") as! Double, 14)
        XCTAssertEqual(interpreter.evaluate("(3 + 4) * 2") as! Double, 14)
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
        XCTAssertEqual(interpreter.evaluate("1 in [3,2,1,2,3]") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("'b' in ['a','c','d']") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("1...5") as! [Double], [1, 2, 3, 4, 5])
        XCTAssertEqual(interpreter.evaluate("[1, test]") as! [Double], [1, 2])
        XCTAssertEqual(interpreter.evaluate("2 in 1...5") as! Bool,true)
        XCTAssertEqual(interpreter.evaluate("5 is odd") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("2 is odd") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("'Hello ' + name") as! String, "Hello Teve")
        XCTAssertNil(interpreter.evaluate("add(1,'a')"))
        XCTAssertNil(interpreter.evaluate("hello"))
    }
    
    func infixOperator<A,B,T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T> {
        return Function([Placeholder("lhs", shortest: true), Static(symbol), Placeholder("rhs", shortest: false)]) { arguments in
            guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
}
