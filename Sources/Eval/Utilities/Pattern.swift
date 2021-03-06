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

/// It's a data transfer object passed in the `Pattern` matcher block
public struct PatternBody<E: Evaluator> {
    /// The key-value pairs of the `Variable` instances found along the way
    public var variables: [String: Any]
    /// The evaluator instance to help parsing the content
    public var interpreter: E
    /// The context if the matcher block needs any contextual information
    public var context: Context
}

/// `MatcherBlock` is used by `Matcher` and `Function` classes when the matched expression should be processed in a custom way. It should return a strongly typed object after the evaluations.
/// The first parameter contains the values of every matched `Variable` instance.
/// The second parameter is the evaluator. If there is a need to process the value of the variable further, creators of this block can use this evaluator, whose value is always the interpreter currently in use
/// In its last parameter if provides information about the context, and therefore allows access to read or modify the context variables.
/// - parameter body: Struct containing the matched variables, an interpreter, and a context
/// - returns: The converted value
public typealias MatcherBlock<T, E: Evaluator> = (_ body: PatternBody<E>) -> T?

/// Options that modify the pattern matching algorithm
public struct PatternOptions: OptionSet {
    /// Integer representation of the option
    public let rawValue: Int
    /// Basic initialiser with the integer representation
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Searches of the elements of the pattern backward from the end of the output. Othwerise, if not present, it matches from the beginning.
    public static let backwardMatch: PatternOptions = PatternOptions(rawValue: 1 << 0)
}

/// Pattern consists of array of elements
public protocol PatternProtocol {
    /// `Matcher` instances are capable of recognising patterns described in the `elements` collection. It only remains effective, if the `Variable` instances are surrounded by `Keyword` instances, so no two `Variable`s should be next to each other. Otherwise, their matching result and value would be undefined.
    /// This collection should be provided during the initialisation, and cannot be modified once the `Matcher` instance has been created.
    var elements: [PatternElement] { get }

    /// Options that modify the pattern matching algorithm
    var options: PatternOptions { get }

    /// Optional name to identify the pattern. If not provided during initialisation, it will fall back to the textual representation of the elements array
    var name: String { get }
}

/// Pattern consists of array of elements
public class Pattern<T, I: Interpreter>: PatternProtocol {
    /// `Matcher` instances are capable of recognising patterns described in the `elements` collection. It only remains effective, if the `Variable` instances are surrounded by `Keyword` instances, so no two `Variable`s should be next to each other. Otherwise, their matching result and value would be undefined.
    /// This collection should be provided during the initialisation, and cannot be modified once the `Matcher` instance has been created.
    public let elements: [PatternElement]

    /// The block to process the elements with
    let matcher: MatcherBlock<T, I>

    /// Options that modify the pattern matching algorithm
    public let options: PatternOptions

    /// Optional name to identify the pattern. If not provided during initialisation, it will fall back to the textual representation of the elements array
    public let name: String

    /// The first parameter is the pattern, that needs to be recognised. The `matcher` ending closure is called whenever the pattern has successfully been recognised and allows the users of this framework to provide custom computations using the matched `Variable` values.
    /// - parameter elemenets: The pattern to recognise
    /// - parameter name: Optional identifier for the pattern. Defaults to the string representation of the elements
    /// - parameter options: Options that modify the pattern matching algorithm
    /// - parameter matcher: The block to process the input with
    public init(_ elements: [PatternElement],
                name: String? = nil,
                options: PatternOptions = [],
                matcher: @escaping MatcherBlock<T, I>) {
        self.name = name ?? Pattern.stringify(elements: elements)
        self.matcher = matcher
        self.options = options
        self.elements = Pattern.elementsByReplacingTheLastVariableNotToBeShortestMatch(in: elements, options: options)
    }

    /// If the last element in the elements pattern is a variable, shortest match will not match until the end of the input string, but just until the first empty character.
    /// - parameter in: The elements array where the last element should be replaced
    /// - parameter options: Options that modify the pattern matching algorithm
    /// - returns: A new collection of elements, where the last element is replaced, whether it's a variable with shortest flag on
    static func elementsByReplacingTheLastVariableNotToBeShortestMatch(in elements: [PatternElement], options: PatternOptions) -> [PatternElement] {
        var elements = elements
        let index = options.contains(.backwardMatch) ? elements.startIndex : elements.index(before: elements.endIndex)

        /// Replaces the last element in the elements collection with the new one in the parmeter
        /// - parameter element: The element to be replaced
        /// - parameter new: The replacement
        /// - parameter previousOptions: The element to be replaced
        func replaceLast(_ element: VariableProtocol, with new: (_ previousOptions: VariableOptions) -> PatternElement) {
            elements.remove(at: index)
            elements.insert(new(element.options.union(.exhaustiveMatch)), at: index)
        }

        if let last = elements[index] as? GenericVariable<I.EvaluatedType, I>, !last.options.contains(.exhaustiveMatch) {
            replaceLast(last) { GenericVariable(last.name, options: $0, map: last.map) }
        } else if let last = elements[index] as? VariableProtocol, !last.options.contains(.exhaustiveMatch) { //in case it cannot be converted, let's use Any. Losing type information
            replaceLast(last) { GenericVariable<Any, I>(last.name, options: $0) { last.performMap(input: $0.value, interpreter: $0.interpreter) } }
        }
        return elements
    }

    /// This matcher provides the main logic of the `Eval` framework, performing the pattern matching, trying to identify, whether the input string is somehow related, or completely matches the pattern of the `Pattern` instance.
    /// Uses the `Matcher` class for the evaluation
    /// - parameter string: The input
    /// - parameter from: The start of the range to analyse the result in
    /// - parameter interpreter: An interpreter instance - if the variables need any further evaluation
    /// - parameter context: The context - if the block uses any contextual data
    /// - parameter connectedRanges: Ranges of string indices that are connected with opening-closing tag pairs, respectively
    /// - returns: The result of the matching operation
    func matches(string: String, from start: String.Index? = nil, interpreter: I, context: Context, connectedRanges: [ClosedRange<String.Index>] = []) -> MatchResult<T> {
        let start = start ?? string.startIndex
        let processor = VariableProcessor(interpreter: interpreter, context: context)
        let matcher = Matcher(pattern: self, processor: processor)
        let result = matcher.match(string: string, from: start, connectedRanges: connectedRanges) { variables in
            self.matcher(PatternBody(variables: variables, interpreter: interpreter, context: context))
        }

        if case let .exactMatch(_, output, variables) = result {
            let input = String(string[start...])
            context.debugInfo[input] = ExpressionInfo(input: input, output: output, pattern: elementsAsString(), patternName: name, variables: variables)
        }

        return result
    }

    /// A textual representation of the Pattern's elements array
    /// - returns: A stringified version of the input elements
    func elementsAsString() -> String {
        return Pattern.stringify(elements: elements)
    }

    /// A textual representation of the elements array
    /// - returns: A stringified version of the input elements
    static func stringify(elements: [PatternElement]) -> String {
        return elements.map {
            if let keyword = $0 as? Keyword {
                return keyword.name
            } else if let variable = $0 as? VariableProtocol {
                return "{\(variable.name)}"
            }
            return ""
        }.joined(separator: " ")
    }
}
