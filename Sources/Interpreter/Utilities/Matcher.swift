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
    
    public func matches(prefix: String, interpreter: E, isLast: Bool = false) -> MatchResult<T> {
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
                variables.merge(embeddedVariables) { (key, value) in key }
                if let variable = currentlyActiveVariable {
                    variables[variable.name] = finaliseVariable(variable, interpreter: interpreter)
                    if !variable.acceptsNilValue && variables[variable.name] == nil {
                        return .noMatch
                    }
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
    
    func finaliseVariable(_ variable: (name: String, value: String, interpreted: Bool, acceptsNilValue: Bool, map: (Any, Any) -> Any?), interpreter: E) -> Any? {
        let value = variable.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if variable.interpreted {
            let variableInterpreter = interpreter.interpreterForEvaluatingVariables
            let output = variableInterpreter.evaluate(value)
            return variable.map(output, variableInterpreter)
        }
        return variable.map(value, interpreter)
    }
}
