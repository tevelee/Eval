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

public class TemplateInterpreter : Interpreter {
    public typealias EvaluatedType = String
    public typealias VariableEvaluator = TypedInterpreter
    
    public let statements: [Matcher<String, TemplateInterpreter>]
    public let context: InterpreterContext
    public let typedInterpreter: TypedInterpreter
    public lazy var interpreterForEvaluatingVariables: TypedInterpreter = { [unowned self] in typedInterpreter }()
    
    public init(statements: [Matcher<String, TemplateInterpreter>],
                interpreter: TypedInterpreter,
                context: InterpreterContext = InterpreterContext()) {
        self.statements = statements
        self.typedInterpreter = interpreter
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> String {
        return evaluate(expression, context: InterpreterContext())
    }
    
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

public class TemplateVariable : GenericVariable<String, TemplateInterpreter> {
    public init(_ name: String, shortest: Bool = true) {
        super.init(name, shortest: shortest, interpreted: false) { value, interpreter in
            guard let stringValue = value as? String else { return "" }
            return interpreter.evaluate(stringValue)
        }
    }
}
