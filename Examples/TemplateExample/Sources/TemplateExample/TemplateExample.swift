import Foundation
import Eval

public class TemplateLanguage: EvaluatorWithContext {
    public typealias EvaluatedType = String
    
    let language: StringTemplateInterpreter
    
    init(dataTypes: [DataTypeProtocol] = StandardLibrary.dataTypes,
         functions: [FunctionProtocol] = StandardLibrary.functions,
         templates: [Matcher<String, TemplateInterpreter<String>>] = TemplateLibrary.templates,
         context: InterpreterContext = InterpreterContext()) {
        TemplateLanguage.preprocess(context)
        let interpreter = TypedInterpreter(dataTypes: dataTypes, functions: functions, context: context)
        language = StringTemplateInterpreter(statements: templates, interpreter: interpreter, context: context)
    }
    
    public func evaluate(_ expression: String) -> String {
        return language.evaluate(expression)
    }
    
    public func evaluate(_ expression: String, context: InterpreterContext) -> String {
        TemplateLanguage.preprocess(context)
        return language.evaluate(expression, context: context)
    }
    
    static func preprocess(_ context: InterpreterContext) {
        context.variables = context.variables.mapValues { value in
            convert(value) {
                if let integerValue = $0 as? Int {
                    return Double(integerValue)
                }
                return $0
            }
        }
    }
    
    static func convert(_ value: Any, recursively: Bool = true, convert: @escaping (Any) -> Any) -> Any {
        if recursively, let array = value as? [Any] {
            return array.map { convert($0) }
        }
        if recursively, let dictionary = value as? [String: Any] {
            return dictionary.mapValues {convert($0) }
        }
        return convert(value)
    }
}

public class TemplateLibrary {
    public static var standardLibrary = StandardLibrary()
    public static var templates: [Matcher<String, TemplateInterpreter<String>>] {
        return [
            ifElseStatement,
            ifStatement,
            printStatement,
            forInStatement,
            setUsingBodyStatement,
            setStatement,
        ]
    }
    
    public static var tagPrefix = "{%"
    public static var tagSuffix = "%}"
    
    public static var ifStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body", trimmed: false), CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, interpreter, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return ""
        }
    }
    
    public static var ifElseStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body", trimmed: false), Keyword(tagPrefix + " else " + tagSuffix), TemplateVariable("else", trimmed: false), CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, interpreter, _ in
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
        return Matcher([OpenKeyword(tagPrefix + " for"), GenericVariable<String, StringTemplateInterpreter>("variable", interpreted: false), Keyword("in"), Variable<[Any]>("items"), Keyword(tagSuffix), GenericVariable<String, StringTemplateInterpreter>("body", interpreted: false, trimmed: false), CloseKeyword(tagPrefix + " endfor " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String,
                let items = variables["items"] as? [Any],
                let body = variables["body"] as? String else { return nil }
            var result = ""
            for item in items {
                context.variables[variableName] = item
                result += interpreter.evaluate(body, context: context)
            }
            context.variables[variableName] = nil
            return result
        }
    }
    
    public static var setStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword(tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endset " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String, let body = variables["body"] as? String else { return nil }
            interpreter.context.variables[variableName] = body
            return ""
        }
    }
    
    public static var setUsingBodyStatement: Matcher<String, TemplateInterpreter<String>> {
        return Matcher([OpenKeyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword("="), Variable<Any>("value"), CloseKeyword(tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String else { return nil }
            interpreter.context.variables[variableName] = variables["value"]
            return ""
        }
    }
}

public class StandardLibrary {
    public static var dataTypes: [DataTypeProtocol] {
        return [
            stringType,
            booleanType,
            arrayType,
            dictionaryType,
            dateType,
            numericType,
        ]
    }
    public static var functions: [FunctionProtocol] {
        return [
           parentheses,
           ternaryOperator,
           
           rangeFunction,
           rangeOfStringFunction,
           rangeBySteps,

           startsWithOperator,
           endsWithOperator,
           containsOperator,
           matchesOperator,

           stringConcatenationOperator,

           multiplicationOperator,
           divisionOperator,
           additionOperator,
           substractionOperator,
           moduloOperator,
           
           lessThanOperator,
           lessThanOrEqualsOperator,
           moreThanOperator,
           moreThanOrEqualsOperator,
           equalsOperator,
           notEqualsOperator,

           inNumericArrayOperator,
           inStringArrayOperator,

           incrementOperator,
           decrementOperator,

           negationOperator,
           notOperator,

           isEvenOperator,
           isOddOperator,

           minFunction,
           maxFunction,
           sumFunction,
           averageFunction,
           countFunction,
           sqrtFunction,

           arraySubscript,
           dictionarySubscript,
           dictionaryKeys,
           dictionaryValues,

           dateFactory,
           dateFormat,
        ]
    }
    
    //MARK: Types
    
    public static var numericType: DataType<Double> {
        let numberLiteral = Literal { v,_ in Double(v) }
        let pi = Literal("pi", convertsTo: Double.pi)
        return DataType(type: Double.self, literals: [numberLiteral, pi]) { value, _ in String(format: "%g", value) }
    }
    
    public static var stringType: DataType<String> {
        let singleQuotesLiteral = literal(opening: "'", closing: "'") { (input, _) in input }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { value, _ in value }
    }
    
    public static var dateType: DataType<Date> {
        let dateFormatter = DateFormatter(with: "yyyy-MM-dd HH:mm:ss")
        let now = Literal<Date>("now", convertsTo: Date())
        return DataType(type: Date.self, literals: [now]) { value, _ in dateFormatter.string(from: value) }
    }
    
    public static var arrayType: DataType<[CustomStringConvertible]> {
        let arrayLiteral = literal(opening: "[", closing: "]") { (input, interpreter) -> [CustomStringConvertible]? in
            return input
                .split(separator: ",")
                .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map{ interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        return DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { value, printer in value.map{ printer.print($0) }.joined(separator: ",") }
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
        return DataType(type: [String: CustomStringConvertible?].self, literals: [dictionaryLiteral]) { value, printer in
            let items = value.map{ key, value in
                if let value = value {
                    return "\(printer.print(key)): \(printer.print(value))"
                } else {
                    return "\(printer.print(key)): nil"
                }
            }.sorted().joined(separator: ", ")
            return "[\(items)]"
        }
    }
    
    public static var booleanType: DataType<Bool> {
        let trueLiteral = Literal("true", convertsTo: true)
        let falseLiteral = Literal("false", convertsTo: false)
        return DataType(type: Bool.self, literals: [trueLiteral, falseLiteral]) { value, _ in value ? "true" : "false" }
    }
    
    //MARK: Functions
    
    public static var parentheses: Function<Any> {
        return Function([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { arguments,_,_ in arguments["body"] }
    }
    
    public static var ternaryOperator: Function<Any> {
        return Function([Variable<Bool>("condition"), Keyword("?"), Variable<Any>("body"), Keyword(":"), Variable<Any>("else")]) { arguments,_,_ in
            guard let condition = arguments["condition"] as? Bool else { return nil }
            return condition ? arguments["body"] : arguments["else"]
        }
    }
    
    public static var rangeFunction: Function<[Double]?> {
        return infixOperator("...") { (lhs: Double, rhs: Double) in
            CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) }
        }
    }
    
    public static var rangeOfStringFunction: Function<[String]?> {
        return infixOperator("...") { (lhs: String, rhs: String) in
            CountableClosedRange(uncheckedBounds: (lower: Character(lhs), upper: Character(rhs))).map { String($0) }
        }
    }
    
    public static var startsWithOperator: Function<Bool?> {
        return infixOperator("starts with") { (lhs: String, rhs: String) in lhs.hasPrefix(rhs) }
    }
    
    public static var endsWithOperator: Function<Bool?> {
        return infixOperator("ends with") { (lhs: String, rhs: String) in lhs.hasSuffix(rhs) }
    }
    
    public static var containsOperator: Function<Bool?> {
        return infixOperator("contains") { (lhs: String, rhs: String) in lhs.contains(rhs) }
    }
    
    public static var matchesOperator: Function<Bool?> {
        return infixOperator("matches") { (lhs: String, rhs: String) in
            if let regex = try? NSRegularExpression(pattern: rhs) {
                let matches = regex.numberOfMatches(in: lhs, range: NSRange(lhs.startIndex..., in: lhs))
                return matches > 0
            }
            return false
        }
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
    
    public static var notEqualsOperator: Function<Bool?> {
        return infixOperator("!=") { (lhs: Double, rhs: Double) in lhs != rhs}
    }
    
    public static var inStringArrayOperator: Function<Bool?> {
        return infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
    }
    
    public static var inNumericArrayOperator: Function<Bool?> {
        return infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
    }
    
    public static var negationOperator: Function<Bool?> {
        return prefixOperator("!") { (expression: Bool) in !expression}
    }
    
    public static var notOperator: Function<Bool?> {
        return prefixOperator("not") { (expression: Bool) in !expression}
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
        return suffixOperator("is odd") { (expression: Double) in abs(Int(expression) % 2) == 1}
    }
    
    public static var minFunction: Function<Double> {
        return objectFunction("min") { (object: [Double]) -> Double? in object.min() }
    }
    
    public static var maxFunction: Function<Double> {
        return objectFunction("max") { (object: [Double]) -> Double? in object.max() }
    }
    
    public static var sumFunction: Function<Double> {
        return objectFunction("sum") { (object: [Double]) -> Double? in object.reduce(0, +) }
    }
    
    public static var averageFunction: Function<Double> {
        return objectFunction("avg") { (object: [Double]) -> Double? in object.reduce(0, +) / Double(object.count) }
    }
    
    public static var countFunction: Function<Double> {
        return objectFunction("count") { (object: [Double]) -> Double? in Double(object.count) }
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
    
    public static var rangeBySteps: Function<[Double]> {
        return functionWithNamedParameters("range") { (arguments: [String: Any]) -> [Double]? in
            guard let start = arguments["start"] as? Double, let end = arguments["end"] as? Double, let step = arguments["step"] as? Double else { return nil }
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
        return Function([Variable<[Any]>("array"), Keyword("."), Variable<Double>("index", shortest: false)]) { variables, _, _ in
            guard let array = variables["array"] as? [Any], let index = variables["index"] as? Double, index > 0, Int(index) < array.count else { return nil }
            return array[Int(index)]
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
            return object.keys.sorted()
        }
    }
    
    public static var dictionaryValues: Function<[Any?]> {
        return objectFunction("values") { (object: [String: Any?]) -> [Any?] in
            if let values = object as? [String: Double] {
                return values.values.sorted()
            }
            if let values = object as? [String: String] {
                return values.values.sorted()
            }
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

extension Character : Strideable {
    public typealias Stride = Int
    
    var value: UInt32 {
        return unicodeScalars.first?.value ?? 0
    }
    
    public func distance(to other: Character) -> Int {
        return Int(other.value) - Int(self.value)
    }

    public func advanced(by n: Int) -> Character {
        let advancedValue = n + Int(self.value)
        guard let advancedScalar = UnicodeScalar(advancedValue) else {
            fatalError("\(String(advancedValue, radix: 16)) does not represent a valid unicode scalar value.")
        }
        return Character(advancedScalar)
    }
}
