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

/// A protocol which is capable of evaluating string expressions to a strongly typed object
public protocol Evaluator {
    associatedtype EvaluatedType

    /// The only method in `Evaluator` protocol which does the evaluation of a string expression, and returns a strongly typed object
    /// - parameter expression: The input
    /// - returns: The evaluated value
    func evaluate(_ expression: String) -> EvaluatedType
}

/// A special kind of evaluator which uses an `InterpreterContext` instance to evaluate expressions
/// The context contains variables which can be used during the evaluation
public protocol EvaluatorWithContext: Evaluator {
    /// Evaluates the provided string expression with the help of the context parameter, and returns a strongly typed object
    /// - parameter expression: The input
    /// - parameter context: The local context if there is something expression specific needs to be provided
    /// - returns: The evaluated value
    func evaluate(_ expression: String, context: InterpreterContext) -> EvaluatedType
}

/// A protocol which stores one `InterpreterContext` instance
public protocol ContextAware {
    /// The stored context object for helping evaluation and providing persistency
    var context: InterpreterContext { get }
}

/// The base protocol of interpreters, that are context-aware, and capable of recursively evaluating variables. They use the evaluate method as their main input
public protocol Interpreter: EvaluatorWithContext, ContextAware {
    associatedtype VariableEvaluator: EvaluatorWithContext
    /// Sometimes interpreters don't use themselves to evaluate variables by default, maybe a third party, or another contained interpreter. For example, the `StringTemplateInterpreter` class uses `TypedInterpreter` instance to evaluate its variables.
    var interpreterForEvaluatingVariables: VariableEvaluator { get }
}

/// The only responsibility of the `InterpreterContext` class is to store variables, and keep them during the execution, where multiple expressions might use the same set of variables.
public class InterpreterContext {
    /// The stored variables
    public var variables: [String: Any]

    /// Users of the context may optionally provide an initial set of variables
    /// - parameter variables: Variable names and values
    public init(variables: [String: Any] = [:]) {
        self.variables = variables
    }

    /// Creates a new context instance by merging their variable dictionaries. The one in the parameter overrides the duplicated of the existing one
    /// - parameter with: The other context to merge with
    /// - returns: A new `InterpreterContext` instance with the current and the parameter variables merged inside
    func merge(with other: InterpreterContext?) -> InterpreterContext {
        if let other = other {
            return InterpreterContext(variables: other.variables.merging(self.variables) { (key, _) in key })
        } else {
            return self
        }
    }
}

/// This is where the `Matcher` is able to determine the `MatchResult` for a given input inside the provided substring range
/// - parameter amongst: All the `Matcher` instances to evaluate, in priority order
/// - parameter in: The input
/// - parameter from: The start of the checked range
/// - parameter until: The end of the checked range
/// - parameter interpreter: An interpreter instance - if variables need any further evaluation
/// - parameter context: The context - if variables need any contextual information
/// - returns: The result of the match operation
func matchStatement<T, E>(amongst statements: [Matcher<T, E>], in input: String, from start: Int = 0, until length: Int = 1, interpreter: E, context: InterpreterContext) -> MatchResult<T> {
    let results = statements.map { statement -> (element: Matcher<T, E>, result: MatchResult<T>) in
        let result = statement.matches(string: input, from: start, until: length, interpreter: interpreter, context: context)
        return (element: statement, result: result)
    }
    let elements = results.filter { !$0.result.isNoMatch() }

    if elements.isEmpty {
        return .noMatch
    }
    if let matchingElement = elements.first(where: { $0.result.isMatch() }),
        case .exactMatch(let length, let output, let variables) = matchingElement.result {
        return .exactMatch(length: length, output: output, variables: variables)
    }
    if elements.contains(where: { $0.result.isPossibleMatch() }) {
        if input.count == start + length {
            return .possibleMatch
        } else {
            return matchStatement(amongst: statements, in: input, from: start, until: length + 1, interpreter: interpreter, context: context)
        }
    }
    return .noMatch
}
