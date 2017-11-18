import XCTest
@testable import Interpreter
import class Interpreter.Pattern

class TemplateTests: XCTestCase {
    func testVariable() {
        let renderer = ContextAwareRenderer(context: RenderingContext(variables: ["variable": "asd"]))
        let interpreter = StringExpressionInterpreter(statements: [ifStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("x{{ variable }}y"), "xasdy")
    }
    
    func testSet() {
        let renderer = ContextAwareRenderer(context: RenderingContext())
        let interpreter = StringExpressionInterpreter(statements: [setStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("{% set var %}val{% endset %}x{{ var }}y"), "xvaly")
    }
    
    static var allTests = [
        ("testVariable", testVariable),
        ("testSet", testSet),
    ]
    
    func printStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        return Pattern(Keyword(tagPrefix) + Variable("body") + Keyword(tagSuffix), renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["body"] {
                return context.variables[variable]
            }
            return nil
        })
    }
    
    func ifStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        let ifOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("if") + Variable("condition") + Keyword(tagSuffix))
        let ifClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endif") + Keyword(tagSuffix))
        return Pattern(ifOpeningTag + Variable("body") + ifClosingTag, renderer: renderer.contextAwareRender { variables, context in
            if let condition = variables["condition"], condition == "true" {
                return variables["body"]
            } else {
                return nil
            }
        })
    }
    
    func setStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        let setOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("set") + Variable("variable") + Keyword(tagSuffix))
        let setClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endset") + Keyword(tagSuffix))
        return Pattern(setOpeningTag + Variable("value") + setClosingTag, renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["variable"], let value = variables["value"] {
                context.variables[variable] = value
            }
            return nil
        })
    }
}
