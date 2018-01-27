import XCTest
@testable import Eval

class VariableTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialised_thenPropertiesAreSet() {
        let variable = GenericVariable<String, DummyInterpreter>("name", options: .acceptsNilValue, map:{ value, _ in nil })
        
        XCTAssertEqual(variable.name, "name")
        XCTAssertEqual(variable.options, .acceptsNilValue)
        XCTAssertNotNil(variable.map)
    }
    
    func test_whenInitialised_thenDefaultAreSetCorrectly() {
        let variable = GenericVariable<String, DummyInterpreter>("name")
        
        XCTAssertEqual(variable.name, "name")
        XCTAssertEqual(variable.options, [])
        XCTAssertNotNil(variable.map)
    }
    
    //MARK: matches
    
    func test_whenCallingMatches_thenReturnAny() {
        let variable = GenericVariable<String, DummyInterpreter>("name")
        
        XCTAssertTrue(variable.matches(prefix: "asd").isAnyMatch())
    }
    
    //MARK: mapped
    
    func test_whenCallingMatched_thenCreatesANewVariable() {
        let variable = GenericVariable<String, TypedInterpreter>("name")
        let result = variable.mapped { return Double($0) }
        
        XCTAssertNotNil(result)
        XCTAssertEqual(variable.name, result.name)
        XCTAssertEqual(variable.options, result.options)
        XCTAssertEqual(result.performMap(input: "1", interpreter: TypedInterpreter()) as! Double, 1)
    }
    
    //MARK: performMap
    
    func test_whenCallingPerformMap_thenUsesMapClosure() {
        let variable = GenericVariable<Int, DummyInterpreter>("name") { _,_ in 123 }
        let result = variable.performMap(input: 1, interpreter: DummyInterpreter())
        
        XCTAssertEqual(result as! Int, 123)
    }
    
    //MARK: matches performance
    
    func test_whenCallingMatchesWithShortInput_thenPerformsEffectively() {
        let variable = GenericVariable<String, DummyInterpreter>("name")
        
        XCTAssertTrue(variable.matches(prefix: "asd").isAnyMatch())
    }
    
    func test_whenCallingMatchesWithLargeInput_thenPerformsEffectively() {
        let variable = GenericVariable<String, DummyInterpreter>("name")
        
        XCTAssertTrue(variable.matches(prefix: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.").isAnyMatch())
    }
}
