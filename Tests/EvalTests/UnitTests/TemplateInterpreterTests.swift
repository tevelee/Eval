import XCTest
@testable import Eval

class StringTemplateInterpreterTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialised_thenPropertiesAreSaved() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("in")]) { _,_,_ in "a" }
        let statements = [matcher]
        let interpreter = TypedInterpreter()
        let context = InterpreterContext()
        
        let stringTemplateInterpreter = StringTemplateInterpreter(statements: statements,
                                                                  interpreter: interpreter,
                                                                  context: context)
        
        XCTAssertEqual(stringTemplateInterpreter.statements.count, 1)
        XCTAssertTrue(statements[0] === stringTemplateInterpreter.statements[0])
        XCTAssertTrue(interpreter === stringTemplateInterpreter.typedInterpreter)
        XCTAssertTrue(context === stringTemplateInterpreter.context)
        XCTAssertFalse(stringTemplateInterpreter.typedInterpreter.context === stringTemplateInterpreter.context)
    }
    
    func test_whenInitialised_thenTypedAndTemplateInterpreterDoNotShareTheSameContext() {
        let stringTemplateInterpreter = StringTemplateInterpreter(statements: [], interpreter: TypedInterpreter(), context: InterpreterContext())

        XCTAssertFalse(stringTemplateInterpreter.typedInterpreter.context === stringTemplateInterpreter.context)
    }
    
    //MARK: evaluate
    
    func test_whenEvaluates_thenTransformationHappens() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("in")]) { _,_,_ in "contains" }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                                    interpreter:TypedInterpreter(),
                                                    context: InterpreterContext())
        
        let result = interpreter.evaluate("a in b")
        
        XCTAssertEqual(result, "a contains b")
    }
    
    func test_whenEvaluates_thenUsesGlobalContext() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("{somebody}")]) { _,_,context in context.variables["person"] as? String }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                                    interpreter:TypedInterpreter(),
                                                    context: InterpreterContext(variables: ["person": "you"]))
        
        let result = interpreter.evaluate("{somebody} + me")
        
        XCTAssertEqual(result, "you + me")
    }

    //MARK: evaluate with context
    
    func test_whenEvaluatesWithContext_thenUsesLocalContext() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("{somebody}")]) { _,_,context in context.variables["person"] as? String }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: InterpreterContext())
        
        let result = interpreter.evaluate("{somebody} + me", context: InterpreterContext(variables: ["person": "you"]))
        
        XCTAssertEqual(result, "you + me")
    }

    func test_whenEvaluatesWithContext_thenLocalOverridesGlobalContext() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("{somebody}")]) { _,_,context in context.variables["person"] as? String }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: InterpreterContext(variables: ["person": "nobody"]))
        
        let result = interpreter.evaluate("{somebody} + me", context: InterpreterContext(variables: ["person": "you"]))
        
        XCTAssertEqual(result, "you + me")
    }
    
    //MARK: TemplateVariable
    
    func test_whenUsingTemplateVariable_thenTransformationHappens() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("{"), TemplateVariable("person"), Keyword("}")]) { _,_,_ in "you" }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: InterpreterContext())
        
        let result = interpreter.evaluate("{somebody} + me")
        
        XCTAssertEqual(result, "you + me")
    }
    
    func test_whenUsingTemplateVariableWithNilResult_thenTransformationNotHappens() {
        let matcher = Matcher<String, TemplateInterpreter<String>>([Keyword("{"), TemplateVariable("person"), Keyword("}")]) { _,_,_ in nil }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: InterpreterContext())
        
        let result = interpreter.evaluate("{somebody} + me")
        
        XCTAssertEqual(result, "{somebody} + me")
    }
}
