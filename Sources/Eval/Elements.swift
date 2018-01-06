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

/// `MatchElement`s are used by `Matcher` instances to be able to recognise patterns.
/// Currently, the two main kind of `MatchElement` classes are `Keyword`s and `Variable`s
public protocol MatchElement {
    /// Using this method, an element returns how much the String provided in the `prefix` parameter matches ths current element
    /// The `isLast` parameter provides extra information about the current element, whether it is the last item in the containing collection. Most of the cases it's false
    func matches(prefix: String, isLast: Bool) -> MatchResult<Any>
}

/// `Keyword` instances are used to provide static points in match sequences, so that they can be used as pillars of the expressions the developer tries to match
public class Keyword: MatchElement {
    /// The type of the Keyword determines whether the item holds some special purpose, or it's just an ordinary static String
    public enum KeywordType {
        /// By default, `Keyword` are created as a generic type, meaning, that there is no special requirement, that they need to fulfill
        case generic
        /// If a pattern contains two, semantically paired `Keyword`s, they often represent opening and closing parentheses or any kind of special enclosing characters.
        /// This case represents the first one of the pair, needs to be matched. Often these are expressed as opening parentheses, e.g. `(`
        case openingStatement
        /// If a pattern contains two, semantically paired `Keyword`s, they often represent opening and closing parentheses or any kind of special enclosing characters.
        /// This case represents the second (and last) one of the pair, needs to be matched. Often these are expressed as closing parentheses, e.g. `)`
        case closingStatement
    }

    let name: String
    let type: KeywordType

    /// `Keyword` must have a name, which is equal to their represented value. The type parameter defaults to generic
    public init(_ name: String, type: KeywordType = .generic) {
        self.name = name.trim()
        self.type = type
    }

    /// `Keyword` instances are returning exactMatch, when they are equal to the `prefix` input.
    /// If the input is really just a prefix of the keyword, possible metch is returned. noMatch otherwise.
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult<Any> {
        if name == prefix || prefix.hasPrefix(name) {
            return .exactMatch(length: name.count, output: name, variables: [:])
        } else if name.hasPrefix(prefix) {
            return .possibleMatch
        } else {
            return .noMatch
        }
    }
}

/// A special subclass of the `Keyword` class, which initialises a `Keyword` with an opening type.
/// Usually used for opening parentheses: OpenKeyword("[")
public class OpenKeyword: Keyword {
    /// The initialiser uses the opening type, but the `name` still must be provided
    public init(_ name: String) {
        super.init(name, type: .openingStatement)
    }
}

/// A special subclass of the `Keyword` class, which initialises a `Keyword` with an closing type.
/// Usually used for closing parentheses: CloseKeyword("]")
public class CloseKeyword: Keyword {
    /// The initialiser uses the closing type, but the `name` still must be provided
    public init(_ name: String) {
        super.init(name, type: .closingStatement)
    }
}

protocol VariableProtocol {
    var name: String { get }
    var shortest: Bool { get }
    var interpreted: Bool { get }
    var acceptsNilValue: Bool { get }
    func performMap(input: Any, interpreter: Any) -> Any?
}

/// Generic superclass of `Variable`s which are aware of their `Interpreter` classes,
/// as they use it when mapping their values
public class GenericVariable<T, E: Interpreter> : VariableProtocol, MatchElement {
    let name: String
    let shortest: Bool
    let interpreted: Bool
    let acceptsNilValue: Bool
    let map: (Any, E) -> T?

    /// `GenericVariable`s have a name (unique identifier), that is used when matching and return them in the matcher.
    ///
    /// `shortest` provides information whether the match should be exhaustive or just use the shortest possible
    /// matching string (even zero characters in some edge cases).
    /// This depends on the surrounding `Keyword` instances in the containing collection.
    ////
    /// If `interpreted` is false, the value of the recognised placeholder will not be processed.
    /// In case of true, it will be evaluated, using the `interpreterForEvaluatingVariables`
    /// property of the interpreter instance
    ///
    /// If `interpreted` is true, and the result of the evaluation is `nil`, then
    /// acceptsNilValue determines if the current match result should be instant noMatch,
    /// or `nil` is an accepted value, so the matching should be continued
    ///
    /// The final `map` block is optional. If provided, then the result of the evaluated variable will be ran through
    /// this map function, transforming its value. By default the map tries to convert the matched value to the expected type, using the `as?` operator.
    public init(_ name: String, shortest: Bool = true, interpreted: Bool = true, acceptsNilValue: Bool = false, map: @escaping (Any, E) -> T? = { (value, _) in value as? T }) {
        self.name = name
        self.shortest = shortest
        self.interpreted = interpreted
        self.acceptsNilValue = acceptsNilValue
        self.map = map
    }

    /// `GenericVariables` always return anyMatch MatchResult, forwarding the shortest argument, provided during initialisation
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult<Any> {
        return .anyMatch(shortest: shortest)
    }

    func mapped<K>(_ map: @escaping (T) -> K?) -> GenericVariable<K, E> {
        return GenericVariable<K, E>(name, shortest: shortest, interpreted: interpreted, map: { value, interpreter in
            guard let value = self.map(value, interpreter) else { return nil }
            return map(value)
        })
    }

    func performMap(input: Any, interpreter: Any) -> Any? {
        guard let interpreter = interpreter as? E else { return nil }
        return map(input, interpreter)
    }
}

/// `Variable` represents a named placeholder, so when the matcher recognises a pattern, the values of the variables are passed to them in a block. 
public class Variable<T> : GenericVariable<T, TypedInterpreter> {
}

/// A special kind of variable, that is used in case of `TemplateInterpreter`s. It does not convert its content using the `interpreterForEvaluatingVariables`, but always uses the `TemplateInterpreter` instance.
/// It's perfect for expressions, that have a body, that needs to be further interpreted, such as an if or while statement.
public class TemplateVariable: GenericVariable<String, TemplateInterpreter> {
    /// No changes compared to the initialiser of the superclass `Variable`, uses the same parameters
    public init(_ name: String, shortest: Bool = true) {
        super.init(name, shortest: shortest, interpreted: false) { value, interpreter in
            guard let stringValue = value as? String else { return "" }
            return interpreter.evaluate(stringValue)
        }
    }
}
