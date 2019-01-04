import Foundation
import Eval

//MARK: Double

public let numberDataType = DataType(type: Double.self, literals:[
        Literal { Double($0.value) },
        Literal("pi", convertsTo: Double.pi)
]) { value, _ in String(describing: value) }

//MARK: Bool

public let booleanDataType = DataType(type: Bool.self, literals: [
    Literal("false", convertsTo: false),
    Literal("true", convertsTo: true)
]) { $0.value ? "true" : "false" }

//MARK: String

let singleQuotesLiteral = Literal { (input, _) -> String? in
    guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
    let trimmed = input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
    return trimmed.contains("'") ? nil : trimmed
}
public let stringDataType = DataType(type: String.self, literals: [singleQuotesLiteral]) { $0.value }

//MARK: Date

public let dateDataType = DataType(type: Date.self, literals: [Literal<Date>("now", convertsTo: Date())]) {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter.string(from: $0)
}

//MARK: Array

let arrayLiteral = Literal { (input, interpreter) -> [CustomStringConvertible]? in
    guard let first = input.first, let last = input.last, first == "[", last == "]" else { return nil }
    return input
        .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        .split(separator: ",")
        .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .map{ interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
}
public let arrayDataType = DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { $0.value.map{ $0.description }.joined(separator: ",") }

//MARK: Operators

public let max = objectFunction("max") { (object: [Double]) -> Double? in object.max() }
public let min = objectFunction("min") { (object: [Double]) -> Double? in object.min() }

public let formatDate = objectFunctionWithParameters("format") { (object: Date, arguments: [Any]) -> String? in
    guard let format = arguments.first as? String else { return nil }
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.dateFormat = format
    return dateFormatter.string(from: object)
}

public let not = prefixOperator("!") { (value: Bool) in !value }

public let dateFactory = function("Date") { (arguments: [Any]) -> Date? in
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

public let parentheses = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { $0.variables["body"] }
public let addition = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
public let multipication = infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs }
public let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
public let inNumberArray = infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
public let inStringArray = infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
public let range = infixOperator("...") { (lhs: Double, rhs: Double) in CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) } }
public let prefix = infixOperator("starts with") { (lhs: String, rhs: String) in lhs.hasPrefix(lhs) }
public let isOdd = suffixOperator("is odd") { (value: Double) in Int(value) % 2 == 1 }
public let isEven = suffixOperator("is even") { (value: Double) in Int(value) % 2 == 0 }
public let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
public let greaterThan = infixOperator(">") { (lhs: Double, rhs: Double) in lhs > rhs }
public let equals = infixOperator("==") { (lhs: Double, rhs: Double) in lhs == rhs }

//MARK: Template elements

public let ifStatement = Matcher([Keyword("{%"), Keyword("if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), Keyword("{%"), Keyword("endif"), Keyword("%}")]) { (variables, interpreter: StringTemplateInterpreter, _) -> String? in
    guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
    if condition {
        return body
    }
    return nil
}

public let printStatement = Matcher([Keyword("{{"), Variable<Any>("body"), Keyword("}}")]) { (variables, interpreter: StringTemplateInterpreter, _) -> String? in
    guard let body = variables["body"] else { return nil }
    return interpreter.typedInterpreter.print(body)
}
