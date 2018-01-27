import XCTest
@testable import Eval
import class Eval.Pattern

class StringTemplateInterpreterTests: XCTestCase {
    
    //MARK: init
    
    func test_whenInitialised_thenPropertiesAreSaved() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("in")]) { _,_,_ in "a" }
        let statements = [matcher]
        let interpreter = TypedInterpreter()
        let context = Context()
        
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
        let stringTemplateInterpreter = StringTemplateInterpreter(statements: [], interpreter: TypedInterpreter(), context: Context())

        XCTAssertFalse(stringTemplateInterpreter.typedInterpreter.context === stringTemplateInterpreter.context)
    }
    
    //MARK: evaluate
    
    func test_whenEvaluates_thenTransformationHappens() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("in")]) { _,_,_ in "contains" }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                                    interpreter:TypedInterpreter(),
                                                    context: Context())
        
        let result = interpreter.evaluate("a in b")
        
        XCTAssertEqual(result, "a contains b")
    }
    
    func test_whenEvaluates_thenUsesGlobalContext() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("{somebody}")]) { _,_,context in context.variables["person"] as? String }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                                    interpreter:TypedInterpreter(),
                                                    context: Context(variables: ["person": "you"]))
        
        let result = interpreter.evaluate("{somebody} + me")
        
        XCTAssertEqual(result, "you + me")
    }

    //MARK: evaluate with context
    
    func test_whenEvaluatesWithContext_thenUsesLocalContext() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("{somebody}")]) { _,_,context in context.variables["person"] as? String }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: Context())
        
        let result = interpreter.evaluate("{somebody} + me", context: Context(variables: ["person": "you"]))
        
        XCTAssertEqual(result, "you + me")
    }

    func test_whenEvaluatesWithContext_thenLocalOverridesGlobalContext() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("{somebody}")]) { _,_,context in context.variables["person"] as? String }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: Context(variables: ["person": "nobody"]))
        
        let result = interpreter.evaluate("{somebody} + me", context: Context(variables: ["person": "you"]))
        
        XCTAssertEqual(result, "you + me")
    }
    
    //MARK: TemplateVariable
    
    func test_whenUsingTemplateVariable_thenTransformationHappens() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("{"), TemplateVariable("person"), Keyword("}")]) { _,_,_ in "you" }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: Context())
        
        let result = interpreter.evaluate("{somebody} + me")
        
        XCTAssertEqual(result, "you + me")
    }
    
    func test_whenUsingTemplateVariableWithNilResult_thenTransformationNotHappens() {
        let matcher = Pattern<String, TemplateInterpreter<String>>([Keyword("{"), TemplateVariable("person"), Keyword("}")]) { _,_,_ in nil }
        let interpreter = StringTemplateInterpreter(statements: [matcher],
                                              interpreter:TypedInterpreter(),
                                              context: Context())
        
        let result = interpreter.evaluate("{somebody} + me")
        
        XCTAssertEqual(result, "{somebody} + me")
    }
}
