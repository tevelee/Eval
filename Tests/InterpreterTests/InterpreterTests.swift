import XCTest
@testable import Interpreter

class InterpreterTests: XCTestCase {
    func testGenericInterpreter() {
        let number = DataType(type: Double.self, literals: [Literal { v,_ in Double(v) },
                                                            Literal("pi", convertsTo: Double.pi) ]) { String(describing: $0) }
        
        let singleQuotesLiteral = Literal { (input, _) -> String? in
            guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
            let trimmed = input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
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
        
        let boolean = DataType(type: Bool.self, literals: [Literal("false", convertsTo: false),
                                                           Literal("true", convertsTo: true)]) { $0 ? "true" : "false" }
        
        let methodCall = Function(patterns: [
            Matcher([Variable<Any>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", shortest: false, interpreted: false)]) { (arguments,_) -> Double? in
                if let lhs = arguments["lhs"] as? NSObjectProtocol,
                    let rhs = arguments["rhs"] as? String,
                    let result = lhs.perform(Selector(rhs)) {
                    return Double(Int(bitPattern: result.toOpaque()))
                }
                return nil
            }
        ])
        
        let max = objectFunction("max") { (object: [Double]) -> Double? in object.max() }
        let min = objectFunction("min") { (object: [Double]) -> Double? in object.min() }
        
        let not = prefixOperator("!") { (value: Bool) in !value }
        let not2 = function("not") { (arguments: [Any]) -> Bool? in
            guard let boolArgument = arguments.first as? Bool else { return nil }
            return !boolArgument
        }
        let add = function("add") { (arguments: [Any]) -> Double? in
            guard let arguments = arguments as? [Double] else { return nil }
            return arguments.reduce(0, +)
        }
        let parenthesis = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { arguments,_ in arguments["body"] }
        let plusOperator = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
        let multipicationOperator = infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs }
        let inArrayNumber = infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
        let inArrayString = infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
        let range = infixOperator("...") { (lhs: Double, rhs: Double) in CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) } }
        let prefix = infixOperator("starts with") { (lhs: String, rhs: String) in lhs.hasPrefix(lhs) }
        let isOdd = suffixOperator("is odd") { (value: Double) in Int(value) % 2 == 1 }
        let isEven = suffixOperator("is even") { (value: Double) in Int(value) % 2 == 0 }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
        
        let increment = Function([Variable<Any>("value", interpreted: false), Keyword("++")]) { (arguments, interpreter) -> Double? in
            if let argument = arguments["value"] as? String {
                if let variable = interpreter.context.variables.first(where: { argument == $0.key }), let value = variable.value as? Double {
                    let incremented = value + 1
                    interpreter.context.variables[variable.key] = incremented
                    return incremented
                } else if let argument = interpreter.evaluate(argument) as? Double {
                    return argument + 1
                }
            }
            return nil
        }
        
        let interpreter = TypedInterpreter(dataTypes: [number, string, boolean, array],
                                             functions: [concat, parenthesis, methodCall, multipicationOperator, plusOperator, inArrayNumber, inArrayString, isOdd, isEven, range, add, max, min, not, not2, prefix, increment, lessThan],
                                             context: InterpreterContext(variables: ["test": 2.0, "name": "Teve"]))
        XCTAssertEqual(interpreter.evaluate("123") as! Double, 123)
        XCTAssertEqual(interpreter.evaluate("1 + 2 + 3") as! Double, 6)
        XCTAssertEqual(interpreter.evaluate("2 + 3 * 4") as! Double, 14)
        XCTAssertEqual(interpreter.evaluate("2 * 3 + 4") as! Double, 10)
        XCTAssertEqual(interpreter.evaluate("2 * (3 + 4)") as! Double, 14)
        XCTAssertEqual(interpreter.evaluate("(3 + 4) * 2") as! Double, 14)
        XCTAssertEqual(interpreter.evaluate("'hello'") as! String, "hello")
        XCTAssertEqual(interpreter.evaluate("false") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("!false") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("not(false)") as! Bool, true)
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
        XCTAssertEqual(interpreter.evaluate("not(1 in [1])") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("'b' in ['a','c','d']") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("1...5") as! [Double], [1, 2, 3, 4, 5])
        XCTAssertEqual(interpreter.evaluate("[1, test]") as! [Double], [1, 2])
        XCTAssertEqual(interpreter.evaluate("2 in 1...5") as! Bool,true)
        XCTAssertEqual(interpreter.evaluate("5 is odd") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("2 is odd") as! Bool, false)
        XCTAssertEqual(interpreter.evaluate("4 is even") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("2 < 3") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("'Teve' starts with 'T'") as! Bool, true)
        XCTAssertEqual(interpreter.evaluate("'Hello ' + name") as! String, "Hello Teve")
        XCTAssertEqual(interpreter.evaluate("12++") as! Double, 13)
        XCTAssertEqual(interpreter.evaluate("(test + 2)++") as! Double, 5)
        XCTAssertEqual(interpreter.evaluate("test++") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("test") as! Double, 3)
        XCTAssertNil(interpreter.evaluate("add(1,'a')"))
        XCTAssertNil(interpreter.evaluate("hello"))
        
        let ifStatement = Matcher([Keyword("{%"), Keyword("if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), Keyword("{%"), Keyword("endif"), Keyword("%}")]) { (variables, interpreter: TemplateInterpreter) -> String? in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }
        
        let printStatement = Matcher([Keyword("{{"), Variable<Any>("body"), Keyword("}}")]) { (variables, interpreter: TemplateInterpreter) -> String? in
            guard let body = variables["body"] else { return nil }
            return interpreter.typedInterpreter.print(body)
        }
        
        let template = TemplateInterpreter(statements: [ifStatement, printStatement], interpreter: interpreter, context: InterpreterContext())
        XCTAssertEqual(template.evaluate("{{ 1 + 2 }}"), "3.0")
        XCTAssertEqual(template.evaluate("{{ 'Hello' + ' ' + 'World' + '!' }}"), "Hello World!")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}Hello{% endif %} asd"), "asd Hello asd")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}{{ 'Hello ' + name }}{% endif %} asd"), "asd Hello Teve asd")
    }
    
    func infixOperator<A,B,T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs", shortest: true), Keyword(symbol), Variable<B>("rhs", shortest: false)]) { arguments,_ in
            guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
    
    func prefixOperator<A,T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Keyword(symbol), Variable<A>("value", shortest: false)]) { arguments,_ in
            guard let value = arguments["value"] as? A else { return nil }
            return body(value)
        }
    }
    
    func suffixOperator<A,T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Variable<A>("value", shortest: true), Keyword(symbol)]) { arguments,_ in
            guard let value = arguments["value"] as? A else { return nil }
            return body(value)
        }
    }
    
    func function<T>(_ name: String, body: @escaping ([Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), Keyword("("), Variable<String>("arguments", shortest: true, interpreted: false), Keyword(")")]) { variables, interpreter in
            guard let arguments = variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").flatMap { interpreter.evaluate(String($0)) }
            return body(interpretedArguments)
        }
    }
    
    func objectFunction<O,T>(_ name: String, body: @escaping (O) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", shortest: false, interpreted: false) { value,_ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }]) { variables, interpreter in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil else { return nil }
            return body(object)
        }
    }
}
