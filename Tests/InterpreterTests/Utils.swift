import Foundation
import Interpreter
import class Interpreter.Pattern
import struct Interpreter.Variable
import struct Interpreter.Keyword

class TestInterpreterFactory: InterpreterFactory {
    func stringExpressionInterpreter() -> StringExpressionInterpreter {
        return stringExpressionInterpreter(context: RenderingContext())
    }
    
    func booleanExpressionInterpreter() -> BooleanExpressionInterpreter {
        return booleanExpressionInterpreter(context: RenderingContext())
    }
    
    func booleanExpressionInterpreter(context: RenderingContext) -> BooleanExpressionInterpreter {
        let renderer = ContextAwareRenderer(context: context)
        
        let equal = boolOperator(keyword: "==", renderer: renderer) { (lhs: Double, rhs: Double) in lhs == rhs }
        let greaterThan = boolOperator(keyword: ">", renderer: renderer) { lhs, rhs in lhs > rhs }
        let greaterThanOrEqual = boolOperator(keyword: ">=", renderer: renderer) { lhs, rhs in lhs >= rhs }
        let lessThan = boolOperator(keyword: "<", renderer: renderer) { lhs, rhs in lhs < rhs }
        let lessThanOrEqual = boolOperator(keyword: "<=", renderer: renderer) { lhs, rhs in lhs <= rhs }
        return BooleanExpressionInterpreter(statements: [equal, greaterThanOrEqual, greaterThan, lessThanOrEqual, lessThan])
    }
    
    func numericExpressionInterpreter() -> NumericExpressionInterpreter {
        let brackets = Pattern([Keyword("("), Variable("body"), Keyword(")")]) { variables, _ in
            if let content = variables["body"] as? String {
                return content
            }
            return ""
        }
        let plus = numericOperator(keyword: "+") { lhs, rhs in lhs + rhs }
        let minus = numericOperator(keyword: "-") { lhs, rhs in lhs - rhs }
        let multiplication = numericOperator(keyword: "*") { lhs, rhs in lhs * rhs }
        let division = numericOperator(keyword: "/") { lhs, rhs in lhs / rhs }
        return NumericExpressionInterpreter(statements: [brackets, division, multiplication, plus, minus])
    }
    
    func stringExpressionInterpreter(context: RenderingContext) -> StringExpressionInterpreter {
        let renderer = ContextAwareRenderer(context: context)
        return StringExpressionInterpreter(statements:
            [
                commentBlock(interpreterFactory: self),
                ifElseStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer, interpreterFactory: self),
                ifStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer, interpreterFactory: self),
                printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer),
                setStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                setAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer),
                forStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer, interpreterFactory: self),
                forAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}", renderer: renderer, interpreterFactory: self),
            ])
    }
    
    func boolOperator(keyword: String, renderer: ContextAwareRenderer, parser: @escaping (Double, Double) -> Bool) -> Pattern {
        return Pattern([Variable("lhs"), Keyword(keyword), Variable("rhs")], renderer: renderer.render { variables, _, context in
            if let lhs = variables["lhs"] as? String, let rhs = variables["rhs"] as? String {
                let lhsValue : Double = self.numericExpressionInterpreter().evaluate(lhs.trim())
                let rhsValue : Double = self.numericExpressionInterpreter().evaluate(rhs.trim())
                return parser(lhsValue, rhsValue) ? "true" : "false"
            }
            return "false"
        })
    }
    
    func numericOperator(keyword: String, parser: @escaping (Double, Double) -> Double) -> Pattern {
        return Pattern([Variable("lhs"), Keyword(keyword), Variable("rhs")]) { variables, _ in
            if let lhs = variables["lhs"] as? String, let rhs = variables["rhs"] as? String {
                let lhsValue : Double = self.numericExpressionInterpreter().evaluate(lhs.trim())
                let rhsValue : Double = self.numericExpressionInterpreter().evaluate(rhs.trim())
                return String(parser(lhsValue, rhsValue))
            }
            return ""
        }
    }
}

func printStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
    return Pattern([Keyword(tagPrefix), Variable("body"), Keyword(tagSuffix)], renderer: renderer.render { variables, _, context in
        if let variable = variables["body"] as? String,
            let result = context.variables[variable.trim()] as? String {
            return result
        }
        return ""
    })
}

func ifStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer, interpreterFactory: InterpreterFactory? = nil) -> Pattern {
    let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("if"), Variable("condition"), Keyword(tagSuffix)])
    let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endif"), Keyword(tagSuffix)])
    return Pattern([ifOpeningTag, Variable("body"), ifClosingTag],
                   interpreterFactory: interpreterFactory,
                   renderer: renderer.render { variables, interpreterFactory, context in
        if let condition = variables["condition"] as? String,
            let body = variables["body"] as? String,
            let factory = interpreterFactory as? TestInterpreterFactory,
            factory.booleanExpressionInterpreter(context: context).evaluate(condition.trim()) {
            return body
        } else {
            return ""
        }
    })
}

func ifElseStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer, interpreterFactory: InterpreterFactory) -> Pattern {
    let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("if"), Variable("condition"), Keyword(tagSuffix)], interpreterFactory: interpreterFactory)
    let elseTag = Pattern([Keyword(tagPrefix), Keyword("else"), Keyword(tagSuffix)], interpreterFactory: interpreterFactory)
    let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endif"), Keyword(tagSuffix)], interpreterFactory: interpreterFactory)
    return Pattern([ifOpeningTag, Variable("body"), elseTag, Variable("else"), ifClosingTag], interpreterFactory: interpreterFactory, renderer: renderer.render { variables, _, context in
        if let condition = variables["condition"] as? String,
            let body = variables["body"] as? String,
            let factory = interpreterFactory as? TestInterpreterFactory,
            factory.booleanExpressionInterpreter(context: context).evaluate(condition.trim()) {
            return body
        } else if let body = variables["else"] as? String {
            return body
        }
        return ""
    })
}

func commentBlock(interpreterFactory: InterpreterFactory) -> Pattern {
    return Pattern([Keyword("{#"), Variable("body"), Keyword("#}")], interpreterFactory: interpreterFactory)
}

func setStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
    let setOpeningTag = Pattern([Keyword(tagPrefix), Keyword("set"), Variable("variable"), Keyword(tagSuffix)])
    let setClosingTag = Pattern([Keyword(tagPrefix), Keyword("endset"), Keyword(tagSuffix)])
    return Pattern([setOpeningTag, Variable("value"), setClosingTag], renderer: renderer.render { variables, _, context in
        if let variable = variables["variable"] as? String,
            let value = variables["value"] as? String {
            context.variables[variable.trim()] = value.trim()
        }
        return ""
    })
}

func setAlternativeStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer) -> Pattern {
    return Pattern([Keyword(tagPrefix), Keyword("set"), Variable("variable"), Keyword("="), Variable("value"), Keyword(tagSuffix)], renderer: renderer.render { variables, _, context in
        if let variable = variables["variable"] as? String,
            let value = variables["value"] as? String {
            context.variables[variable.trim()] = value.trim()
        }
        return ""
    })
}

func forStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer, interpreterFactory: InterpreterFactory? = nil) -> Pattern {
    let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("for"), Variable("variable"), Keyword("from"), Variable("from"), Keyword("to"), Variable("to"), Keyword(tagSuffix)])
    let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endfor"), Keyword(tagSuffix)])
    return Pattern([ifOpeningTag, Variable("body"), ifClosingTag],
                   interpreterFactory: interpreterFactory,
                   renderer: renderer.render { variables, interpreter, context in
                    if let variable = variables["variable"] as? String,
                        let from = variables["from"] as? String,
                        let to = variables["to"] as? String,
                        let body = variables["body"] as? String,
                        let fromInt = Int(from.trim()), let toInt = Int(to.trim()),
                        let stringInterpreter = interpreter as? TestInterpreterFactory {
                        
                        var result = ""
                        for x in fromInt ... toInt {
                            context.variables[variable.trim()] = String(x)
                            result += stringInterpreter.stringExpressionInterpreter(context: context).evaluate(body)
                        }
                        return result
                    } else {
                        return ""
                    }
    })
}

func forAlternativeStatement(tagPrefix: String, tagSuffix: String, renderer: ContextAwareRenderer, interpreterFactory: InterpreterFactory? = nil) -> Pattern {
    let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("for"), Variable("variable"), Keyword("in"), Variable("source"), Keyword(tagSuffix)])
    let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endfor"), Keyword(tagSuffix)])
    return Pattern([ifOpeningTag, Variable("body"), ifClosingTag], interpreterFactory: interpreterFactory, renderer: renderer.render { variables, _, context in
        if let variable = variables["variable"] as? String,
            let source = variables["source"] as? String,
            let body = variables["body"] as? String,
            let sourceArray = context.variables[source.trim()] as? [Int] {
            
            let renderer = ContextAwareRenderer(context: context)
            let interpreter = StringExpressionInterpreter(statements: [printStatement(tagPrefix: "{{", tagSuffix: "}}", renderer: renderer)])
            
            var result = ""
            for x in sourceArray {
                renderer.context.variables[variable.trim()] = String(x)
                result += interpreter.evaluate(body)
            }
            return result
        } else {
            return ""
        }
    })
}

func inc(renderer: ContextAwareRenderer) -> Pattern {
    return Pattern([Keyword("inc"), Keyword("("), Variable("arguments"), Keyword(")")],
                   renderer: renderer.render { variables, _, context in
                    if let args = variables["arguments"] as? String,
                        let variable = args.trim().components(separatedBy: ",").first,
                        let value = context.variables[variable] as? Int {
                        return String(value + 1)
                    }
                    return ""
    })
}

func incFilter(renderer: ContextAwareRenderer) -> Pattern {
    return Pattern([Variable("variable"), Keyword("|"), Keyword("inc")],
                   renderer: renderer.render { variables, _, context in
                    if let variable = variables["variable"] as? String,
                        let value = context.variables[variable] as? Int {
                        return String(value + 1)
                    }
                    return ""
    })
}
