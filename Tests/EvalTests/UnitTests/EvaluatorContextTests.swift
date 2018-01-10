import XCTest
@testable import Eval

class EvaluatorContextTests: XCTestCase {
    
    //MARK: init
    
    func test_whenCreated_thenVariablesAreSet() {
        let variables = ["test": 2]
        
        let context = InterpreterContext(variables: variables)
        
        XCTAssertEqual(variables, context.variables as! [String: Int])
    }
    
    //MARK: merge
    
    func test_whenMergingTwo_thenCreatesANewContext() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["b": 2])
        
        let result = one.merge(with: two)
        
        XCTAssertEqual(result.variables as! [String: Int], ["a": 1, "b": 2])
        XCTAssertFalse(one === result)
        XCTAssertFalse(two === result)
    }
    
    func test_whenMergingTwo_thenParameterOverridesVariablesInSelf() {
        let one = InterpreterContext(variables: ["a": 1])
        let two = InterpreterContext(variables: ["a": 2, "x": 3])
        
        let result = one.merge(with: two)
        
        XCTAssertEqual(result.variables as! [String: Int], ["a": 2, "x": 3])
    }
    
    func test_whenMergingWithNil_thenReturnsSelf() {
        let context = InterpreterContext(variables: ["a": 1])
        
        let result = context.merge(with: nil)
        
        XCTAssertTrue(result === context)
    }
}
