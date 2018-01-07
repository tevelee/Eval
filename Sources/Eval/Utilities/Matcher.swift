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
public typealias MatcherBlock<T, E: Evaluator> = ([String: Any], E, InterpreterContext) -> T?

/// Matchers are the heart of the Eval framework, providing pattern matching capabilities to the library.
public class Matcher<T, E: Interpreter> {
    /// `Matcher` instances are capable of recognising patterns described in the `elements` collection. It only remains effective, if the `Variable` instances are surrounded by `Keyword` instances, so no two `Variable`s should be next to each other. Otherwise, their matching result and value would be undefined.
    /// This collection should be provided during the initialisation, and cannot be modified once the `Matcher` instance has been created.
    public let elements: [MatchElement]
    let matcher: MatcherBlock<T, E>

    /// The first parameter is the pattern, that needs to be recognised. The `matcher` ending closure is called whenever the pattern has successfully been recognised and allows the users of this framework to provide custom computations using the matched `Variable` values.
    public init(_ elements: [MatchElement],
                matcher: @escaping MatcherBlock<T, E>) {
        self.matcher = matcher

        var elements = elements
        if let last = elements.last as? GenericVariable<E.EvaluatedType, E> {
            elements.removeLast()
            elements.append(GenericVariable(last.name, shortest: false, interpreted: last.interpreted, acceptsNilValue: last.acceptsNilValue, map: last.map))
        }
        self.elements = elements
    }

    /// This matcher provides the main logic of the `Eval` framework, performing the pattern matching, trying to identify, whether the input string is somehow related, or completely matches the pattern of the `Matcher` instance.
    func matches(string: String, from start: Int = 0, until length: Int, interpreter: E, context: InterpreterContext) -> MatchResult<T> {
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

    func finaliseVariable(_ variable: (metadata: VariableProtocol, value: String), interpreter: E, context: InterpreterContext) -> Any? {
        let value = variable.value.trim()
        if variable.metadata.interpreted {
            let variableInterpreter = interpreter.interpreterForEvaluatingVariables
            let output = variableInterpreter.evaluate(value, context: context)
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
