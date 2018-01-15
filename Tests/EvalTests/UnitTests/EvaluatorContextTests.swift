import XCTest
@testable import Eval

class EvaluatorContextTests: XCTestCase {
    
    //MARK: init
    
    func test_whenCreated_thenVariablesAreSet() {
        let variables = ["test": 2]
        
        let context = InterpreterContext(variables: variables)
        
        XCTAssertEqual(variables, context.variables as! [String: Int])
    }
    
    //MARK: merging
    
    func test_whenMergingTwo_thenCreatesANewContext() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["b": 2])
        
        let result = one.merging(with: two)
        
        XCTAssertEqual(result.variables as! [String: Int], ["a": 1, "b": 2])
        XCTAssertFalse(one === result)
        XCTAssertFalse(two === result)
    }
    
    func test_whenMergingTwo_thenParameterOverridesVariablesInSelf() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["a": 2, "x": 3])
        
        let result = one.merging(with: two)
        
        XCTAssertEqual(result.variables as! [String: Int], ["a": 2, "x": 3])
    }
    
    func test_whenMergingWithNil_thenReturnsSelf() {
        let context = InterpreterContext(variables: ["a": 1])
        
        let result = context.merging(with: nil)
        
        XCTAssertTrue(result === context)
    }

    //MARK: merge
    
    func test_whenMergingTwoInAMutableWay_thenMergesVariables() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["b": 2])
        
        one.merge(with: two) { existing, _ in existing }
        
        XCTAssertEqual(one.variables as! [String: Int], ["a": 1, "b": 2])
    }
    
    func test_whenMergingTwoInAMutableWay_thenParameterOverridesVariablesInSelf() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["a": 2, "x": 3])
        
        one.merge(with: two) { existing, _ in existing }
        
        XCTAssertEqual(one.variables as! [String: Int], ["a": 1, "x": 3])
    }
    
    func test_whenMergingTwoInAMutableWayReversed_thenParameterOverridesVariablesInSelf() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["a": 2, "x": 3])
        
        two.merge(with: one) { _, new in new }
        
        XCTAssertEqual(two.variables as! [String: Int], ["a": 1, "x": 3])
    }
    
    func test_whenMergingWithNilInAMutableWay_thenReturnsSelf() {
        let context = InterpreterContext(variables: ["a": 1])
        
        context.merge(with: nil) { existing, _ in existing }
        
        XCTAssertTrue(context.variables as! [String: Int] == ["a": 1])
    }
}
