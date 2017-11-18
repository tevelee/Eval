import Foundation

public class NumericExpressionInterpreter : TemplateLanguageInterpreter {
    public func evaluate(_ expression: String) -> Double {
        return Double(interpret(expression)) ?? 0
    }
}

public class BooleanExpressionInterpreter : TemplateLanguageInterpreter {
    public func evaluate(_ expression: String) -> Bool {
        return interpret(expression) == "true"
    }
}
