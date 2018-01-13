import Foundation
import Eval

public class TemplateLanguage: EvaluatorWithContext {
    public typealias EvaluatedType = String
    
    let language: StringTemplateInterpreter
    
    init(dataTypes: [DataTypeProtocol] = StandardLibrary.dataTypes,
         functions: [FunctionProtocol] = StandardLibrary.functions,
         templates: [Matcher<String, StringTemplateInterpreter>] = TemplateLibrary.templates) {
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
    public static var templates: [Matcher<String, StringTemplateInterpreter>] {
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
    
    public static var ifStatement: Matcher<String, StringTemplateInterpreter> {
        return Matcher([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, interpreter, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }
    }
    
    public static var ifElseStatement: Matcher<String, StringTemplateInterpreter> {
        return Matcher([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body"), Keyword(tagPrefix + " else " + tagSuffix), TemplateVariable("else"), CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, interpreter, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            } else {
                return variables["else"] as? String
            }
        }
    }
    
    public static var printStatement: Matcher<String, StringTemplateInterpreter> {
        return Matcher([OpenKeyword("{{"), Variable<Any>("body"), CloseKeyword("}}")]) { variables, interpreter, _ in
            guard let body = variables["body"] else { return nil }
            return interpreter.typedInterpreter.print(body)
        }
    }
    
    public static var forInStatement: Matcher<String, StringTemplateInterpreter> {
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
    
    public static var setStatement: Matcher<String, StringTemplateInterpreter> {
        return Matcher([Keyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword(tagSuffix), TemplateVariable("body"), Keyword(tagPrefix + " endset " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String, let body = variables["body"] as? String else { return nil }
            interpreter.context.variables[variableName] = body
            return nil
        }
    }
    
    public static var setUsingBodyStatement: Matcher<String, StringTemplateInterpreter> {
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
            StandardLibrary.dateType,
            StandardLibrary.numberType,
        ]
    }
    public static var functions: [FunctionProtocol] {
        return [
            StandardLibrary.parentheses,

            StandardLibrary.rangeFunction,

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

            StandardLibrary.inNumberArrayOperator,
            StandardLibrary.inStringArrayOperator,

            StandardLibrary.incrementOperator,
            StandardLibrary.decrementOperator,

            StandardLibrary.negationOperator,

            StandardLibrary.isEvenOperator,
            StandardLibrary.isOddOperator,

            StandardLibrary.minFunction,
            StandardLibrary.maxFunction,

            StandardLibrary.dateFactory,
            StandardLibrary.dateFormat,
        ]
    }
    
    //MARK: Types
    
    public static var numberType: DataType<Double> {
        let numberLiteral = Literal { v,_ in Double(v) }
        let pi = Literal("pi", convertsTo: Double.pi)
        return DataType(type: Double.self, literals: [numberLiteral, pi]) { String(describing: $0) }
    }
    
    public static var stringType: DataType<String> {
        let singleQuotesLiteral = Literal { (input, _) -> String? in
            guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
            let trimmed = input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
        }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0 }
    }
    
    public static var dateType: DataType<Date> {
        let dateFormatter = DateFormatter(with: "yyyy-MM-dd HH:mm:ss")
        let now = Literal<Date>("now", convertsTo: Date())
        return DataType(type: Date.self, literals: [now]) { dateFormatter.string(from: $0) }
    }
    
    public static var arrayType: DataType<[CustomStringConvertible]> {
        let arrayLiteral = Literal { (input, interpreter) -> [CustomStringConvertible]? in
            guard let first = input.first, let last = input.last, first == "[", last == "]" else { return nil }
            return input
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: ",")
                .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map{ interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        return DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { $0.map{ $0.description }.joined(separator: ",") }
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
    
    public static var inNumberArrayOperator: Function<Bool?> {
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
    
    public static var dateFormat: Function<String> {
        return objectFunctionWithParameters("format") { (object: Date, arguments: [Any]) -> String? in
            guard let format = arguments.first as? String else { return nil }
            let dateFormatter = DateFormatter(with: format)
            return dateFormatter.string(from: object)
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
