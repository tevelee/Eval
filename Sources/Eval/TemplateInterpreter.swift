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

/// This interpreter is used to evaluate string expressions and return a transformed string, replacing the content where it matches certain patterns.
/// Typically used in web applications, where the rendering of an HTML page is provided as a template, and the application replaces certain statements, based on input parameters.
public class TemplateInterpreter: Interpreter {
    /// The result of a template evaluation is a String
    public typealias EvaluatedType = String

    /// The statements (patterns) registered to the interpreter. If found, these are going to be processed and replaced with the evaluated value
    public let statements: [Matcher<String, TemplateInterpreter>]

    /// The context used when evaluating the expressions. These context variables are global, used in every evaluation processed with this instance.
    public let context: InterpreterContext

    /// The `TemplateInterpreter` contains a `TypedInterpreter`, as it is quite common practice to evaluate strongly typed expression as s support for the template language.
    /// Common examples are: condition part of an if statement, or body of a print statement
    public let typedInterpreter: TypedInterpreter

    /// The evaluator type that is being used to process variables. By default, the TypedInterpreter is being used
    public typealias VariableEvaluator = TypedInterpreter

    /// The evaluator, that is being used to process variables
    public lazy var interpreterForEvaluatingVariables: TypedInterpreter = { [unowned self] in typedInterpreter }()

    /// The statements, and context parameters are optional, but highly recommended to use with actual values.
    /// In order to properly initialise a `TemplateInterpreter`, you'll need a `TypedInterpreter` instance as well.
    /// - parameter statements: The patterns that the interpreter should recognise
    /// - parameter interpreter: A `TypedInterpreter` instance to evaluate typed expressions appearing in the template
    /// - parameter context: Global context that is going to be used with every expression evaluated with the current instance. Defaults to empty context
    public init(statements: [Matcher<String, TemplateInterpreter>] = [],
                interpreter: TypedInterpreter,
                context: InterpreterContext = InterpreterContext()) {
        self.statements = statements
        self.typedInterpreter = interpreter
        self.context = context
    }

    /// The main part of the evaluation happens here. In this case, only the global context variables are going to be used
    /// - parameter expression: The input
    /// - returns: The output of the evaluation
    public func evaluate(_ expression: String) -> String {
        return evaluate(expression, context: InterpreterContext())
    }

    /// The main part of the evaluation happens here. In this case, the global context variables merged with the provided context are going to be used.
    /// - parameter expression: The input
    /// - parameter context: Local context that is going to be used with this expression only
    /// - returns: The output of the evaluation
    public func evaluate(_ expression: String, context: InterpreterContext) -> String {
        let context = self.context.merge(with: context)
        var output = ""

        var position = 0
        repeat {
            let result = matchStatement(amongst: statements, in: expression, from: position, interpreter: self, context: context)
            switch result {
            case .noMatch, .possibleMatch:
                output += expression[position]
                position += 1
            case .exactMatch(let length, let matchOutput, _):
                output += matchOutput
                position += length
            default:
                assertionFailure("Invalid result")
            }
        } while position < expression.count

        return output
    }
}

/// A special kind of variable that is used in case of `TemplateInterpreter`s. It does not convert its content using the `interpreterForEvaluatingVariables` but always uses the `TemplateInterpreter` instance.
/// It's perfect for expressions, that have a body, that needs to be further interpreted, such as an if or while statement.
public class TemplateVariable: GenericVariable<String, TemplateInterpreter> {
    /// No changes compared to the initialiser of the superclass `Variable`, uses the same parameters
    /// - parameter name: `GenericVariable`s have a name (unique identifier), that is used when matching and returning them in the matcher.
    /// - parameter shortest: provides information whether the match should be exhaustive or just use the shortest possible matching string (even zero characters in some edge cases). This depends on the surrounding `Keyword` instances in the containing collection. Defaults to `true`
    public init(_ name: String, shortest: Bool = true) {
        super.init(name, shortest: shortest, interpreted: false) { value, interpreter in
            guard let stringValue = value as? String else { return "" }
            return interpreter.evaluate(stringValue)
        }
    }
}
