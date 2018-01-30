@testable import Eval
import XCTest

class InterpreterContextTests: XCTestCase {

    // MARK: init

    func test_whenCreated_thenVariablesAreSet() {
        let variables = ["test": 2]

        let context = Context(variables: variables)

        XCTAssertEqual(variables, context.variables as! [String: Int])
    }

    // MARK: push/pop

    func test_whenPushing_thenRemainsTheSame() {
        let variables = ["test": 2]
        let context = Context(variables: variables)

        context.push()

        XCTAssertEqual(variables, context.variables as! [String: Int])
    }

    func test_whenPushingAndModifying_thenContextChanges() {
        let variables = ["test": 2]
        let context = Context(variables: variables)

        context.push()
        context.variables["a"] = 3

        XCTAssertNotEqual(variables, context.variables as! [String: Int])
    }

    func test_whenPushingModifyingAndPopping_thenRestores() {
        let variables = ["test": 2]
        let context = Context(variables: variables)

        context.push()
        context.variables["a"] = 3
        context.pop()

        XCTAssertEqual(variables, context.variables as! [String: Int])
    }

    func test_whenJustPopping_thenNothingHappens() {
        let variables = ["test": 2]
        let context = Context(variables: variables)

        context.pop()

        XCTAssertEqual(variables, context.variables as! [String: Int])
    }

    // MARK: merging

    func test_whenMergingTwo_thenCreatesANewContext() {
        let one = Context(variables: ["a": 1])
        let two = Context(variables: ["b": 2])

        let result = one.merging(with: two)

        XCTAssertEqual(result.variables as! [String: Int], ["a": 1, "b": 2])
        XCTAssertFalse(one === result)
        XCTAssertFalse(two === result)
    }

    func test_whenMergingTwo_thenParameterOverridesVariablesInSelf() {
        let one = Context(variables: ["a": 1])
        let two = Context(variables: ["a": 2, "x": 3])

        let result = one.merging(with: two)

        XCTAssertEqual(result.variables as! [String: Int], ["a": 2, "x": 3])
    }

    func test_whenMergingWithNil_thenReturnsSelf() {
        let context = Context(variables: ["a": 1])

        let result = context.merging(with: nil)

        XCTAssertTrue(result === context)
    }

    // MARK: merge

    func test_whenMergingTwoInAMutableWay_thenMergesVariables() {
        let one = Context(variables: ["a": 1])
        let two = Context(variables: ["b": 2])

        one.merge(with: two) { existing, _ in existing }

        XCTAssertEqual(one.variables as! [String: Int], ["a": 1, "b": 2])
    }

    func test_whenMergingTwoInAMutableWay_thenParameterOverridesVariablesInSelf() {
        let one = Context(variables: ["a": 1])
        let two = Context(variables: ["a": 2, "x": 3])

        one.merge(with: two) { existing, _ in existing }

        XCTAssertEqual(one.variables as! [String: Int], ["a": 1, "x": 3])
    }

    func test_whenMergingTwoInAMutableWayReversed_thenParameterOverridesVariablesInSelf() {
        let one = Context(variables: ["a": 1])
        let two = Context(variables: ["a": 2, "x": 3])

        two.merge(with: one) { _, new in new }

        XCTAssertEqual(two.variables as! [String: Int], ["a": 1, "x": 3])
    }

    func test_whenMergingWithNilInAMutableWay_thenReturnsSelf() {
        let context = Context(variables: ["a": 1])

        context.merge(with: nil) { existing, _ in existing }

        XCTAssertTrue(context.variables as! [String: Int] == ["a": 1])
    }
}
