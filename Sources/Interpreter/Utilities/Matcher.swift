import Foundation

typealias MatcherBlock<T, E: Evaluator> = ([String: Any], E) -> T?

public class Matcher<T, E: VariableEvaluator> {
    let elements: [MatchElement]
    let matcher: MatcherBlock<T, E>
    
    init(_ elements: [MatchElement],
         matcher: @escaping MatcherBlock<T, E>) {
        self.matcher = matcher
        
        var elements = elements
        if let last = elements.last as? GenericVariable<E.EvaluatedType, E> {
            elements.removeLast()
            elements.append(GenericVariable(last.name, shortest: false, map: last.map))
        }
        self.elements = elements
    }
    
    public func matches(string: String, from start: Int = 0, until length: Int = 1, interpreter: E) -> MatchResult<T> {
        let isLast = string.count == start + length
        let prefix = String(string[start ..< start + length])
        var elementIndex = 0
        var input = prefix
        var variables: [String: Any] = [:]
        var currentlyActiveVariable: (name: String, value: String, interpreted: Bool, acceptsNilValue: Bool, map: (Any, Any) -> Any?)? = nil
        repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: input, isLast: isLast)
            
            switch result {
            case .noMatch:
                if let variable = currentlyActiveVariable, !input.isEmpty {
                    currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()), variable.interpreted, variable.acceptsNilValue, variable.map)
                } else {
                    return .noMatch
                }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch(let shortest):
                if !input.isEmpty, currentlyActiveVariable == nil, let variable = element as? VariableProtocol {
                    currentlyActiveVariable = (variable.name, String(input.removeFirst()), variable.interpreted, variable.acceptsNilValue, variable.performMap)
                }
                if !shortest {
                    if isLast, let variable = currentlyActiveVariable {
                        if !input.isEmpty {
                            currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()), variable.interpreted, variable.acceptsNilValue, variable.map)
                        } else {
                            variables[variable.name] = finaliseVariable(variable, interpreter: interpreter)
                            if !variable.acceptsNilValue && variables[variable.name] == nil {
                                return .noMatch
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
                if isEmbedded(element: element, in: String(string[start...]), at: prefix.count - input.count) {
                    if let variable = currentlyActiveVariable, !input.isEmpty {
                        currentlyActiveVariable = (variable.name, variable.value + String(input.removeFirst()), variable.interpreted, variable.acceptsNilValue, variable.map)
                    } else {
                        elementIndex += 1
                    }
                } else {
                    variables.merge(embeddedVariables) { (key, value) in key }
                    if let variable = currentlyActiveVariable {
                        variables[variable.name] = finaliseVariable(variable, interpreter: interpreter)
                        if !variable.acceptsNilValue && variables[variable.name] == nil {
                            return .noMatch
                        }
                        currentlyActiveVariable = nil
                    }
                    input.removeFirst(length)
                    input = input.trim()
                    elementIndex += 1
                }
            }
        } while elementIndex < elements.count
        
        if let renderedOutput = matcher(variables, interpreter) {
            return .exactMatch(length: prefix.count - input.count, output: renderedOutput, variables: variables)
        } else {
            return .noMatch
        }
    }
    
    func finaliseVariable(_ variable: (name: String, value: String, interpreted: Bool, acceptsNilValue: Bool, map: (Any, Any) -> Any?), interpreter: E) -> Any? {
        let value = variable.value.trim()
        if variable.interpreted {
            let variableInterpreter = interpreter.interpreterForEvaluatingVariables
            let output = variableInterpreter.evaluate(value)
            return variable.map(output, variableInterpreter)
        }
        return variable.map(value, interpreter)
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
