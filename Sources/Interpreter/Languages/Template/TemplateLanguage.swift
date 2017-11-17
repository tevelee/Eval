import Foundation

public protocol Element {
    func matches(prefix: String) -> MatchResult
}

public struct Pattern : Element {
    let elements: [Element]
    let renderer: ([String: String]) -> String?
    
    public init(_ elements: [Element], renderer: @escaping ([String: String]) -> String? = { _ in nil }) {
        self.elements = elements
        self.renderer = renderer
    }
    
    public func matches(prefix: String) -> MatchResult {
        var elementIndex = 0
        var input = prefix
        var variables: [String: String] = [:]
        var currentlyActiveVariable: (name: String, value: String)? = nil
        elementSearch: repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: input)
            
            switch result {
            case .noMatch:
                if let previous = currentlyActiveVariable, !input.isEmpty {
                    currentlyActiveVariable = (previous.name, previous.value + String(input.removeFirst()))
                } else {
                    return .noMatch
                }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch:
                if !input.isEmpty, let variable = element as? Variable {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()))
                }
                elementIndex += 1
            case .exactMatch(let length, _, let embeddedVariables):
                variables.merge(embeddedVariables) { (key, value) in key }
                if let variable = currentlyActiveVariable {
                    variables[variable.name] = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    currentlyActiveVariable = nil
                }
                input.removeFirst(length)
                input = input.trimmingCharacters(in: .whitespacesAndNewlines)
                elementIndex += 1
            }
        } while elementIndex < elements.count
        
        let renderedOutput = renderer(variables) ?? ""
        return .exactMatch(length: prefix.count - input.count, output: renderedOutput, variables: variables)
    }
}

public struct Keyword : Element {
    let name: String
    
    public init(_ name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func matches(prefix: String) -> MatchResult {
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
    
    public init(_ name: String) {
        self.name = name
    }
    
    public func matches(prefix: String) -> MatchResult {
        return .anyMatch
    }
}

public class TemplateLanguageInterpreter : Interpreter {
    let statements: [Pattern]
    
    init(statements: [Pattern]) {
        self.statements = statements
    }
    
    public func interpret(_ input: String) -> String {
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
        let elements = statements.map { (element: $0, result: $0.matches(prefix: prefix)) }.filter { $0.result != .noMatch }
        
        if elements.count == 0 {
            return .noMatch
        }
        if let matchingElement = elements.first(where: { $0.result.isMatch() }),
            case .exactMatch(let length, let output, let variables) = matchingElement.result {
            return .exactMatch(length: length, output: output, variables: variables)
        }
        if elements.contains(where: { $0.result == .possibleMatch }) {
            if input.count == start + length {
                return .exactMatch(length: start + length, output: prefix, variables: [:]) //FIXME: is this really a match?
            } else {
                return isStatement(in: input, from: start, until: length + 1)
            }
        }
        return .noMatch
    }
}
