@testable import Eval
import XCTest
import class Eval.Pattern

class PatternTests: XCTestCase {

    // MARK: init

    class DummyElement: PatternElement {
        func matches(prefix: String, options: PatternOptions) -> MatchResult<Any> {
            return .noMatch
        }
    }

    func test_whenInitialised_thenElementsAndMatcherAreSet() {
        let element = DummyElement()
        let matcherBlock: MatcherBlock<Int, DummyInterpreter> = { _ in 1 }

        let matcher = Pattern<Int, DummyInterpreter>([element], matcher: matcherBlock)

        XCTAssertTrue(element === matcher.elements[0] as! DummyElement)
        //XCTAssertTrue(matcherBlock === matcher.matcher)
    }

    func test_whenInitialisedWithVariableOnTheLastPlace_thenLastVariableBecomesNotShortest() {
        let element = DummyElement()
        let variable = GenericVariable<String, DummyInterpreter>("name")

        let matcher = Pattern<String, DummyInterpreter>([element, variable]) { _ in "x" }

        let result = matcher.elements[1] as! GenericVariable<String, DummyInterpreter>
        XCTAssertTrue(element === matcher.elements[0] as! DummyElement)
        XCTAssertFalse(variable === result)
        XCTAssertTrue(result.options.contains(.exhaustiveMatch))
    }

    // MARK: matches

    // swiftlint:disable:next function_body_length
    func test_whenMatching_thenExpectingAppropriateResults() {
        // swiftlint:disable:next nesting
        typealias TestCase = (elements: [PatternElement], input: String, expectedResult: MatchResult<Int>)

        let keyword = Keyword("ok")
        let variable = GenericVariable<String, DummyInterpreter>("name", options: .notInterpreted)
        let variableLongest = GenericVariable<String, DummyInterpreter>("name", options: [.notInterpreted, .exhaustiveMatch])
        let variable2 = GenericVariable<String, DummyInterpreter>("last", options: .notInterpreted)

        let testCases: [TestCase] = [
            ([keyword], "invalid", .noMatch),
            ([keyword], "o", .possibleMatch),
            ([keyword], "ok", .exactMatch(length: 2, output: 1, variables: [:])),
            ([keyword], "okokok", .exactMatch(length: 2, output: 1, variables: [:])),

            ([variable], "anything", .exactMatch(length: 8, output: 1, variables: ["name": "anything"])),
            ([variableLongest], "anything", .exactMatch(length: 8, output: 1, variables: ["name": "anything"])),

            ([variable, keyword], "invalid", .possibleMatch),
            ([variable, keyword], "invalid o", .possibleMatch),
            ([variable, keyword], "invalid ok", .exactMatch(length: 10, output: 1, variables: ["name": "invalid"])),
            ([variable, keyword], "invalidxok", .exactMatch(length: 10, output: 1, variables: ["name": "invalidx"])),
            ([variable, keyword], "invalidxok extra", .exactMatch(length: 10, output: 1, variables: ["name": "invalidx"])),

            ([keyword, variable], "xokthen", .noMatch),
            ([keyword, variable], "o", .possibleMatch),
            ([keyword, variable], "oi", .noMatch),
            ([keyword, variable], "ok", .exactMatch(length: 2, output: 1, variables: ["name": ""])),
            ([keyword, variable], "ok then", .exactMatch(length: 7, output: 1, variables: ["name": "then"])),
            ([keyword, variable], "ok,then", .exactMatch(length: 7, output: 1, variables: ["name": ",then"])),

            ([keyword, variable, keyword], "o", .possibleMatch),
            ([keyword, variable, keyword], "ok", .possibleMatch),
            ([keyword, variable, keyword], "oko", .possibleMatch),
            ([keyword, variable, keyword], "okok", .exactMatch(length: 4, output: 1, variables: ["name": ""])),
            ([keyword, variable, keyword], "okxok", .exactMatch(length: 5, output: 1, variables: ["name": "x"])),
            ([keyword, variable, keyword], "okokok", .exactMatch(length: 4, output: 1, variables: ["name": ""])),
            ([keyword, variableLongest, keyword], "ok", .possibleMatch),
            ([keyword, variableLongest, keyword], "okx", .possibleMatch),
            ([keyword, variableLongest, keyword], "oko", .possibleMatch),

            ([keyword, variableLongest, keyword], "okok", .possibleMatch),
            ([keyword, variableLongest, keyword], "okxok", .possibleMatch),

            ([variable, keyword, variable2], "xo", .possibleMatch),
            ([variable, keyword, variable2], "xok", .exactMatch(length: 3, output: 1, variables: ["name": "x", "last": ""])),
            ([variable, keyword, variable2], "xoky", .exactMatch(length: 4, output: 1, variables: ["name": "x", "last": "y"])),
            ([variable, keyword, variable2], "xoky and rest", .exactMatch(length: 13, output: 1, variables: ["name": "x", "last": "y and rest"])),
            ([variable, keyword, variable2], "xokoky", .exactMatch(length: 6, output: 1, variables: ["name": "x", "last": "oky"]))
        ]

        for testCase in testCases {
            let matcher = Pattern<Int, DummyInterpreter>(testCase.elements) { _ in 1 }
            let result = matcher.matches(string: testCase.input, interpreter: DummyInterpreter(), context: Context())
            XCTAssertTrue(result == testCase.expectedResult, "\(testCase.input) should have resulted in \(testCase.expectedResult) but got \(result) instead")
        }
    }

    func test_whenMatchingForwards_thenExpectingAppropriateResults() {
        let matcher = Pattern<Int, TypedInterpreter>([Variable<Int>("lhs"), Keyword("-"), Variable<Int>("rhs")]) {
            guard let lhs = $0.variables["lhs"] as? Int, let rhs = $0.variables["rhs"] as? Int else { return nil }
            return lhs - rhs
        }
        let function = Function(patterns: [matcher])
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }], functions: [function])
        XCTAssertEqual(interpreter.evaluate("3 - 2 - 1") as! Int, 2)
    }

    func test_whenMatchingBackwards_thenExpectingAppropriateResults() {
        let matcher = Pattern<Int, TypedInterpreter>([Variable<Int>("lhs"), Keyword("-"), Variable<Int>("rhs")], options: .backwardMatch) {
            guard let lhs = $0.variables["lhs"] as? Int, let rhs = $0.variables["rhs"] as? Int else { return nil }
            return lhs - rhs
        }
        let function = Function(patterns: [matcher])
        let interpreter = TypedInterpreter(dataTypes: [DataType(type: Int.self, literals: [Literal { Int($0.value) }]) { String($0.value) }], functions: [function])
        XCTAssertEqual(interpreter.evaluate("3 - 2 - 1") as! Int, 0)
    }
}
