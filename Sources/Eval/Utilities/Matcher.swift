/*
 *  Copyright (c) 2018 Laszlo Teveli.
 *
 *  Licensed to the Apache Software Foundation (ASF) under one
 *  or more contributor license agreements.  See the NOTICE file
 *  distributed with this work for additional information
 *  regarding copyright ownership.  The ASF licenses this file
 *  to you under the Apache License, Version 2.0 (the
 *  "License"); you may not use this file except in compliance
 *  with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

import Foundation

/// `MatcherBlock` is used by `Matcher` and `Function` classes when the matched expression should be processed in a custom way. It should return a strongly typed object after the evaluations.
/// The first parameter contains the values of every matched `Variable` instance.
/// The second parameter is the evaluator. If there is a need to process the value of the variable further, creators of this block can use this evaluator, whose value is always the interpreter currently in use
/// In its last parameter if provides information about the context, and therefore allows access to read or modify the context variables.
/// - parameter variables: The key-value pairs of the `Variable` instances found along the way
/// - parameter evaluator: The evaluator instance to help parsing the content
/// - parameter context: The context if the matcher block needs any contextual information
/// - returns: The converted value
public typealias MatcherBlock<T, E: Evaluator> = (_ variables: [String: Any], _ evaluator: E, _ context: InterpreterContext) -> T?

/// Matchers are the heart of the Eval framework, providing pattern matching capabilities to the library.
public class Matcher<T, E: Interpreter> {
    /// `Matcher` instances are capable of recognising patterns described in the `elements` collection. It only remains effective, if the `Variable` instances are surrounded by `Keyword` instances, so no two `Variable`s should be next to each other. Otherwise, their matching result and value would be undefined.
    /// This collection should be provided during the initialisation, and cannot be modified once the `Matcher` instance has been created.
    public let elements: [MatchElement]

    /// The block to process the elements with
    let matcher: MatcherBlock<T, E>

    /// The first parameter is the pattern, that needs to be recognised. The `matcher` ending closure is called whenever the pattern has successfully been recognised and allows the users of this framework to provide custom computations using the matched `Variable` values.
    /// - parameter elemenets: The pattern to recognise
    /// - parameter matcher: The block to process the input with
    public init(_ elements: [MatchElement],
                matcher: @escaping MatcherBlock<T, E>) {
        self.matcher = matcher
        self.elements = Matcher.elementsByReplacingTheLastVariableNotToBeShortestMatch(in: elements)
    }
    
    /// If the last element in the elements pattern is a variable, shortest match will not match until the end of the input string, but just until the first empty character.
    /// - parameter in: The elements array where the last element should be replaced
    /// - returns: A new collection of elements, where the last element is replaced, whether it's a variable with shortest flag on
    static func elementsByReplacingTheLastVariableNotToBeShortestMatch(in elements: [MatchElement]) -> [MatchElement] {
        var elements = elements
        if let last = elements.last as? GenericVariable<E.EvaluatedType, E> {
            elements.removeLast()
            elements.append(GenericVariable(last.name, shortest: false, interpreted: last.interpreted, acceptsNilValue: last.acceptsNilValue, map: last.map))
        } else if let last = elements.last as? VariableProtocol { //in case it cannot be converted, let's use Any, losing type information
            elements.removeLast()
            elements.append(GenericVariable<Any, E>(last.name, shortest: false, interpreted: last.interpreted, acceptsNilValue: last.acceptsNilValue, map: last.performMap))
        }
        return elements
    }

    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    /// This matcher provides the main logic of the `Eval` framework, performing the pattern matching, trying to identify, whether the input string is somehow related, or completely matches the pattern of the `Matcher` instance.
    /// - parameter string: The input
    /// - parameter from: The start of the range to analyse the result in
    /// - parameter until: The end of the range to analyse the result in
    /// - parameter interpreter: An interpreter instance - if the variables need any further evaluation
    /// - parameter context: The context - if the block uses any contextual data
    /// - returns: The result of the matching operation
    func matches(string: String, from start: Int = 0, until length: Int, interpreter: E, context: InterpreterContext) -> MatchResult<T> {
    // swiftlint:enable cyclomatic_complexity
    // swiftlint:enable function_body_length
        let isLast = string.count == start + length
        let trimmed = String(string[start ..< start + length])
        var elementIndex = 0
        var remainder = trimmed
        var variables: [String: Any] = [:]

        typealias VariableValue = (metadata: VariableProtocol, value: String)
        var currentlyActiveVariable: VariableValue? = nil

        /// Tries to append the next input character to the currently active variables - if we have any
        /// - returns: Whether the append was successful
        func tryToAppendCurrentVariable() -> Bool {
            if let variable = currentlyActiveVariable {
                appendNextCharacterToVariable(variable)
            }
            return currentlyActiveVariable != nil
        }

        /// Appends the next character to the provded variables
        /// - parameter variable: The variable to append to
        func appendNextCharacterToVariable(_ variable: VariableValue) {
            if remainder.isEmpty {
                currentlyActiveVariable = (variable.metadata, variable.value)
            } else {
                currentlyActiveVariable = (variable.metadata, variable.value + String(remainder.removeFirst()))
            }
        }

        /// An element to initialise the variable with
        /// - parameter element: The variable element
        func initialiseVariable(_ element: MatchElement) {
            if currentlyActiveVariable == nil, let variable = element as? VariableProtocol {
                currentlyActiveVariable = (variable, "")
            }
        }

        /// When the recognition of a variable arrives to the final stage, function finalises its value and appends the variables array
        /// - returns: Whether the registration was successful (the finalisation resulted in a valid value)
        func registerAndValidateVariable() -> Bool {
            if let variable = currentlyActiveVariable {
                variables[variable.metadata.name] = finaliseVariable(variable, interpreter: interpreter, context: context)
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
                                return .possibleMatch
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
                    variables.merge(embeddedVariables) { (key, _) in key }
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

    /// Maps and evaluates variable content, based on its interpretation settings
    /// - parameter variable: The variable to process
    /// - parameter metadata: Property-bag with the name, interpretation details, and map function of the variable
    /// - parameter value: The value of the variable
    /// - parameter interpreter: An interpreter instance - if the value needs any further evaluation
    /// - parameter context: The context - if the block uses any contextual data
    /// - returns: The result of the matching operation
    func finaliseVariable(_ variable: (metadata: VariableProtocol, value: String), interpreter: E, context: InterpreterContext) -> Any? {
        let value = variable.value.trim()
        if variable.metadata.interpreted {
            let variableInterpreter = interpreter.interpreterForEvaluatingVariables
            let output = variableInterpreter.evaluate(value, context: context)
            return variable.metadata.performMap(input: output, interpreter: variableInterpreter)
        }
        return variable.metadata.performMap(input: value, interpreter: interpreter)
    }

    /// Determines whether the current character is an `OpenKeyword`, so there might be another embedded match later
    /// - parameter element: The element to check whether it's an `OpenKeyword`
    /// - parameter in: The input
    /// - parameter at: The starting position to check from
    /// - returns: Whether the element conditions apply and the position is before the last one
    func isEmbedded(element: MatchElement, in string: String, at currentPosition: Int) -> Bool {
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
