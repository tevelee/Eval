@testable import Eval
import class Eval.Pattern
import XCTest

class InterpreterTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func test_whenAddingALotOfFunctions_thenInterpretationWorksCorrectly() {
        let number = numberDataType()
        let string = stringDataType()
        let date = dateDataType()
        let array = arrayDataType()
        let boolean = booleanDataType()

        let methodCall = methodCallFunction()
        let max = objectFunction("max") { (object: [Double]) -> Double? in object.max() }
        let min = objectFunction("min") { (object: [Double]) -> Double? in object.min() }
        let sum = objectFunction("sum") { (object: [Double]) -> Double? in object.reduce(0, +) }
        let format = dateFomatFunction()
        let dateFactory = dateFactoryFunction()
        let not = prefixOperator("!") { (value: Bool) in !value }
        let not2 = function("not") { (arguments: [Any]) -> Bool? in
            guard let boolArgument = arguments.first as? Bool else { return nil }
            return !boolArgument
        }
        let sqrtFunction = function("sqrt") { (arguments: [Any]) -> Double? in
            guard let argument = arguments.first as? Double else { return nil }
            return sqrt(argument)
        }
        let add = function("add") { (arguments: [Any]) -> Double? in
            guard let arguments = arguments as? [Double] else { return nil }
            return arguments.reduce(0, +)
        }
        let test = functionWithNamedParameters("test") { (arguments: [String: Any]) -> Double? in
            guard let foo = arguments["foo"] as? Double, let bar = arguments["bar"] as? Double else { return nil }
            return foo + bar
        }
        let parenthesis = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { $0.variables["body"] }
        let plusOperator = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
        let multipicationOperator = infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs }
        let inArrayNumber = infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
        let inArrayString = infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
        let range = infixOperator("...") { (lhs: Double, rhs: Double) in CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) } }
        let prefix = infixOperator("starts with") { (lhs: String, rhs: String) in lhs.hasPrefix(rhs) }
        let isOdd = suffixOperator("is odd") { (value: Double) in Int(value) % 2 == 1 }
        let isEven = suffixOperator("is even") { (value: Double) in Int(value) % 2 == 0 }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }

        let increment = incrementFunction()

        let interpreter = TypedInterpreter(dataTypes: [number, string, boolean, array, date],
                                           functions: [concat, parenthesis, methodCall, sum, range, sqrtFunction, dateFactory, format, multipicationOperator, plusOperator, inArrayNumber, inArrayString, isOdd, isEven, add, max, min, not, not2, prefix, increment, lessThan, test],
                                           context: Context(variables: ["test": 2.0, "name": "Teve"]))
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
        XCTAssertEqual(interpreter.evaluate("2 in 1...5") as! Bool, true)
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
        XCTAssertEqual(interpreter.evaluate("sqrt(4)") as! Double, 2)
        XCTAssertNotNil(interpreter.evaluate("now.format('yyyy-MM-dd')"))
        XCTAssertEqual(interpreter.evaluate("Date(2018, 12, 13).format('yyyy-MM-dd')") as! String, "2018-12-13")
        XCTAssertEqual(interpreter.evaluate("test(foo=1, bar=2)") as! Double, 3)
        XCTAssertNil(interpreter.evaluate("add(1,'a')"))
        XCTAssertNil(interpreter.evaluate("hello"))

        let context = Context()
        _ = interpreter.evaluate("Date(1009 * 2, sqrt(144), 10 + 3).format('yyyy-MM-dd')", context: context)

        context.debugInfo.forEach {
            print("DEBUG STEP: '\($0.value.pattern)', where \($0.value.variables), rendered to \($0.value.output) from input \($0.key)")
        }

        let ifStatement = Pattern<String, TemplateInterpreter<String>>([Keyword("{%"), Keyword("if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), Keyword("{% endif %}")]) {
            guard let condition = $0.variables["condition"] as? Bool, let body = $0.variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }

        let printStatement = Pattern<String, TemplateInterpreter<String>>([Keyword("{{"), Variable<Any>("body"), Keyword("}}")]) {
            guard let body = $0.variables["body"] else { return nil }
            return $0.interpreter.typedInterpreter.print(body)
        }

        let template = StringTemplateInterpreter(statements: [ifStatement, printStatement], interpreter: interpreter, context: Context())
        XCTAssertEqual(template.evaluate("{{ 1 + 2 }}"), "3.0")
        XCTAssertEqual(template.evaluate("{{ 'Hello' + ' ' + 'World' + '!' }}"), "Hello World!")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}Hello{% endif %} asd"), "asd Hello asd")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}{{ 'Hello ' + name }}{% endif %} asd"), "asd Hello Teve asd")
    }

    func test_whenEmbeddingTags_thenInterpretationWorksCorrectly() {
        let parenthesis = Function<Any>([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { $0.variables["body"] }
        let addition = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType()],
                                           functions: [parenthesis, addition])

        XCTAssertEqual(interpreter.evaluate("(1)") as! Double, 1)
        XCTAssertEqual(interpreter.evaluate("(1) + (2)") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("(1 + (2))") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("(1 + 2)") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("((1) + 2)") as! Double, 3)
        XCTAssertEqual(interpreter.evaluate("((1) + (2))") as! Double, 3)
    }

    func test_whenEmbeddingTagsWithNonCummitativeOperation_thenInterpretationWorksCorrectly() {
        let parenthesis = Function<Any>([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { $0.variables["body"] }
        let addition = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let subtraction = infixOperator("-") { (lhs: Double, rhs: Double) in lhs - rhs }
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType()],
                                           functions: [parenthesis, subtraction, addition])

        XCTAssertEqual(interpreter.evaluate("6 - 4 - 2") as! Double, 0)
        XCTAssertEqual(interpreter.evaluate("6 - (4 + 2)") as! Double, 0)
        XCTAssertEqual(interpreter.evaluate("6 - (4 - 2)") as! Double, 4)
        XCTAssertEqual(interpreter.evaluate("12 - (6 - (4 - 2))") as! Double, 8)
    }

    func test_whenStartsWithParentheses_thenInterpretationWorksCorrectly() {
        let parenthesis = Function<Any>([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { $0.variables["body"] }
        let addition = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let multiplication = infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs }
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType()],
                                           functions: [parenthesis, multiplication, addition])

        XCTAssertEqual(interpreter.evaluate("(2 + 3)") as! Double, 5)
        XCTAssertEqual(interpreter.evaluate("(2 + 3) * 4") as! Double, 20)
    }

    // MARK: Helpers - operators

    func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")], options: .backwardMatch) {
            guard let lhs = $0.variables["lhs"] as? A, let rhs = $0.variables["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }

    func prefixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Keyword(symbol), Variable<A>("value")]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }

    func suffixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Variable<A>("value"), Keyword(symbol)]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }

    func function<T>(_ name: String, body: @escaping ([Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { match in
            guard let arguments = match.variables["arguments"] as? String else { return nil }
            let interpretedArguments: [Any] = arguments.split(separator: ",").compactMap { match.interpreter.evaluate(String($0).trim(), context: match.context) }
            return body(interpretedArguments)
        }
    }

    func functionWithNamedParameters<T>(_ name: String, body: @escaping ([String: Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), Keyword("("), Variable<String>("arguments", options: .notInterpreted), Keyword(")")]) {
            guard let arguments = $0.variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trim().split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = $0.interpreter.evaluate(String(value))
                }
            }
            return body(interpretedArguments)
        }
    }

    func objectFunction<O, T>(_ name: String, body: @escaping (O) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == name else { return nil }
            return value
        }]) {
            guard let object = $0.variables["lhs"] as? O, $0.variables["rhs"] != nil else { return nil }
            return body(object)
        }
    }

    func objectFunctionWithParameters<O, T>(_ name: String, body: @escaping (O, [Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == name else { return nil }
            return value
        }, Keyword("("), Variable<String>("arguments", options: .notInterpreted), Keyword(")")]) { match in
            guard let object = match.variables["lhs"] as? O, match.variables["rhs"] != nil, let arguments = match.variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { match.interpreter.evaluate(String($0).trim()) }
            return body(object, interpretedArguments)
        }
    }

    // MARK: Helpers - data types

    func numberDataType() -> DataType<Double> {
        return DataType(type: Double.self,
                        literals: [Literal { Double($0.value) },
                                   Literal("pi", convertsTo: Double.pi)]) { String(describing: $0.value) }
    }

    func stringDataType() -> DataType<String> {
        let singleQuotesLiteral = Literal { literal -> String? in
            guard let first = literal.value.first, let last = literal.value.last, first == last, first == "'" else { return nil }
            let trimmed = literal.value.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
        }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0.value }
    }

    func dateDataType() -> DataType<Date> {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return DataType(type: Date.self, literals: [Literal<Date>("now", convertsTo: Date())]) { dateFormatter.string(from: $0.value) }
    }

    func arrayDataType() -> DataType<[CustomStringConvertible]> {
        let arrayLiteral = Literal { literal -> [CustomStringConvertible]? in
            guard let first = literal.value.first, let last = literal.value.last, first == "[", last == "]" else { return nil }
            return literal.value
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { literal.interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        return DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { $0.value.map { $0.description }.joined(separator: ",") }
    }

    func booleanDataType() -> DataType<Bool> {
        return DataType(type: Bool.self, literals: [Literal("false", convertsTo: false), Literal("true", convertsTo: true)]) { $0.value ? "true" : "false" }
    }

    // MARK: Helpers - functions

    func methodCallFunction() -> Function<Double> {
        return Function(patterns: [
            Pattern(Variable<Any>("lhs") + Keyword(".") + Variable<String>("rhs", options: .notInterpreted)) {
                if let lhs = $0.variables["lhs"] as? NSObjectProtocol,
                    !(lhs is NSNull),
                    let rhs = $0.variables["rhs"] as? String,
                    let result = lhs.perform(Selector(rhs)) {
                    return Double(Int(bitPattern: result.toOpaque()))
                }
                return nil
            }
        ])
    }

    func dateFomatFunction() -> Function<String> {
        return objectFunctionWithParameters("format") { (object: Date, arguments: [Any]) -> String? in
            guard let format = arguments.first as? String else { return nil }
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            dateFormatter.dateFormat = format
            return dateFormatter.string(from: object)
        }
    }

    func dateFactoryFunction() -> Function<Date> {
        return function("Date") { (arguments: [Any]) -> Date? in
            guard let arguments = arguments as? [Double], arguments.count >= 3 else { return nil }
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.year = Int(arguments[0])
            components.month = Int(arguments[1])
            components.day = Int(arguments[2])
            components.hour = arguments.count > 3 ? Int(arguments[3]) : 0
            components.minute = arguments.count > 4 ? Int(arguments[4]) : 0
            components.second = arguments.count > 5 ? Int(arguments[5]) : 0
            return components.date
        }
    }

    func incrementFunction() -> Function<Double> {
        return Function([Variable<Any>("value", options: .notInterpreted), Keyword("++")]) {
            if let argument = $0.variables["value"] as? String {
                if let variable = $0.interpreter.context.variables.first(where: { argument == $0.key }), let value = variable.value as? Double {
                    let incremented = value + 1
                    $0.interpreter.context.variables[variable.key] = incremented
                    return incremented
                } else if let argument = $0.interpreter.evaluate(argument) as? Double {
                    return argument + 1
                }
            }
            return nil
        }
    }
}
