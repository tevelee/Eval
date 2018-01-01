import Foundation

public class Literal<T> {
    let convert: (String, GenericInterpreterProtocol) -> T?
    
    init(convert: @escaping (String, GenericInterpreterProtocol) -> T?) {
        self.convert = convert
    }
    
    init(_ check: String, convertsTo value: T) {
        self.convert = { input,_ in check == input ? value : nil }
    }
    
    public func convert(input: String, interpreter: GenericInterpreterProtocol) -> T? {
        return convert(input, interpreter)
    }
}

public protocol DataTypeProtocol {
    func convert(input: String, interpreter: GenericInterpreterProtocol) -> Any?
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
    
    public func convert(input: String, interpreter: GenericInterpreterProtocol) -> Any? {
        return literals.flatMap{ $0.convert(input: input, interpreter: interpreter) }.first
    }
}

public protocol FunctionProtocol {
    func convert(input: String, interpreter: GenericInterpreterProtocol) -> Any?
}

typealias MatcherBlock<T, E: Evaluator> = ([String: Any], E) -> T?

public class Function<T> : FunctionProtocol {
    var patterns: [Matcher<T, GenericInterpreterProtocol>]
    
    init(patterns: [Matcher<T, GenericInterpreterProtocol>]) {
        self.patterns = patterns
    }
    
    init(_ elements: [MatchElement], matcher: @escaping MatcherBlock<T, GenericInterpreterProtocol>) {
        self.patterns = [Matcher(elements, matcher: matcher)]
    }
    
    public func convert(input: String, interpreter: GenericInterpreterProtocol) -> Any? {
        guard case let .exactMatch(_, output, _) = isStatement(statements: patterns, in: input, until: input.count, interpreter: interpreter) else { return nil }
        return output
    }
}

func isStatement<T, E>(statements: [Matcher<T, E>], in input: String, from start: Int = 0, until length: Int = 1, interpreter: E) -> MatchType<T> {
    let prefix = String(input[start ..< start + length])
    let isLast = input.count == start + length
    let results = statements.map { (element: $0, result: $0.matches(prefix: prefix, interpreter: interpreter, isLast: isLast)) }
    let elements = results.filter { !$0.result.isNoMatch() }
    
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

public typealias ValueMap<A, B> = (A) -> B?

protocol PlaceholderProtocol {
    var name: String { get }
    var shortest: Bool { get }
    var interpreted: Bool { get }
    func performMap(input: Any) -> Any?
}

public class Placeholder<T> : PlaceholderProtocol, MatchElement {
    let name: String
    let shortest: Bool
    let interpreted: Bool
    let map: ValueMap<Any, T>
    
    public init(_ name: String, shortest: Bool = true, interpreted: Bool = true, map: @escaping ValueMap<Any, T> = { $0 as? T }) {
        self.name = name
        self.shortest = shortest
        self.interpreted = interpreted
        self.map = map
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchType<Any> {
        return .anyMatch(shortest: shortest)
    }
    
    func mapped<K>(_ map: @escaping ValueMap<T, K>) -> Placeholder<K> {
        return Placeholder<K>(name, shortest: shortest, interpreted: interpreted, map: {
            guard let value = self.map($0) else { return nil }
            return map(value)
        })
    }
    
    func performMap(input: Any) -> Any? {
        return map(input)
    }
}

public class Matcher<T, E: Evaluator> {
    let elements: [MatchElement]
    let matcher: MatcherBlock<T, E>
    
    init(_ elements: [MatchElement],
         matcher: @escaping MatcherBlock<T, E>) {
        self.matcher = matcher

        var elements = elements
        if let last = elements.last as? Placeholder<E.T> {
            elements.removeLast()
            elements.append(Placeholder(last.name, shortest: false, map: last.map))
        }
        self.elements = elements
    }
    
    public func matches(prefix: String, interpreter: E, isLast: Bool = false) -> MatchType<T> {
        var elementIndex = 0
        var input = prefix
        var variables: [String: Any] = [:]
        var currentlyActiveVariable: (name: String, value: String, interpreted: Bool, map: ValueMap<Any, Any>)? = nil
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
                if !input.isEmpty, currentlyActiveVariable == nil, let variable = element as? PlaceholderProtocol {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()), variable.interpreted, variable.performMap)
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
        
        if let renderedOutput = matcher(variables, interpreter) {
            return .exactMatch(length: prefix.count - input.count, output: renderedOutput, variables: variables)
        } else {
            return .noMatch
        }
    }
    
    func finaliseVariable(_ variable: (name: String, value: String, interpreted: Bool, map: ValueMap<Any, Any>), interpreter: E) -> Any? {
        let value = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if variable.interpreted {
            let output = interpreter.evaluate(value)
            return variable.map(output)
        }
        return variable.map(value)
    }
}

public class InterpreterContext {
    var variables: [String: Any]
    
    init(variables: [String: Any] = [:]) {
        self.variables = variables
    }
}

public protocol Evaluator {
    associatedtype T
    var context: InterpreterContext { get }
    func evaluate(_ expression: String) -> T
}

public class GenericInterpreterProtocol: Evaluator {
    public typealias T = Any?
    public let context: InterpreterContext
    
    init(context: InterpreterContext) {
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> Any? {
        return nil
    }
}

public class GenericInterpreter : GenericInterpreterProtocol {
    let dataTypes: [DataTypeProtocol]
    let functions: [FunctionProtocol]
    
    init(dataTypes: [DataTypeProtocol] = [],
        functions: [FunctionProtocol] = [],
        context: InterpreterContext) {
        self.dataTypes = dataTypes
        self.functions = functions
        super.init(context: context)
    }
    
    public override func evaluate(_ expression: String) -> Any? {
        let expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for dataType in dataTypes.reversed() {
            if let value = dataType.convert(input: expression, interpreter: self) {
                return value
            }
        }
        for variable in context.variables where expression == variable.key {
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

public class TemplateInterpreter : Evaluator {
    public typealias T = String
    
    let statements: [Matcher<String, TemplateInterpreter>]
    public let context: InterpreterContext
    
    init(statements: [Matcher<String, TemplateInterpreter>],
         context: InterpreterContext) {
        self.statements = statements
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> String {
        var output = ""
        
        var position = 0
        repeat {
            let result = isStatement(statements: statements, in: expression, from: position, interpreter: self)
            switch result {
            case .noMatch:
                output += expression[position]
                position += 1
            case .exactMatch(let length, let matchOutput, _):
                output += matchOutput
                position += length
            default:
                assertionFailure("Invalid result")
            }
        } while position < expression.count
        
        return output
    }
}
