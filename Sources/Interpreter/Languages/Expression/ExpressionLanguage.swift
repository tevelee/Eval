import Foundation

public protocol Renderer {
    func render(variables: [String: Any]) -> String
}

public class StaticRenderer: Renderer {
    let renderingBlock: ([String: Any]) -> String
    
    init(renderingBlock: @escaping ([String: Any]) -> String) {
        self.renderingBlock = renderingBlock
    }
    
    public func render(variables: [String: Any]) -> String {
        return self.renderingBlock(variables)
    }
}

public protocol Element {
    func matches(prefix: String, isLast: Bool) -> MatchResult
}

public class Pattern : Element {
    let elements: [Element]
    let renderer: Renderer
    
    public convenience init(_ elements: [Element], renderingBlock: @escaping ([String: Any]) -> String? = { _ in nil }) {
        self.init(elements, renderer: StaticRenderer(renderingBlock: { variables in renderingBlock(variables) ?? "" }))
    }
    
    public init(_ elements: [Element], renderer: Renderer) {
        var elements = elements
        if let last = elements.last as? Variable {
            elements.removeLast()
            elements.append(Variable(last.name, shortest: false))
        }
        self.elements = elements
        self.renderer = renderer
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult {
        var elementIndex = 0
        var input = prefix
        var variables: [String: String] = [:]
        var currentlyActiveVariable: (name: String, value: String)? = nil
        elementSearch: repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: input, isLast: isLast)
            
            switch result {
            case .noMatch:
                if let previous = currentlyActiveVariable, !input.isEmpty {
                    currentlyActiveVariable = (previous.name, previous.value + String(input.removeFirst()))
                } else {
                    return .noMatch
                }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch(let shortest):
                if !input.isEmpty, let variable = element as? Variable {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()))
                }
                if !shortest {
                    if isLast, let variable = currentlyActiveVariable {
                        variables[variable.name] = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        return .possibleMatch
                    }
                }
                elementIndex += 1
            case .exactMatch(let length, _, let embeddedVariables):
                variables.merge(embeddedVariables) { (key, value) in key }
                if let variable = currentlyActiveVariable {
                    variables[variable.name] = variable.value
                    currentlyActiveVariable = nil
                }
                input.removeFirst(length)
                input = input.trimmingCharacters(in: .whitespacesAndNewlines)
                elementIndex += 1
            }
        } while elementIndex < elements.count
        
        let renderedOutput = renderer.render(variables: variables)
        return .exactMatch(length: prefix.count - input.count, output: renderedOutput, variables: variables)
    }
}

public struct Keyword : Element {
    let name: String
    
    public init(_ name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult {
        if name == prefix || prefix.hasPrefix(name) {
            return .exactMatch(length: name.count, output: name, variables: [:])
        } else if name.hasPrefix(prefix) {
            return .possibleMatch
        } else {
            return .noMatch
        }
    }
}

public struct Variable : Element {
    let name: String
    let shortest: Bool
    
    public init(_ name: String, shortest: Bool = true) {
        self.name = name
        self.shortest = shortest
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult {
        return .anyMatch(shortest: shortest)
    }
}

public class StringExpressionInterpreter : Interpreter {
    let statements: [Pattern]
    
    public init(statements: [Pattern]) {
        self.statements = statements
    }
    
    public func evaluate(_ input: String) -> String {
        var output = ""
        
        var position = 0
        repeat {
            let result = isStatement(in: input, from: position)
            switch result {
            case .noMatch:
                output += input[position]
                position += 1
            case .exactMatch(let length, let matchOutput, _):
                output += matchOutput
                position += length
            default:
                assertionFailure("Invalid result")
            }
        } while position < input.count
        
        return output
    }
    
    func isStatement(in input: String, from start: Int, until length: Int = 1) -> MatchResult {
        let prefix = String(input[start ..< start + length])
        let isLast = input.count == start + length
        let elements = statements.map { (element: $0, result: $0.matches(prefix: prefix, isLast: isLast)) }.filter { $0.result != .noMatch }
        
        if elements.count == 0 {
            return .noMatch
        }
        if let matchingElement = elements.first(where: { $0.result.isMatch() }),
            case .exactMatch(let length, let output, let variables) = matchingElement.result {
            return .exactMatch(length: length, output: output, variables: variables)
        }
        if elements.contains(where: { $0.result == .possibleMatch }) {
            if isLast {
                return .noMatch
            } else {
                return isStatement(in: input, from: start, until: length + 1)
            }
        }
        return .noMatch
    }
}

public class NumericExpressionInterpreter : StringExpressionInterpreter {
    public func evaluate(_ expression: String) -> Double {
        return Double(evaluate(expression)) ?? 0
    }
}

public class BooleanExpressionInterpreter : StringExpressionInterpreter {
    public func evaluate(_ expression: String) -> Bool {
        return evaluate(expression) == "true"
    }
}
