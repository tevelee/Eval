import Foundation

typealias VariableValue = (metadata: VariableProtocol, value: String)

protocol VariableProcessorProtocol {
    func process(_ variable: VariableValue) -> Any?
}

class VariableProcessor<E: Interpreter> : VariableProcessorProtocol {
    let interpreter: E
    let context: Context
    
    init(interpreter: E, context: Context) {
        self.interpreter = interpreter
        self.context = context
    }
    
    /// Maps and evaluates variable content, based on its interpretation settings
    /// - parameter variable: The variable to process
    /// - returns: The result of the matching operation
    func process(_ variable: VariableValue) -> Any? {
        let value = variable.metadata.trimmed ? variable.value.trim() : variable.value
        if variable.metadata.interpreted {
            let variableInterpreter = interpreter.interpreterForEvaluatingVariables
            let output = variableInterpreter.evaluate(value, context: context)
            return variable.metadata.performMap(input: output, interpreter: variableInterpreter)
        }
        return variable.metadata.performMap(input: value, interpreter: interpreter)
    }
}

class Matcher {
    let elements: [PatternElement]
    let processor: VariableProcessorProtocol
    let isBackward: Bool
    
    init(elements: [PatternElement], processor: VariableProcessorProtocol, isBackward: Bool = false) {
        self.elements = elements
        self.processor = processor
        self.isBackward = isBackward
    }
    
    fileprivate var currentlyActiveVariable: VariableValue? = nil
    
    /// Tries to append the next input character to the currently active variables - if we have any
    /// - returns: Whether the append was successful
    fileprivate func tryToAppendCurrentVariable(remainder: inout String) -> Bool {
        if let variable = currentlyActiveVariable {
            appendNextCharacterToVariable(variable, remainder: &remainder)
        }
        return currentlyActiveVariable != nil
    }
    
    /// Appends the next character to the provded variables
    /// - parameter variable: The variable to append to
    fileprivate func appendNextCharacterToVariable(_ variable: VariableValue, remainder: inout String) {
        if remainder.isEmpty {
            currentlyActiveVariable = (variable.metadata, variable.value)
        } else {
            if isBackward {
                currentlyActiveVariable = (variable.metadata, String(describing: remainder.removeLast()) + variable.value)
            } else {
                currentlyActiveVariable = (variable.metadata, variable.value + String(describing: remainder.removeFirst()))
            }
        }
    }
    
    /// An element to initialise the variable with
    /// - parameter element: The variable element
    fileprivate func initialiseVariable(_ element: PatternElement) {
        if currentlyActiveVariable == nil, let variable = element as? VariableProtocol {
            currentlyActiveVariable = (variable, "")
        }
    }
    
    /// When the recognition of a variable arrives to the final stage, function finalises its value and appends the variables array
    /// - returns: Whether the registration was successful (the finalisation resulted in a valid value)
    fileprivate func registerAndValidateVariable(variables: inout [String: Any]) -> Bool {
        if let variable = currentlyActiveVariable {
            let result = processor.process(variable)
            variables[variable.metadata.name] = result
            return !variable.metadata.acceptsNilValue && result != nil
        }
        return false
    }
    
    fileprivate func nextElement(_ elementIndex: inout Int) {
        elementIndex += isBackward ? -1 : 1
    }
    
    fileprivate func notFinished(_ elementIndex: Int) -> Bool {
        if isBackward {
            return elementIndex >= elements.startIndex
        } else {
            return elementIndex < elements.endIndex
        }
    }
    
    fileprivate func initialIndex() -> Int {
        if isBackward {
            return elements.index(before: elements.endIndex)
        } else {
            return elements.startIndex
        }
    }
    
    fileprivate func drop(_ remainder: String, length: Int) -> String {
        if isBackward {
            return String(remainder.dropLast(length))
        } else {
            return String(remainder.dropFirst(length))
        }
    }
    
    func match<T>(string: String, from start: Int = 0, renderer: @escaping (_ variables: [String: Any]) -> T?) -> MatchResult<T> {
        let trimmed = String(string[start...])
        var elementIndex = initialIndex()
        var remainder = trimmed
        var variables: [String: Any] = [:]
        
        repeat {
            let element = elements[elementIndex]
            let result = element.matches(prefix: remainder, isBackward: isBackward)
            
            switch result {
            case .noMatch:
                guard tryToAppendCurrentVariable(remainder: &remainder) else { return .noMatch }
            case .possibleMatch:
                return .possibleMatch
            case .anyMatch(let shortest):
                initialiseVariable(element)
                if shortest {
                    nextElement(&elementIndex)
                } else {
                    _ = tryToAppendCurrentVariable(remainder: &remainder)
                    if remainder.isEmpty {
                        guard registerAndValidateVariable(variables: &variables) else { return .possibleMatch }
                        nextElement(&elementIndex)
                    }
                }
            case .exactMatch(let length, _, let embeddedVariables):
                if isEmbedded(element: element, in: String(string[start...]), at: trimmed.count - remainder.count) {
                    let isSuccess = tryToAppendCurrentVariable(remainder: &remainder)
                    if !isSuccess {
                        nextElement(&elementIndex)
                    }
                } else {
                    variables.merge(embeddedVariables) { (key, _) in key }
                    if currentlyActiveVariable != nil {
                        guard registerAndValidateVariable(variables: &variables) else { return .noMatch }
                        currentlyActiveVariable = nil
                    }
                    nextElement(&elementIndex)
                    remainder = drop(remainder, length: length)
                    if notFinished(elementIndex) {
                        remainder = remainder.trim()
                    }
                }
            }
        } while notFinished(elementIndex)
        
        if let renderedOutput = renderer(variables) {
            return .exactMatch(length: string.count - start - remainder.count, output: renderedOutput, variables: variables)
        } else {
            return .noMatch
        }
    }
    
    /// Determines whether the current character is an `OpenKeyword`, so there might be another embedded match later
    /// - parameter element: The element to check whether it's an `OpenKeyword`
    /// - parameter in: The input
    /// - parameter at: The starting position to check from
    /// - returns: Whether the element conditions apply and the position is before the last one
    fileprivate func isEmbedded(element: PatternElement, in string: String, at currentPosition: Int) -> Bool {
        if let closingTag = element as? Keyword, closingTag.type == .closingStatement, let closingPosition = positionOfClosingTag(in: string),
            currentPosition < closingPosition {
            return true
        }
        return false
    }
    
    /// Determines whether the current character is an `OpenKeyword` and fins the position of its appropriate `ClosingKeyword` pair
    /// - parameter in: The input
    /// - parameter from: The starting position of the checking range
    /// - returns: `nil` if the `CloseKeyword` pair cannot be found. The position otherwise
    fileprivate func positionOfClosingTag(in string: String, from start: Int = 0) -> Int? {
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
                    if counter == 0 {
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
