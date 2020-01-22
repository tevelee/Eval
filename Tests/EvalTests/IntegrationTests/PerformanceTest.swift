//
//  PerformanceTest.swift
//  EvalTests
//
//  Created by László Teveli on 2019. 09. 14..
//

import XCTest
@testable import Eval

class PerformanceTest: XCTestCase {
    var interpreter: TypedInterpreter?
    
    override func setUp() {
        super.setUp()
        let not = prefixOperator("!") { (value: Bool) in !value }
        let not2 = prefixOperator("x") { (value: Bool) in !value }
        let equality = infixOperator("==") { (lhs: Bool, rhs: Bool) in lhs == rhs }
        
        interpreter = TypedInterpreter(dataTypes: [stringDataType(), booleanDataType(), numberDataType()],
                                       functions: [not, not2, equality],
                                       context: Context(variables: ["nothing": true]))
    }
    
    func test_suffix1() {
        self.measure {
            for _ in 1...1000 {
                _ = self.interpreter?.evaluate("!nothing")
            }
        }
    }
    
    func test_suffix2() {
        self.measure {
            for _ in 1...1000 {
                _ = self.interpreter?.evaluate("x nothing")
            }
        }
    }
    
    func test_suffix3() {
        self.measure {
            for _ in 1...1000 {
                _ = self.interpreter?.evaluate("nothing == true")
            }
        }
    }

    func numberDataType() -> DataType<Double> {
        return DataType(type: Double.self,
                        literals: [Literal { Double($0.value) },
                                   Literal("pi", convertsTo: Double.pi)]) { String(describing: $0.value) }
    }
    
    func stringDataType() -> DataType<String> {
        let singleQuotesLiteral = Literal { literal -> String? in
            guard let first = literal.value.first, let last = literal.value.last, first == last, first == "'" else { return nil }
            let trimmed = literal.value.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
        }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0.value }
    }

    func booleanDataType() -> DataType<Bool> {
        return DataType(type: Bool.self, literals: [Literal("false", convertsTo: false), Literal("true", convertsTo: true)]) { $0.value ? "true" : "false" }
    }
    
    func prefixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T?> {
        return Function([Keyword(symbol), Variable<A>("value")]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }
    
    func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")], options: .backwardMatch) {
            guard let lhs = $0.variables["lhs"] as? A, let rhs = $0.variables["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
}
