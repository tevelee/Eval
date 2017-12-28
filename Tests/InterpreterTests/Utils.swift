import Foundation
import Interpreter
import class Interpreter.Pattern
import struct Interpreter.Variable
import struct Interpreter.Keyword

public class BooleanInterpreterFactory : BooleanInterpreterProviderFeature {
    public weak var platform: RenderingPlatform?
    
    public required init(platform: RenderingPlatform) {
        self.platform = platform
    }
    
    public func booleanExpressionInterpreter() -> BooleanExpressionInterpreter {
        return BooleanExpressionInterpreter(platform: platform)
    }
}

public class NumericInterpreterFactory : NumericInterpreterProviderFeature {
    public weak var platform: RenderingPlatform?
    
    public required init(platform: RenderingPlatform) {
        self.platform = platform
    }
    
    public func numericExpressionInterpreter() -> NumericExpressionInterpreter {
        return NumericExpressionInterpreter(platform: platform)
    }
}

public class StringInterpreterFactory : StringInterpreterProviderFeature {
    public weak var platform: RenderingPlatform?
    
    public required init(platform: RenderingPlatform) {
        self.platform = platform
    }
    
    public func stringExpressionInterpreter() -> StringExpressionInterpreter {
        return StringExpressionInterpreter(statements: [
            commentBlock(),
            ifElseStatement(tagPrefix: "{%", tagSuffix: "%}"),
            ifStatement(tagPrefix: "{%", tagSuffix: "%}"),
            printStatement(tagPrefix: "{{", tagSuffix: "}}"),
            setStatement(tagPrefix: "{%", tagSuffix: "%}"),
            setAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}"),
            forStatement(tagPrefix: "{%", tagSuffix: "%}"),
            forAlternativeStatement(tagPrefix: "{%", tagSuffix: "%}"),
        ])
    }

    func printStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        return Pattern([Keyword(tagPrefix), Variable("body"), Keyword(tagSuffix)], platform: platform) { platform, variables in
            guard let variable = variables["body"] as? String else { return "" }
            if let contextHandler = platform.capability(of: ContextHandler.self),
                let result = contextHandler.context.variables[variable.trim()] as? String {
                return result
            } else if let numericInterpreter = platform.capability(of: NumericInterpreterProviderFeature.self)?.numericExpressionInterpreter(),
                let numericResult = try? numericInterpreter.evaluate(variable) {
                return numericResult.truncatingRemainder(dividingBy: 1) == 0 ?
                    String(format: "%.0f", numericResult) :
                    String(numericResult) // avoid zero sufffix (e.g. 5.0) when result is whole number
            }
            return ""
        }
    }

    func ifStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        return Pattern([Keyword(tagPrefix), Keyword("if"), Variable("condition"), Keyword(tagSuffix),
                        Variable("body"),
                        Keyword(tagPrefix), Keyword("endif"), Keyword(tagSuffix)],
                       platform: platform) { platform, variables in
            guard let condition = variables["condition"] as? String, let body = variables["body"] as? String,
                let booleanInterpreter = platform.capability(of: BooleanInterpreterProviderFeature.self)?.booleanExpressionInterpreter() else { return "" }
            if let result = try? booleanInterpreter.evaluate(condition.trim()), result {
                return body
            }
            return ""
        }
    }

    func ifElseStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("if"), Variable("condition"), Keyword(tagSuffix)])
        let elseTag = Pattern([Keyword(tagPrefix), Keyword("else"), Keyword(tagSuffix)])
        let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endif"), Keyword(tagSuffix)])
        return Pattern([ifOpeningTag, Variable("body"), elseTag, Variable("else"), ifClosingTag], platform: platform) { platform, variables in
            guard let condition = variables["condition"] as? String, let body = variables["body"] as? String,
                let booleanInterpreter = platform.capability(of: BooleanInterpreterProviderFeature.self)?.booleanExpressionInterpreter() else { return "" }
            if let result = try? booleanInterpreter.evaluate(condition.trim()), result {
                return body
            } else if let body = variables["else"] as? String {
                return body
            }
            return ""
        }
    }

    func commentBlock() -> Pattern {
        return Pattern([Keyword("{#"), Variable("body"), Keyword("#}")])
    }

    func setStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        let setOpeningTag = Pattern([Keyword(tagPrefix), Keyword("set"), Variable("variable"), Keyword(tagSuffix)])
        let setClosingTag = Pattern([Keyword(tagPrefix), Keyword("endset"), Keyword(tagSuffix)])
        return Pattern([setOpeningTag, Variable("value"), setClosingTag], platform: platform) { platform, variables in
            guard let variable = variables["variable"] as? String, let value = variables["value"] as? String,
                let contextHandler = platform.capability(of: ContextHandlerFeature.self) else { return "" }
            contextHandler.context.variables[variable.trim()] = value.trim()
            return ""
        }
    }

    func setAlternativeStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        return Pattern([Keyword(tagPrefix), Keyword("set"), Variable("variable"), Keyword("="), Variable("value"), Keyword(tagSuffix)], platform: platform) { platform, variables in
            guard let variable = variables["variable"] as? String, let value = variables["value"] as? String,
                let contextHandler = platform.capability(of: ContextHandlerFeature.self) else { return "" }
            contextHandler.context.variables[variable.trim()] = value.trim()
            return ""
        }
    }

    func forStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("for"), Variable("variable"), Keyword("from"), Variable("from"), Keyword("to"), Variable("to"), Keyword(tagSuffix)])
        let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endfor"), Keyword(tagSuffix)])
        return Pattern([ifOpeningTag, Variable("body"), ifClosingTag], platform: platform) { platform, variables in
            guard let variable = variables["variable"] as? String,
            let from = variables["from"] as? String,
            let to = variables["to"] as? String,
            let body = variables["body"] as? String,
            let fromInt = Int(from.trim()), let toInt = Int(to.trim()),
            let contextHandler = platform.capability(of: ContextHandlerFeature.self),
            let stringInterpreter = platform.capability(of: StringInterpreterProviderFeature.self)?.stringExpressionInterpreter() else { return "" }
            
            var result = ""
            for x in fromInt ... toInt {
                contextHandler.context.variables[variable.trim()] = String(x)
                result += try! stringInterpreter.evaluate(body)
            }
            return result
        }
    }

    func forAlternativeStatement(tagPrefix: String, tagSuffix: String) -> Pattern {
        let ifOpeningTag = Pattern([Keyword(tagPrefix), Keyword("for"), Variable("variable"), Keyword("in"), Variable("source"), Keyword(tagSuffix)])
        let ifClosingTag = Pattern([Keyword(tagPrefix), Keyword("endfor"), Keyword(tagSuffix)])
        return Pattern([ifOpeningTag, Variable("body"), ifClosingTag], platform: platform) { platform, variables in
            guard let variable = variables["variable"] as? String,
                let source = variables["source"] as? String,
                let body = variables["body"] as? String,
                let contextHandler = platform.capability(of: ContextHandlerFeature.self),
                let stringInterpreter = platform.capability(of: StringInterpreterProviderFeature.self)?.stringExpressionInterpreter(),
                let sourceArray = contextHandler.context.variables[source.trim()] as? [Int] else { return "" }
                
            var result = ""
            for x in sourceArray {
                contextHandler.context.variables[variable.trim()] = String(x)
                result += try! stringInterpreter.evaluate(body)
            }
            return result
        }
    }

    func inc() -> Pattern {
        return Pattern([Keyword("inc"), Keyword("("), Variable("arguments"), Keyword(")")], platform: platform) { platform, variables in
            guard let args = variables["arguments"] as? String,
                let variable = args.trim().components(separatedBy: ",").first,
                let contextHandler = platform.capability(of: ContextHandlerFeature.self),
                let value = contextHandler.context.variables[variable] as? Int else { return "" }
            return String(value + 1)
        }
    }

    func incFilter() -> Pattern {
        return Pattern([Variable("variable"), Keyword("|"), Keyword("inc")], platform: platform) { platform, variables in
            guard let variable = variables["variable"] as? String,
                let contextHandler = platform.capability(of: ContextHandlerFeature.self),
                let value = contextHandler.context.variables[variable] as? Int else { return "" }
            return String(value + 1)
        }
    }
}
