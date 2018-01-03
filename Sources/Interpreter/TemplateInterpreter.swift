import Foundation

public class TemplateInterpreter : VariableEvaluator {
    public typealias EvaluatedType = String
    public typealias VariableEvaluator = TypedInterpreterBase
    
    let statements: [Matcher<String, TemplateInterpreter>]
    public let context: InterpreterContext
    public let typedInterpreter: TypedInterpreter
    public lazy var interpreterForEvaluatingVariables: TypedInterpreterBase = { [unowned self] in typedInterpreter }()
    
    public init(statements: [Matcher<String, TemplateInterpreter>],
                interpreter: TypedInterpreter,
                context: InterpreterContext) {
        self.statements = statements
        self.typedInterpreter = interpreter
        self.context = context
    }
    
    public func evaluate(_ expression: String) -> String {
        return evaluate(expression, context: nil)
    }
    
    public func evaluate(_ expression: String, context: InterpreterContext? = nil) -> String {
        let context = self.context.merge(with: context)
        var output = ""
        
        var position = 0
        repeat {
            let result = matchStatement(amongst: statements, in: expression, from: position, interpreter: self, context: context)
            switch result {
            case .noMatch, .possibleMatch:
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

public class TemplateVariable : GenericVariable<String, TemplateInterpreter> {
    public init(_ name: String, shortest: Bool = true) {
        super.init(name, shortest: shortest, interpreted: false) { value, interpreter in
            guard let stringValue = value as? String else { return "" }
            return interpreter.evaluate(stringValue)
        }
    }
}
