import Foundation

public typealias MatcherBlock<T, E: Evaluator> = ([String: Any], E, InterpreterContext) -> T?

public class Matcher<T, E: VariableEvaluator> {
    let elements: [MatchElement]
    let matcher: MatcherBlock<T, E>
    
    public init(_ elements: [MatchElement],
                matcher: @escaping MatcherBlock<T, E>) {
        self.matcher = matcher
        
        var elements = elements
        if let last = elements.last as? GenericVariable<E.EvaluatedType, E> {
            elements.removeLast()
            elements.append(GenericVariable(last.name, shortest: false, map: last.map))
        }
        self.elements = elements
    }
    
    public func matches(string: String, from start: Int = 0, until length: Int, interpreter: E, context: InterpreterContext) -> MatchResult<T> {
        let isLast = string.count == start + length
        let trimmed = String(string[start ..< start + length])
        var elementIndex = 0
        var remainder = trimmed
        var variables: [String: Any] = [:]
        
        typealias VariableValue = (metadata: VariableProtocol, value: String)
        var currentlyActiveVariable: VariableValue? = nil
        func tryToAppendCurrentVariable() -> Bool {
            if let variable = currentlyActiveVariable {
                appendNextCharacterToVariable(variable)
            }
            return currentlyActiveVariable != nil
        }
        func appendNextCharacterToVariable(_ variable: VariableValue) {
            if !remainder.isEmpty {
                currentlyActiveVariable = (variable.metadata, variable.value + String(remainder.removeFirst()))
            }
        }
        func initialiseVariable(_ element: MatchElement) {
            if currentlyActiveVariable == nil, let variable = element as? VariableProtocol {
                appendNextCharacterToVariable((variable, ""))
            }
        }
        func registerAndValidateVariable() -> Bool {
            if let variable = currentlyActiveVariable {
                variables[variable.metadata.name] = finaliseVariable(variable, interpreter: interpreter)
                return !variable.metadata.acceptsNilValue && variables[variable.metadata.name] != nil
            }
            return false
        }
        
        repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: remainder, isLast: isLast)
            
            switch result {
            case .noMatch:
                if !tryToAppendCurrentVariable() {
                    return .noMatch
                }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch(let shortest):
                initialiseVariable(element)
                if shortest {
                    elementIndex += 1
                } else {
                    if isLast {
                        _ = tryToAppendCurrentVariable()
                        if remainder.isEmpty {
                            if !registerAndValidateVariable() {
                                return .noMatch
                            }
                            elementIndex += 1
                        }
                    } else {
                        return .possibleMatch
                    }
                }
            case .exactMatch(let length, _, let embeddedVariables):
                if isEmbedded(element: element, in: String(string[start...]), at: trimmed.count - remainder.count) {
                    if !tryToAppendCurrentVariable() {
                        elementIndex += 1
                    }
                } else {
                    variables.merge(embeddedVariables) { (key, value) in key }
                    if currentlyActiveVariable != nil {
                        if !registerAndValidateVariable() {
                            return .noMatch
                        }
                        currentlyActiveVariable = nil
                    }
                    remainder.removeFirst(length)
                    remainder = remainder.trim()
                    elementIndex += 1
                }
            }
        } while elementIndex < elements.count
        
        if let renderedOutput = matcher(variables, interpreter, context) {
            return .exactMatch(length: length - remainder.count, output: renderedOutput, variables: variables)
        } else {
            return .noMatch
        }
    }
    
    func finaliseVariable(_ variable: (metadata: VariableProtocol, value: String), interpreter: E) -> Any? {
        let value = variable.value.trim()
        if variable.metadata.interpreted {
            let variableInterpreter = interpreter.interpreterForEvaluatingVariables
            let output = variableInterpreter.evaluate(value)
            return variable.metadata.performMap(input: output, interpreter: variableInterpreter)
        }
        return variable.metadata.performMap(input: value, interpreter: interpreter)
    }
    
    func isEmbedded(element: MatchElement, in string: String, at currentPosition: Int) -> Bool {
        if let closingTag = element as? Keyword, closingTag.type == .closingStatement, let closingPosition = positionOfClosingTag(in: string),
            currentPosition < closingPosition {
            return true
        }
        return false
    }
    
    func positionOfClosingTag(in string: String, from start: Int = 0) -> Int? {
        if let opening = elements.first(where: { ($0 as? Keyword)?.type == .openingStatement }) as? Keyword,
            let closing = elements.first(where: { ($0 as? Keyword)?.type == .closingStatement }) as? Keyword {
            var counter = 0
            var position = start
            repeat {
                var isCloseTagEarlier = false
                if let open = string.position(of: opening.name, from: position),
                    let close = string.position(of: closing.name, from: position),
                    close < open {
                    isCloseTagEarlier = true
                }
                
                if let open = string.position(of: opening.name, from: position), !isCloseTagEarlier {
                    counter += 1
                    position = open + opening.name.count
                } else if let close = string.position(of: closing.name, from: position) {
                    counter -= 1
                    if (counter == 0) {
                        return close
                    }
                    position = close + closing.name.count
                } else {
                    break
                }
            } while true
        }
        return nil
    }
}
