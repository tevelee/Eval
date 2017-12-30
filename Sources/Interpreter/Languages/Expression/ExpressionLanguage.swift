import Foundation
import Expression

public protocol RenderingFeature {
    weak var platform: RenderingPlatform? { get }
    init(platform: RenderingPlatform)
}

public protocol StringInterpreterProviderFeature: RenderingFeature {
    func stringExpressionInterpreter() -> StringExpressionInterpreter
}

public protocol BooleanInterpreterProviderFeature: RenderingFeature {
    func booleanExpressionInterpreter() -> BooleanExpressionInterpreter
}

public protocol NumericInterpreterProviderFeature: RenderingFeature {
    func numericExpressionInterpreter() -> NumericExpressionInterpreter
}

public class RenderingPlatform {
    var capabilities: [RenderingFeature]
    
    public init(capabilities: [RenderingFeature] = []) {
        self.capabilities = capabilities
    }
    
    public func add(capability: RenderingFeature) {
        capabilities.append(capability)
    }
    
    public func add<T: RenderingFeature>(capability type: T.Type) -> T {
        let capability = type.init(platform: self)
        capabilities.append(capability)
        return capability
    }
    
    public func capability<T>(of type: T.Type) -> T? {
        return capabilities.first { $0 is T } as? T
    }
}

public protocol Renderer {
    func render(platform: RenderingPlatform, variables: [String: Any]) -> String
}

public typealias RenderingBlock = (RenderingPlatform, [String: Any]) -> String

class BlockRenderer: Renderer {
    let renderingBlock: RenderingBlock
    
    init(renderingBlock: @escaping RenderingBlock) {
        self.renderingBlock = renderingBlock
    }
    
    public func render(platform: RenderingPlatform, variables: [String: Any]) -> String {
        return self.renderingBlock(platform, variables)
    }
}

public protocol Element {
    func matches(prefix: String, isLast: Bool) -> MatchResult
}

public class Pattern : Element {
    let elements: [Element]
    let renderer: Renderer
    let charactersToIgnore: CharacterSet = .whitespacesAndNewlines
    let platform: RenderingPlatform
    
    public init(_ elements: [Element],
                platform: RenderingPlatform? = nil,
                renderingBlock: @escaping RenderingBlock = { _,_ in "" }) {
        var elements = elements
        if let last = elements.last as? Variable {
            elements.removeLast()
            elements.append(Variable(last.name, shortest: false))
        }
        self.elements = elements
        self.platform = platform ?? RenderingPlatform(capabilities: [])
        self.renderer = BlockRenderer(renderingBlock: renderingBlock)
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
                if !input.isEmpty, currentlyActiveVariable == nil, let variable = element as? Variable {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()))
                }
                if !shortest {
                    if isLast, let variable = currentlyActiveVariable {
                        variables[variable.name] = variable.value.trimmingCharacters(in: charactersToIgnore)
                        if !input.isEmpty {
                            currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()))
                        } else {
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
                    variables[variable.name] = variable.value
                    currentlyActiveVariable = nil
                }
                input.removeFirst(length)
                input = input.trimmingCharacters(in: charactersToIgnore)
                elementIndex += 1
            }
        } while elementIndex < elements.count
        
        let renderedOutput = render(variables: variables)
        return .exactMatch(length: prefix.count - input.count, output: renderedOutput, variables: variables)
    }
    
    func render(variables: [String: String]) -> String {
        return renderer.render(platform: platform, variables: variables)
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
    var statements: [Pattern]
    
    public init(statements: [Pattern] = []) {
        self.statements = statements
    }
    
    public func evaluate(_ input: String) throws -> String {
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
        let elements = statements
            .map { (element: $0, result: $0.matches(prefix: prefix, isLast: isLast)) }
            .filter { $0.result != .noMatch }
        
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

public class NumericExpressionInterpreter : Interpreter {
    let platform: RenderingPlatform?
    
    public required init(platform: RenderingPlatform?) {
        self.platform = platform
    }
    
    public func evaluate(_ expression: String) throws -> Double {
        return try evaluateExpression(expression, platform: platform)
    }
}

public class BooleanExpressionInterpreter : Interpreter {
    let platform: RenderingPlatform?
    
    public required init(platform: RenderingPlatform?) {
        self.platform = platform
    }
    
    public func evaluate(_ expression: String) throws -> Bool {
        return try evaluateExpression(expression, options: .boolSymbols, platform: platform) == 1
    }
}

func evaluateExpression(_ expression: String, options: Expression.Options = [], platform: RenderingPlatform?) throws -> Double {
    var symbols: [Expression.Symbol: ([Double]) -> Double] = [:]
    if let context = platform?.capability(of: ContextHandlerFeature.self)?.context {
        for (_, variable) in context.variables.mapValues({ (variable) -> Double? in
            if let value = variable as? String, let double = Double(value) {
                return double
            } else if let value = variable as? Int {
                return Double(value)
            } else if let value = variable as? Float {
                return Double(value)
            } else if let value = variable as? Double {
                return value
            }
            return nil
        }).enumerated() where variable.value != nil {
            symbols[.variable(variable.key)] = { _ in variable.value! }
        }
    }
    
    return try Expression(expression, options: options, constants: [:], arrays: [:], symbols: symbols).evaluate()
}
