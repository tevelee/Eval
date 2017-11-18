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
                                                                   setAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("{% set var1 %}123{% endset %}x{{ var1 }}y"), "x123y")
        XCTAssertEqual(interpreter.evaluate("{% set var2 = asd %}x{{ var2 }}y"), "xasdy")
    }
    
    func testLoop() {
        let renderer = ContextAwareRenderer(context: RenderingContext(variables: ["array": [1, 2, 3, 4, 5]]))
        let interpreter = StringExpressionInterpreter(statements: [forStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   forAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                                                                   printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
        XCTAssertEqual(interpreter.evaluate("x{% for x from 1 to 3 %}{{ x }}{% endfor %}y"), "x123y")
        XCTAssertEqual(interpreter.evaluate("x {% for y in array %}{{ y }} {% endfor %}y"), "x 1 2 3 4 5 y")
    }
    
    static var allTests = [
        ("testVariable", testVariable),
        ("testSet", testSet),
        ("testLoop", testLoop),
    ]
    
    func printStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        return Pattern(Keyword(tagPrefix) + Variable("body") + Keyword(tagSuffix), renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["body"] as? String,
                let result = context.variables[variable.trim()] as? String {
                return result
            }
            return nil
        })
    }
    
    func ifStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        let ifOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("if") + Variable("condition") + Keyword(tagSuffix))
        let ifClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endif") + Keyword(tagSuffix))
        return Pattern(ifOpeningTag + Variable("body") + ifClosingTag, renderer: renderer.contextAwareRender { variables, context in
            if let condition = variables["condition"] as? String,
                let body = variables["body"] as? String,
                booleanExpressionInterpreter(variables: renderer.context.variables).evaluate(condition.trim()) {
                return body
            } else {
                return nil
            }
        })
    }
    
    func setStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        let setOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("set") + Variable("variable") + Keyword(tagSuffix))
        let setClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endset") + Keyword(tagSuffix))
        return Pattern(setOpeningTag + Variable("value") + setClosingTag, renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["variable"] as? String,
                let value = variables["value"] as? String {
                context.variables[variable.trim()] = value.trim()
            }
            return nil
        })
    }
    
    func setAlternativeStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        return Pattern(Keyword(tagPrefix) + Keyword("set") + Variable("variable") + Keyword("=") + Variable("value") + Keyword(tagSuffix), renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["variable"] as? String,
                let value = variables["value"] as? String {
                context.variables[variable.trim()] = value.trim()
            }
            return nil
        })
    }
    
    func forStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        let ifOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("for") + Variable("variable") + Keyword("from") + Variable("from") + Keyword("to") + Variable("to") + Keyword(tagSuffix))
        let ifClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endfor") + Keyword(tagSuffix))
        return Pattern(ifOpeningTag + Variable("body") + ifClosingTag, renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["variable"] as? String,
                let from = variables["from"] as? String,
                let to = variables["to"] as? String,
                let body = variables["body"] as? String,
                let fromInt = Int(from.trim()), let toInt = Int(to.trim()) {
                
                let renderer = ContextAwareRenderer(context: context)
                let interpreter = StringExpressionInterpreter(statements: [self.printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
                
                var result = ""
                for x in fromInt ... toInt {
                    renderer.context.variables[variable.trim()] = String(x)
                    result += interpreter.evaluate(body)
                }
                return result
            } else {
                return nil
            }
        })
    }
    
    func forAlternativeStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
        let ifOpeningTag = Pattern(Keyword(tagPrefix) + Keyword("for") + Variable("variable") + Keyword("in") + Variable("source") + Keyword(tagSuffix))
        let ifClosingTag = Pattern(Keyword(tagPrefix) + Keyword("endfor") + Keyword(tagSuffix))
        return Pattern(ifOpeningTag + Variable("body") + ifClosingTag, renderer: renderer.contextAwareRender { variables, context in
            if let variable = variables["variable"] as? String,
                let source = variables["source"] as? String,
                let body = variables["body"] as? String,
                let sourceArray = context.variables[source.trim()] as? [Int] {
                
                let renderer = ContextAwareRenderer(context: context)
                let interpreter = StringExpressionInterpreter(statements: [self.printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
                
                var result = ""
                for x in sourceArray {
                    renderer.context.variables[variable.trim()] = String(x)
                    result += interpreter.evaluate(body)
                }
                return result
            } else {
                return nil
            }
        })
    }
}
