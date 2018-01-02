import Foundation

public class TemplateInterpreter : VariableEvaluator {
    public typealias EvaluatedType = String
    public typealias VariableEvaluator = TypedInterpreterBase
    
    let statements: [Matcher<String, TemplateInterpreter>]
    public let context: InterpreterContext
    public let typedInterpreter: TypedInterpreter
    public lazy var interpreterForEvaluatingVariables: TypedInterpreterBase = { [unowned self] in typedInterpreter }()
    
    init(statements: [Matcher<String, TemplateInterpreter>],
         interpreter: TypedInterpreter,
         context: InterpreterContext) {
        self.statements = statements
        self.typedInterpreter = interpreter
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

public class TemplateVariable : Variable<String, TemplateInterpreter> {
    public init(_ name: String, shortest: Bool = true) {
        super.init(name, shortest: shortest, interpreted: false) { value, interpreter in
            guard let stringValue = value as? String else { return "" }
            return interpreter.evaluate(stringValue)
        }
    }
}
