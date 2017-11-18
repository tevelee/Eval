import Foundation
import Interpreter
import class Interpreter.Pattern

func boolOperator(keyword: String, renderer: ContextAwareRenderer, parser: @escaping (Double, Double) -> Bool) -> Pattern {
    return Pattern([Variable("lhs"), Keyword(keyword), Variable("rhs")], renderer: renderer.contextAwareRender { variables, context in
        if let lhs = variables["lhs"] as? String, let rhs = variables["rhs"] as? String {
            let lhsValue : Double = numericExpressionInterpreter().evaluate(lhs.trim())
            let rhsValue : Double = numericExpressionInterpreter().evaluate(rhs.trim())
            return parser(lhsValue, rhsValue) ? "true" : "false"
        }
        return "false"
    })
}

func numericOperator(keyword: String, parser: @escaping (Double, Double) -> Double) -> Pattern {
    return Pattern([Variable("lhs"), Keyword(keyword), Variable("rhs")]) { variables in
        if let lhs = variables["lhs"] as? String, let rhs = variables["rhs"] as? String {
            let lhsValue : Double = numericExpressionInterpreter().evaluate(lhs.trim())
            let rhsValue : Double = numericExpressionInterpreter().evaluate(rhs.trim())
            return String(parser(lhsValue, rhsValue))
        }
        return ""
    }
}

func numericExpressionInterpreter() -> NumericExpressionInterpreter {
    let brackets = Pattern([Keyword("("), Variable("body"), Keyword(")")]) { variables in
        if let content = variables["body"] as? String {
            return content
        }
        return nil
    }
    let plus = numericOperator(keyword: "+") { lhs, rhs in lhs + rhs }
    let minus = numericOperator(keyword: "-") { lhs, rhs in lhs - rhs }
    let multiplication = numericOperator(keyword: "*") { lhs, rhs in lhs * rhs }
    let division = numericOperator(keyword: "/") { lhs, rhs in lhs / rhs }
    return NumericExpressionInterpreter(statements: [brackets, division, multiplication, plus, minus])
}

func booleanExpressionInterpreter(variables: [String: Any] = [:]) -> BooleanExpressionInterpreter {
    let renderer = ContextAwareRenderer(context: RenderingContext(variables: variables))
    
    let equal = boolOperator(keyword: "==", renderer: renderer) { (lhs: Double, rhs: Double) in lhs == rhs }
    let greaterThan = boolOperator(keyword: ">", renderer: renderer) { lhs, rhs in lhs > rhs }
    let greaterThanOrEqual = boolOperator(keyword: ">=", renderer: renderer) { lhs, rhs in lhs >= rhs }
    let lessThan = boolOperator(keyword: "<", renderer: renderer) { lhs, rhs in lhs < rhs }
    let lessThanOrEqual = boolOperator(keyword: "<=", renderer: renderer) { lhs, rhs in lhs <= rhs }
    return BooleanExpressionInterpreter(statements: [equal, greaterThanOrEqual, greaterThan, lessThanOrEqual, lessThan])
}
