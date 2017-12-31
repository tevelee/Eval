import Foundation

public class Literal<T> {
    let convert: (String, GenericInterpreter) -> T?
    
    init(convert: @escaping (String, GenericInterpreter) -> T?) {
        self.convert = convert
    }
    
    init(for value: T, when check: String) {
        self.convert = { input,_ in check == input ? value : nil }
    }
    
    public func convert(input: String, interpreter: GenericInterpreter) -> T? {
        return convert(input, interpreter)
    }
}

public protocol DataTypeProtocol {
    func convert(input: String, interpreter: GenericInterpreter) -> Any?
}

public class DataType<T> : DataTypeProtocol {
    let type: T.Type
    let literals: [Literal<T>]
    let print: (T) -> String

    init (type: T.Type,
          literals: [Literal<T>],
          print: @escaping (T) -> String) {
        self.type = type
        self.literals = literals
        self.print = print
    }
    
    public func convert(input: String, interpreter: GenericInterpreter) -> Any? {
        return literals.flatMap{ $0.convert(input: input, interpreter: interpreter) }.first
    }
}

public protocol FunctionProtocol {
    func convert(input: String, interpreter: GenericInterpreter) -> Any?
}

public class Function<T> : FunctionProtocol {
    var patterns: [Matcher<T>]
    
    init(patterns: [Matcher<T>]) {
        self.patterns = patterns
    }
    
    init(_ elements: [MatchElement], matcher: @escaping ([String: Any]) -> T?) {
        self.patterns = [Matcher(elements, matcher: matcher)]
    }
    
    public func convert(input: String, interpreter: GenericInterpreter) -> Any? {
        guard case let .exactMatch(_, output, _) = isStatement(statements: patterns, in: input, interpreter: interpreter) else { return nil }
        return output
    }
}

func isStatement<T>(statements: [Matcher<T>], in input: String, from start: Int = 0, until length: Int = 1, interpreter: GenericInterpreter) -> MatchType<Any> {
    let prefix = String(input[start ..< start + length])
    let isLast = input.count == start + length
    let elements = statements
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
            return isStatement(statements: statements, in: input, from: start, until: length + 1, interpreter: interpreter)
        }
    }
    return .noMatch
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

public typealias ValueMap = (Any) -> Any?

public class Placeholder : MatchElement {
    let name: String
    let shortest: Bool
    let interpreted: Bool
    let map: ValueMap
    
    public init(_ name: String, shortest: Bool = true, interpreted: Bool = true, map: @escaping ValueMap = { $0 }) {
        self.name = name
        self.shortest = shortest
        self.interpreted = interpreted
        self.map = map
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchType<Any> {
        return .anyMatch(shortest: shortest)
    }
    
    public func map(value: String) -> Any? {
        return map(value)
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
            elements.append(Placeholder(last.name, shortest: false, map: last.map))
        }
        self.elements = elements
    }
    
    public func matches(prefix: String, interpreter: GenericInterpreter, isLast: Bool = false) -> MatchType<T> {
        var elementIndex = 0
        var input = prefix
        var variables: [String: Any] = [:]
        var currentlyActiveVariable: (name: String, value: String, interpreted: Bool, map: ValueMap)? = nil
        repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: input, isLast: isLast)
            
            switch result {
            case .noMatch:
                if let variable = currentlyActiveVariable, !input.isEmpty {
                    currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()), variable.interpreted, variable.map)
                } else {
                    return .noMatch
                }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch(let shortest):
                if !input.isEmpty, currentlyActiveVariable == nil, let variable = element as? Placeholder {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()), variable.interpreted, variable.map)
                }
                if !shortest {
                    if isLast, let variable = currentlyActiveVariable {
                        if !input.isEmpty {
                            currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()), variable.interpreted, variable.map)
                        } else {
                            variables[variable.name] = finaliseVariable(variable, interpreter: interpreter)
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
                    variables[variable.name] = finaliseVariable(variable, interpreter: interpreter)
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
    
    func finaliseVariable(_ variable: (name: String, value: String, interpreted: Bool, map: ValueMap), interpreter: GenericInterpreter) -> Any? {
        let value = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if variable.interpreted, let output = interpreter.evaluate(value) {
            return variable.map(output)
        }
        return variable.map(value)
    }
}

public class GenericInterpreter {
    let dataTypes: [DataTypeProtocol]
    let functions: [FunctionProtocol]
    let variables: [String: Any]
    
    init(dataTypes: [DataTypeProtocol] = [],
        functions: [FunctionProtocol] = [],
        variables: [String: Any] = [:]) {
        self.dataTypes = dataTypes
        self.functions = functions
        self.variables = variables
    }
    
    public func evaluate(_ expression: String) -> Any? {
        let expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for dataType in dataTypes.reversed() {
            if let value = dataType.convert(input: expression, interpreter: self) {
                return value
            }
        }
        for variable in variables where expression == variable.key {
            return variable.value
        }
        for function in functions.reversed() {
            if let value = function.convert(input: expression, interpreter: self) {
                return value
            }
        }
        return nil
    }
}
