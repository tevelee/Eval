import Foundation

public class Literal<T> {
    let convert: (String, GenericInterpreter) -> T?
    
    init(convert: @escaping (String, GenericInterpreter) -> T?) {
        self.convert = convert
    }
    
    public func convert(input: String, interpreter: GenericInterpreter) -> T? {
        return convert(input, interpreter)
    }
}

public protocol DataTypeProtocol {
    var name: String { get }
    func convert(input: String, interpreter: GenericInterpreter) -> Any?
}

public class DataType<T> : DataTypeProtocol {
    public let name: String
    let type: T.Type
    let literals: [Literal<T>]
    let print: (T) -> String

    init (name: String,
          type: T.Type,
          literals: [Literal<T>],
          print: @escaping (T) -> String) {
        self.name = name
        self.type = type
        self.literals = literals
        self.print = print
    }
    
    public func convert(input: String, interpreter: GenericInterpreter) -> Any? {
        return literals.flatMap{ $0.convert(input: input, interpreter: interpreter) }.first
    }
}

//public protocol InstanceProtocol {
//}
//
//public class Instance<T>: InstanceProtocol {
//    let dataType: DataType<T>
//    let value: T
//
//    init(dataType: DataType<T>,
//         value: T) {
//        self.dataType = dataType
//        self.value = value
//    }
//}

public protocol FunctionProtocol {
    var name: String { get }
    func convert(input: String, interpreter: GenericInterpreter) -> Any?
}

public class Function<T> : FunctionProtocol {
    public let name: String
    var patterns: [Matcher<T>]
    
    init(name: String,
         patterns: [Matcher<T>]) {
        self.name = name
        self.patterns = patterns
    }
    
    public func convert(input: String, interpreter: GenericInterpreter) -> Any? {
        if case let .exactMatch(_, output, _) = isStatement(in: input, interpreter: interpreter) {
            return output
        }
        return nil
    }
    
    func isStatement(in input: String, from start: Int = 0, until length: Int = 1, interpreter: GenericInterpreter) -> MatchType<Any> {
        let prefix = String(input[start ..< start + length])
        let isLast = input.count == start + length
        let elements = patterns
            .map { (element: $0, result: $0.matches(prefix: prefix, interpreter: interpreter, isLast: isLast)) }
            .filter { !$0.result.isNoMatch() }
        
        if elements.count == 0 {
            return .noMatch
        }
        if let matchingElement = elements.first(where: { $0.result.isMatch() }),
            case .exactMatch(let length, let output, let variables) = matchingElement.result {
            return .exactMatch(length: length, output: output, variables: variables)
        }
        if elements.contains(where: { $0.result.isPossibleMatch() }) {
            if isLast {
                return .noMatch
            } else {
                return isStatement(in: input, from: start, until: length + 1, interpreter: interpreter)
            }
        }
        return .noMatch
    }
}

public enum MatchType<T> {
    case noMatch
    case possibleMatch
    case exactMatch(length: Int, output: T, variables: [String: Any])
    case anyMatch(shortest: Bool)
    
    func isMatch() -> Bool {
        if case .exactMatch(length: _, output: _, variables: _) = self {
            return true
        }
        return false
    }
    
    func isNoMatch() -> Bool {
        if case .noMatch = self {
            return true
        }
        return false
    }
    
    func isPossibleMatch() -> Bool {
        if case .possibleMatch = self {
            return true
        }
        return false
    }
}

public protocol MatchElement {
    func matches(prefix: String, isLast: Bool) -> MatchType<Any>
}

public class Static : MatchElement {
    public typealias T = String

    let name: String
    
    public init(_ name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchType<Any> {
        if name == prefix || prefix.hasPrefix(name) {
            return .exactMatch(length: name.count, output: name, variables: [:])
        } else if name.hasPrefix(prefix) {
            return .possibleMatch
        } else {
            return .noMatch
        }
    }
}

public class Placeholder : MatchElement {
    let name: String
    let shortest: Bool
    let interpreted: Bool
    
    public init(_ name: String, shortest: Bool = true, interpreted: Bool = true) {
        self.name = name
        self.shortest = shortest
        self.interpreted = interpreted
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchType<Any> {
        return .anyMatch(shortest: shortest)
    }
}

public class Matcher<T> {
    let elements: [MatchElement]
    let matcher: ([String: Any]) -> T?
    
    init(_ elements: [MatchElement],
         matcher: @escaping ([String: Any]) -> T?) {
        self.matcher = matcher

        var elements = elements
        if let last = elements.last as? Placeholder {
            elements.removeLast()
            elements.append(Placeholder(last.name, shortest: false))
        }
        self.elements = elements
    }
    
    public func matches(prefix: String, interpreter: GenericInterpreter, isLast: Bool = false) -> MatchType<T> {
        var elementIndex = 0
        var input = prefix
        var variables: [String: Any] = [:]
        var currentlyActiveVariable: (name: String, value: String, interpreted: Bool)? = nil
        repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: input, isLast: isLast)
            
            switch result {
            case .noMatch:
                if let previous = currentlyActiveVariable, !input.isEmpty {
                    currentlyActiveVariable = (previous.name, previous.value + String(input.removeFirst()), previous.interpreted)
                } else {
                    return .noMatch
                }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch(let shortest):
                if !input.isEmpty, currentlyActiveVariable == nil, let variable = element as? Placeholder {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()), variable.interpreted)
                }
                if !shortest {
                    if isLast, let variable = currentlyActiveVariable {
                        if !input.isEmpty {
                            currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()), variable.interpreted)
                        } else {
                            let value = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
                            if variable.interpreted, let output = interpreter.evaluate(value) {
                                variables[variable.name] = output
                            } else {
                                variables[variable.name] = value
                            }
                            elementIndex += 1
                        }
                    } else {
                        return .possibleMatch
                    }
                } else {
                    elementIndex += 1
                }
            case .exactMatch(let length, _, let embeddedVariables):
                variables.merge(embeddedVariables) { (key, value) in key }
                if let variable = currentlyActiveVariable {
                    let value = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if variable.interpreted, let output = interpreter.evaluate(value) {
                        variables[variable.name] = output
                    } else {
                        variables[variable.name] = value
                    }
                    currentlyActiveVariable = nil
                }
                input.removeFirst(length)
                input = input.trimmingCharacters(in: .whitespacesAndNewlines)
                elementIndex += 1
            }
        } while elementIndex < elements.count
        
        if let renderedOutput = matcher(variables) {
            return .exactMatch(length: prefix.count - input.count, output: renderedOutput, variables: variables)
        } else {
            return .noMatch
        }
    }
}

public class Constant {
    
}

public class GenericInterpreter {
    let dataTypes: [DataTypeProtocol]
    let functions: [FunctionProtocol]
    let constants: [Constant]
    
    init(dataTypes: [DataTypeProtocol] = [],
        functions: [FunctionProtocol] = [],
        constants: [Constant] = []) {
        self.dataTypes = dataTypes
        self.functions = functions
        self.constants = constants
    }
    
    public func evaluate(_ expression: String) -> Any? {
        for dataType in dataTypes {
            if let value = dataType.convert(input: expression, interpreter: self) {
                return value
            }
        }
        for function in functions {
            if let value = function.convert(input: expression, interpreter: self) {
                return value
            }
        }
        return nil
    }
}

//GOAL: To be able to parse the following expressions
//"[1,2,3,0]|max + variable"
//"['a', 'b']|join(', ')"
//"'hello'|length + 1"
//"Date(2017,12,13)|format('yyyy-mm-dd')"
//"string|escape('%')"
//"person.name|capitalised|map('Hello #{%s}!')"
//"{'a': 1}"
//"1 in [1,2]"
//"1 in odd"
//"3..5"
//"'Name' starts with 'N'"
//"value|default('none')"
//"range(low=1, high=10, step=2)"
