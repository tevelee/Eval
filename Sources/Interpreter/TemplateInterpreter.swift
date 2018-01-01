import Foundation

public class TemplateInterpreter : Evaluator {
    public typealias T = String
    
    let statements: [Matcher<String, TemplateInterpreter>]
    public let context: InterpreterContext
    public let interpreter: TypedInterpreter
    
    init(statements: [Matcher<String, TemplateInterpreter>],
         interpreter: TypedInterpreter,
         context: InterpreterContext) {
        self.statements = statements
        self.interpreter = interpreter
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> String {
        var output = ""
        
        var position = 0
        repeat {
            let result = isStatement(statements: statements, in: expression, from: position, interpreter: self)
            switch result {
            case .noMatch:
                output += expression[position]
                position += 1
            case .exactMatch(let length, let matchOutput, _):
                output += matchOutput
                position += length
            default:
                assertionFailure("Invalid result")
            }
        } while position < expression.count
        
        return output
    }
}
