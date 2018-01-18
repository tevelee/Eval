import Foundation
import Eval

public class TemplateLanguage: EvaluatorWithContext {
    public typealias EvaluatedType = String
    
    let language: StringTemplateInterpreter
    
    init(dataTypes: [DataTypeProtocol] = StandardLibrary.dataTypes,
         functions: [FunctionProtocol] = StandardLibrary.functions,
         templates: [Matcher<String, TemplateInterpreter<String>>] = TemplateLibrary.templates) {
        let context = InterpreterContext()
        let interpreter = TypedInterpreter(dataTypes: dataTypes, functions: functions, context: context)
        language = StringTemplateInterpreter(statements: templates, interpreter: interpreter, context: context)
    }
    
    public func evaluate(_ expression: String) -> String {
        return language.evaluate(expression)
    }
    
    public func evaluate(_ expression: String, context: InterpreterContext) -> String {
        return language.evaluate(expression, context: context)
    }
}

public class TemplateLibrary {
    public static var standardLibrary = StandardLibrary()
    public static var templates: [Matcher<String, TemplateInterpreter<String>>] {
        return [
            TemplateLibrary.ifElseStatement,
            TemplateLibrary.ifStatement,
            TemplateLibrary.printStatement,
            TemplateLibrary.forInStatement,
            TemplateLibrary.setUsingBodyStatement,
            TemplateLibrary.setStatement,
        ]
    }
    
    public static var tagPrefix = "{%"
    public static var tagSuffix = "%}"
    
    public static var ifStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, interpreter, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }
    }
    
    public static var ifElseStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body"), Keyword(tagPrefix + " else " + tagSuffix), TemplateVariable("else"), CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, interpreter, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            } else {
                return variables["else"] as? String
            }
        }
    }
    
    public static var printStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword("{{"), Variable<Any>("body"), CloseKeyword("}}")]) { variables, interpreter, _ in
            guard let body = variables["body"] else { return nil }
            return interpreter.typedInterpreter.print(body)
        }
    }
    
    public static var forInStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " for"), Variable<String>("variable", interpreted: false), Keyword("in"), Variable<[Any]>("items"), Keyword(tagSuffix), Variable<String>("body", interpreted: false), CloseKeyword(tagPrefix + " endfor " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String,
                let items = variables["items"] as? [Any],
                let body = variables["body"] as? String else { return nil }
            var result = ""
            for item in items {
                context.variables[variableName] = item
                result += interpreter.evaluate(body)
            }
            context.variables[variableName] = nil
            return result
        }
    }
    
    public static var setStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([Keyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword(tagSuffix), TemplateVariable("body"), Keyword(tagPrefix + " endset " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String, let body = variables["body"] as? String else { return nil }
            interpreter.context.variables[variableName] = body
            return nil
        }
    }
    
    public static var setUsingBodyStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([Keyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword("="), Variable<Any>("value"), Keyword(tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String else { return nil }
            interpreter.context.variables[variableName] = variables["value"]
            return nil
        }
    }
}

public class StandardLibrary {
    public static var dataTypes: [DataTypeProtocol] {
        return [
            StandardLibrary.stringType,
            StandardLibrary.booleanType,
            StandardLibrary.arrayType,
            StandardLibrary.dictionaryType,
            StandardLibrary.dateType,
            StandardLibrary.integerType,
            StandardLibrary.doubleType,
        ]
    }
    public static var functions: [FunctionProtocol] {
        return [
            StandardLibrary.parentheses,

            StandardLibrary.rangeFunction,
            StandardLibrary.rangeBySteps,

            StandardLibrary.startsWithOperator,
            StandardLibrary.endsWithOperator,

            StandardLibrary.stringConcatenationOperator,

            StandardLibrary.additionOperator,
            StandardLibrary.substractionOperator,
            StandardLibrary.multiplicationOperator,
            StandardLibrary.divisionOperator,
            StandardLibrary.moduloOperator,

            StandardLibrary.lessThanOperator,
            StandardLibrary.lessThanOrEqualsOperator,
            StandardLibrary.moreThanOperator,
            StandardLibrary.moreThanOrEqualsOperator,
            StandardLibrary.equalsOperator,

            StandardLibrary.inIntegerArrayOperator,
            StandardLibrary.inDoubleArrayOperator,
            StandardLibrary.inStringArrayOperator,

            StandardLibrary.incrementOperator,
            StandardLibrary.decrementOperator,

            StandardLibrary.negationOperator,

            StandardLibrary.isEvenOperator,
            StandardLibrary.isOddOperator,

            StandardLibrary.minFunction,
            StandardLibrary.maxFunction,
            StandardLibrary.sqrtFunction,

            StandardLibrary.arraySubscript,
            StandardLibrary.dictionarySubscript,
            StandardLibrary.dictionaryKeys,
            StandardLibrary.dictionaryValues,

            StandardLibrary.dateFactory,
            StandardLibrary.dateFormat,
        ]
    }
    
    //MARK: Types
    
    public static var doubleType: DataType<Double> {
        let numberLiteral = Literal { v,_ in Double(v) }
        let pi = Literal("pi", convertsTo: Double.pi)
        return DataType(type: Double.self, literals: [numberLiteral, pi]) { String(describing: $0) }
    }
    
    public static var integerType: DataType<Int> {
        let numberLiteral = Literal { v,_ in Int(v) }
        return DataType(type: Int.self, literals: [numberLiteral]) { String(describing: $0) }
    }
    
    public static var stringType: DataType<String> {
        let singleQuotesLiteral = literal(opening: "'", closing: "'") { (input, _) in input }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0 }
    }
    
    public static var dateType: DataType<Date> {
        let dateFormatter = DateFormatter(with: "yyyy-MM-dd HH:mm:ss")
        let now = Literal<Date>("now", convertsTo: Date())
        return DataType(type: Date.self, literals: [now]) { dateFormatter.string(from: $0) }
    }
    
    public static var arrayType: DataType<[CustomStringConvertible]> {
        let arrayLiteral = literal(opening: "[", closing: "]") { (input, interpreter) -> [CustomStringConvertible]? in
            return input
                .split(separator: ",")
                .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map{ interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        return DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { $0.map{ $0.description }.joined(separator: ",") }
    }
    
    public static var dictionaryType: DataType<[String: CustomStringConvertible?]> {
        let dictionaryLiteral = literal(opening: "{", closing: "}") { (input, interpreter) -> [String: CustomStringConvertible?]? in
            let values = input
                .split(separator: ",")
                .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let parsedValues : [(key: String, value: CustomStringConvertible?)] = values
                .map{ $0.split(separator: ":").map { interpreter.evaluate(String($0)) } }
                .flatMap{
                    guard let first = $0.first, let key = first as? String, let value = $0.last else { return nil }
                    return (key: key, value: value as? CustomStringConvertible)
                }
            return Dictionary(grouping: parsedValues) { $0.key }.mapValues { $0.first?.value }
        }
        return DataType(type: [String: CustomStringConvertible?].self, literals: [dictionaryLiteral]) {
            return "[\($0.map{ "\($0.key): \($0.value ?? "nil")" }.sorted().joined(separator: ", "))]"
        }
    }
    
    public static var booleanType: DataType<Bool> {
        let trueLiteral = Literal("true", convertsTo: true)
        let falseLiteral = Literal("false", convertsTo: false)
        return DataType(type: Bool.self, literals: [trueLiteral, falseLiteral]) { $0 ? "true" : "false" }
    }
    
    //MARK: Functions
    
    public static var parentheses: Function<Any> {
        return Function([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { arguments,_,_ in arguments["body"] }
    }
    
    public static var rangeFunction: Function<[Double]?> {
        return infixOperator("...") { (lhs: Double, rhs: Double) in
            CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) }
        }
    }
    
    public static var startsWithOperator: Function<Bool?> {
        return infixOperator("starts with") { (lhs: String, rhs: String) in lhs.hasPrefix(lhs) }
    }
    
    public static var endsWithOperator: Function<Bool?> {
        return infixOperator("ends with") { (lhs: String, rhs: String) in lhs.hasSuffix(lhs) }
    }
    
    public static var stringConcatenationOperator: Function<String?> {
        return infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs}
    }
    
    public static var additionOperator: Function<Double?> {
        return infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs}
    }
    
    public static var substractionOperator: Function<Double?> {
        return infixOperator("-") { (lhs: Double, rhs: Double) in lhs - rhs}
    }
    
    public static var multiplicationOperator: Function<Double?> {
        return infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs}
    }
    
    public static var divisionOperator: Function<Double?> {
        return infixOperator("/") { (lhs: Double, rhs: Double) in lhs / rhs}
    }
    
    public static var moduloOperator: Function<Double?> {
        return infixOperator("%") { (lhs: Double, rhs: Double) in Double(Int(lhs) % Int(rhs))}
    }
    
    public static var lessThanOperator: Function<Bool?> {
        return infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs}
    }
    
    public static var moreThanOperator: Function<Bool?> {
        return infixOperator("<=") { (lhs: Double, rhs: Double) in lhs <= rhs}
    }
    
    public static var lessThanOrEqualsOperator: Function<Bool?> {
        return infixOperator(">") { (lhs: Double, rhs: Double) in lhs > rhs}
    }
    
    public static var moreThanOrEqualsOperator: Function<Bool?> {
        return infixOperator(">=") { (lhs: Double, rhs: Double) in lhs >= rhs}
    }
    
    public static var equalsOperator: Function<Bool?> {
        return infixOperator("==") { (lhs: Double, rhs: Double) in lhs == rhs}
    }
    
    public static var inStringArrayOperator: Function<Bool?> {
        return infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
    }
    
    public static var inIntegerArrayOperator: Function<Bool?> {
        return infixOperator("in") { (lhs: Int, rhs: [Int]) in rhs.contains(lhs) }
    }
    
    public static var inDoubleArrayOperator: Function<Bool?> {
        return infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
    }
    
    public static var negationOperator: Function<Bool?> {
        return prefixOperator("!") { (expression: Bool) in !expression}
    }
    
    public static var incrementOperator: Function<Double?> {
        return suffixOperator("++") { (expression: Double) in expression + 1}
    }
    
    public static var decrementOperator: Function<Double?> {
        return suffixOperator("--") { (expression: Double) in expression - 1}
    }
    
    public static var isEvenOperator: Function<Bool?> {
        return suffixOperator("is even") { (expression: Double) in Int(expression) % 2 == 0}
    }
    
    public static var isOddOperator: Function<Bool?> {
        return suffixOperator("is odd") { (expression: Double) in Int(expression) % 2 == 1}
    }
    
    public static var minFunction: Function<Double> {
        return objectFunction("min") { (object: [Double]) -> Double? in object.min() }
    }
    
    public static var maxFunction: Function<Double> {
        return objectFunction("max") { (object: [Double]) -> Double? in object.max() }
    }
    
    public static var sqrtFunction: Function<Double> {
        return function("sqrt") { (arguments: [Any]) -> Double? in
            guard let value = arguments.first as? Double else { return nil }
            return sqrt(value)
        }
    }
    
    public static var dateFactory: Function<Date?> {
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
    
    public static var rangeBySteps: Function<[Int]> {
        return functionWithNamedParameters("range") { (arguments: [String: Any]) -> [Int]? in
            guard let start = arguments["start"] as? Int, let end = arguments["end"] as? Int, let step = arguments["step"] as? Int else { return nil }
            var result = [start]
            var value = start
            while value <= end - step {
                value += step
                result.append(value)
            }
            return result
        }
    }
    
    public static var dateFormat: Function<String> {
        return objectFunctionWithParameters("format") { (object: Date, arguments: [Any]) -> String? in
            guard let format = arguments.first as? String else { return nil }
            let dateFormatter = DateFormatter(with: format)
            return dateFormatter.string(from: object)
        }
    }

    public static var arraySubscript: Function<Any?> {
        return Function([Variable<[Any]>("array"), Keyword("."), Variable<Int>("index", shortest: false)]) { variables, _, _ in
            guard let array = variables["array"] as? [Any], let index = variables["index"] as? Int, index > 0, index < array.count else { return nil }
            return array[index]
        }
    }
    
    public static var dictionarySubscript: Function<Any?> {
        return Function([Variable<[String: Any]>("dictionary"), Keyword("."), Variable<String>("key", shortest: false, interpreted: false)]) { variables, _, _ in
            guard let dictionary = variables["dictionary"] as? [String: Any], let key = variables["key"] as? String else { return nil }
            return dictionary[key]
        }
    }
    
    public static var dictionaryKeys: Function<[String]> {
        return objectFunction("keys") { (object: [String: Any?]) -> [String] in
            return Array(object.keys)
        }
    }
    
    public static var dictionaryValues: Function<[Any?]> {
        return objectFunction("values") { (object: [String: Any?]) -> [Any?] in
            return Array(object.values)
        }
    }
    
    public static var methodCallWithIntResult: Function<Double> {
        return Function([Variable<Any>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", shortest: false, interpreted: false)]) { (arguments,_,_) -> Double? in
            if let lhs = arguments["lhs"] as? NSObjectProtocol,
                let rhs = arguments["rhs"] as? String,
                let result = lhs.perform(Selector(rhs)) {
                return Double(Int(bitPattern: result.toOpaque()))
            }
            return nil
        }
    }
    
    //MARK: Literal helpers
    
    public static func literal<T>(opening: String, closing: String, convert: @escaping (_ input: String, _ interpreter: TypedInterpreter) -> T?) -> Literal<T> {
        return Literal { (input, interpreter) -> T? in
            guard input.hasPrefix(opening), input.hasSuffix(closing) else { return nil }
            let inputWithoutOpening = String(input.suffix(from: input.index(input.startIndex, offsetBy: opening.count)))
            let inputWithoutSides = String(inputWithoutOpening.prefix(upTo: inputWithoutOpening.index(inputWithoutOpening.endIndex, offsetBy: -closing.count)))
            guard !inputWithoutSides.contains(opening) && !inputWithoutSides.contains(closing) else { return nil }
            return convert(inputWithoutSides, interpreter)
        }
    }

    //MARK: Operator helpers
    
    public static func infixOperator<A,B,T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs", shortest: true), Keyword(symbol), Variable<B>("rhs", shortest: false)]) { arguments,_,_ in
            guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
    
    public static func prefixOperator<A,T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Keyword(symbol), Variable<A>("value", shortest: false)]) { arguments,_,_ in
            guard let value = arguments["value"] as? A else { return nil }
            return body(value)
        }
    }
    
    public static func suffixOperator<A,T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Variable<A>("value", shortest: true), Keyword(symbol)]) { arguments,_,_ in
            guard let value = arguments["value"] as? A else { return nil }
            return body(value)
        }
    }
    
    //MARK: Function helpers
    
    public static func function<T>(_ name: String, body: @escaping ([Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", shortest: true, interpreted: false), CloseKeyword(")")]) { variables, interpreter, _ in
            guard let arguments = variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").flatMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return body(interpretedArguments)
        }
    }
    
    public static func functionWithNamedParameters<T>(_ name: String, body: @escaping ([String: Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", shortest: true, interpreted: false), CloseKeyword(")")]) { variables, interpreter, _ in
            guard let arguments = variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = interpreter.evaluate(String(value))
                }
            }
            return body(interpretedArguments)
        }
    }
    
    public static func objectFunction<O,T>(_ name: String, body: @escaping (O) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", shortest: false, interpreted: false) { value,_ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }]) { variables, interpreter, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil else { return nil }
            return body(object)
        }
    }
    
    public static func objectFunctionWithParameters<O,T>(_ name: String, body: @escaping (O, [Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", interpreted: false) { value,_ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }, Keyword("("), Variable<String>("arguments", interpreted: false), Keyword(")")]) { variables, interpreter, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil, let arguments = variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").flatMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return body(object, interpretedArguments)
        }
    }
    
    public static func objectFunctionWithNamedParameters<O,T>(_ name: String, body: @escaping (O, [String: Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs", shortest: true), Keyword("."), Variable<String>("rhs", interpreted: false) { value,_ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }, OpenKeyword("("), Variable<String>("arguments", interpreted: false), CloseKeyword(")")]) { variables, interpreter, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil, let arguments = variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = interpreter.evaluate(String(value))
                }
            }
            return body(object, interpretedArguments)
        }
    }
}

public extension DateFormatter {
    public convenience init(with format: String) {
        self.init()
        self.calendar = Calendar(identifier: .gregorian)
        self.dateFormat = format
    }
}
