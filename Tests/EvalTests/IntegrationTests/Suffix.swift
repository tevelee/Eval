//
//  Suffix.swift
//  Eval
//
//  Created by László Teveli on 2019. 09. 14..
//

import Foundation
import XCTest
@testable import Eval

class MiniExpressionStandardLibraryTest: XCTestCase {
    private func evaluate<R>(_ expression: String, inputs: [String: Any] = [:]) -> R? {
        let context = Context(variables: inputs)
        let interpreter = TypedInterpreter(dataTypes: MiniExpressionStandardLibrary.dataTypes, functions: MiniExpressionStandardLibrary.functions, context: context)
        let result = interpreter.evaluate(expression, context: context)
        print(context.debugInfo)
        return result as? R
    }
    func testComposition() {
        // based on feedback I realized this doesn't work...
        // TODO: figure out the suffix error in this case
        XCTAssertEqual(evaluate("(toggle == true) and (url exists)", inputs: ["toggle": true, "url": 1]), true)
//        XCTAssertEqual(evaluate("(toggle == true) and (url exists)", inputs: ["toggle": true]), false)
        XCTAssertEqual(evaluate("(toggle == true) and (not(url exists))", inputs: ["toggle": true]), true)
    }
    func testComposition2() {
        // this (prefix function) does work...
        XCTAssertEqual(evaluate("(toggle == true) and (didset url)", inputs: ["toggle": true, "url": 1]), true)
//        XCTAssertEqual(evaluate("(toggle == true) and (didset url)", inputs: ["toggle": true]), false)
        XCTAssertEqual(evaluate("(toggle == true) and (not(didset url))", inputs: ["toggle": true]), true)
    }
}

class MiniExpressionStandardLibrary {
    static var dataTypes: [DataTypeProtocol] {
        return [
            booleanType,
        ]
    }
    static var functions: [FunctionProtocol] {
        return [
            andOperator,
            boolParentheses,
            existsOperator,
            boolEqualsOperator,
            didsetOperator,
        ]
    }
    // MARK: - Types
    
    static var booleanType: DataType<Bool> {
        let trueLiteral = Literal("true", convertsTo: true)
        let falseLiteral = Literal("false", convertsTo: false)
        return DataType(type: Bool.self, literals: [trueLiteral, falseLiteral]) { $0.value ? "true" : "false" }
    }
    // MARK: - Functions
    
    static var boolEqualsOperator: Function<Bool> {
        return infixOperator("==") { (lhs: Bool, rhs: Bool) in lhs == rhs }
    }
    static var boolParentheses: Function<Bool> {
        return Function([OpenKeyword("("), Variable<Bool>("body"), CloseKeyword(")")]) { $0.variables["body"] as? Bool }
    }
    static var andOperator: Function<Bool> {
        return infixOperator("and") { (lhs: Bool, rhs: Bool) in lhs && rhs }
    }
    static var existsOperator: Function<Bool> {
        return suffixOperator("exists") { (expression: Any?) in expression != nil }
    }
    static var didsetOperator: Function<Bool> {
        return prefixOperator("didset") { (expression: Any?) in expression != nil }
    }
    // MARK: - Operator helpers
    
    static func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")], options: .backwardMatch) {
            guard let lhs = $0.variables["lhs"] as? A, let rhs = $0.variables["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
    static func prefixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T> {
        return Function([Keyword(symbol), Variable<A>("value")]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }
    static func suffixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T> {
        return Function([Variable<A>("value"), Keyword(symbol)]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }
}
