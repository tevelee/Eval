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

/// A type of interpreter implementation that is capable of evaluating arbitrary string expressions to strongly typed variables
public class TypedInterpreter: Interpreter {
    /// The result is a strongly typed value or `nil` (if it cannot be properly processed)
    public typealias EvaluatedType = Any?

    /// The global context used for every evaluation with this instance
    public let context: InterpreterContext

    /// The interpreter used for evaluating variable values. In case of the `TypedInterpreter`, it's itself
    public lazy var interpreterForEvaluatingVariables: TypedInterpreter = { [unowned self] in self }()

    /// The data types that the expression is capable of recognise
    public let dataTypes: [DataTypeProtocol]

    /// The list of functions that are available during the evaluation to process the recognised data types
    public let functions: [FunctionProtocol]

    /// Each item of the input list (data types, functions and the context) is optional, but strongly recommended to provide them. It's usual that for every data type, there are a few functions provided, so the list can occasionally be pretty long.
    public init(dataTypes: [DataTypeProtocol] = [],
                functions: [FunctionProtocol] = [],
                context: InterpreterContext = InterpreterContext()) {
        self.dataTypes = dataTypes
        self.functions = functions
        self.context = context
    }

    /// The evaluation method, that produces the strongly typed results. In this case, only the globally available context can be used
    public func evaluate(_ expression: String) -> Any? {
        return evaluate(expression, context: InterpreterContext())
    }

    /// The evaluation method, that produces the strongly typed results. In this case, only the context is a result of merging the global context and the one provided in the parameter
    public func evaluate(_ expression: String, context: InterpreterContext) -> Any? {
        let context = self.context.merge(with: context)
        let expression = expression.trim()

        for dataType in dataTypes.reversed() {
            if let value = dataType.convert(input: expression, interpreter: self) {
                return value
            }
        }
        for variable in context.variables where expression == variable.key {
            return variable.value
        }
        for function in functions.reversed() {
            if let value = function.convert(input: expression, interpreter: self, context: context) {
                return value
            }
        }
        return nil
    }

    /// A helper to be able to effectively print any result, coming out of the evaluation. The `print` method recognises the used data type and uses its string conversion block
    public func print(_ input: Any) -> String {
        for dataType in dataTypes {
            if let value = dataType.print(value: input) {
                return value
            }
        }
        return ""
    }
}

/// Data types tell the framework which kind of data can be parsed in the expressions
public protocol DataTypeProtocol {
    /// If the framework meets with some static value that hasn't been processed before, it tries to convert it with every registered data type.
    /// This method returns nil if the conversion could not have been processed with any of the type's literals.
    func convert(input: String, interpreter: TypedInterpreter) -> Any?

    /// This is a convenience method, for debugging and value printing purposes, which can return a string from the current data type.
    /// It does not need to be unique or always the same for the same input values.
    func print(value input: Any) -> String?
}

/// The implementation of a `DataType` uses the `DataTypeProtocol` to convert input to a strongly typed data and print it if needed
public class DataType<T> : DataTypeProtocol {
    let type: T.Type
    let literals: [Literal<T>]
    let print: (T) -> String

    /// To be able to bridge the outside world effectively, it needs to provide an already existing Swift or user-defined type. This can be class, struct, enum, or anything else, for example, block or function (which is not recommended).
    /// The literals tell the framework which strings can be represented in the given data type
    /// The last print block is used to convert the value of any DataType to a string value. It does not need to be unique or always the same for the same input values.
    public init (type: T.Type,
                 literals: [Literal<T>],
                 print: @escaping (T) -> String) {
        self.type = type
        self.literals = literals
        self.print = print
    }

    /// For the conversion it uses the registered literals, to be able to process the input and return an existing type
    public func convert(input: String, interpreter: TypedInterpreter) -> Any? {
        return literals.flatMap { $0.convert(input: input, interpreter: interpreter) }.first
    }

    /// This is a convenience method, for debugging and value printing purposes, which can return a string from the current data type.
    /// It does not need to be unique or always the same for the same input values.
    public func print(value input: Any) -> String? {
        guard let input = input as? T else { return nil }
        return self.print(input)
    }
}

/// `Literal`s are used by `DataType`s to be able to recognise static values, that can be expressed as a given type
public class Literal<T> {
    let convert: (String, TypedInterpreter) -> T?

    /// In case of more complicated expression, this initialiser accepts a `convert` block, which can be used to process static values. Return nil, if the input cannot be accepted and converted.
    public init(convert: @escaping (String, TypedInterpreter) -> T?) {
        self.convert = convert
    }

    /// In case the literals are easily expressed, static keywords, then this initialiser is the best to use.
    /// The first parameter is the used keyword; the second one is the statically typed associated value. As it is expressed as an autoclosure, the provided expression will be evaluated at recognition time, not initialisation time. For example, Date() is perfectly acceptable to use here.
    public init(_ check: String, convertsTo value: @autoclosure @escaping () -> T) {
        self.convert = { input, _ in check == input ? value() : nil }
    }

    func convert(input: String, interpreter: TypedInterpreter) -> T? {
        return convert(input, interpreter)
    }
}

/// `Function`s can process values in given `DataType`s, allowing the expressions to be feature-rich
public protocol FunctionProtocol {
    /// Functions use similar conversion methods as `DataType`s. If they return `nil`, the function does not apply to the given input. Otherwise, the result is expressed as an instance of a given `DataType`
    /// It uses the interpreter the and parsing context to be able to effectively process the content
    func convert(input: String, interpreter: TypedInterpreter, context: InterpreterContext) -> Any?
}

/// `Function`s can process values in given `DataType`s, allowing the expressions to be feature-rich
public class Function<T> : FunctionProtocol {
    /// Although `Function`s typically contain only one pattern, multiple ones can be added, for semantic grouping purposes
    public let patterns: [Matcher<T, TypedInterpreter>]

    /// If multiple patterns are provided use this initialiser. Otherwise, for only one, there is `init(_,matcher:)`
    public init(patterns: [Matcher<T, TypedInterpreter>]) {
        self.patterns = patterns
    }

    /// The element contains the pattern that needs to be recognised. The matcher ending closure then transforms and processes the recognised value
    public init(_ elements: [MatchElement], matcher: @escaping MatcherBlock<T, TypedInterpreter>) {
        self.patterns = [Matcher(elements, matcher: matcher)]
    }

    /// The matching of the input expression of a given `Function` happens in this method. It only accepts matches from the matcher, that are exact matches.
    public func convert(input: String, interpreter: TypedInterpreter, context: InterpreterContext) -> Any? {
        guard case let .exactMatch(_, output, _) = matchStatement(amongst: patterns, in: input, until: input.count, interpreter: interpreter, context: context) else { return nil }
        return output
    }
}
