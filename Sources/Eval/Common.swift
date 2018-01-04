import Foundation

public protocol Evaluator {
    associatedtype EvaluatedType
    func evaluate(_ expression: String) -> EvaluatedType
}

public protocol EvaluatorWithContext: Evaluator {
    func evaluate(_ expression: String, context: InterpreterContext) -> EvaluatedType
}

public protocol ContextAware {
    var context: InterpreterContext { get }
}

public protocol Interpreter: EvaluatorWithContext, ContextAware {
    associatedtype VariableEvaluator: EvaluatorWithContext
    var interpreterForEvaluatingVariables: VariableEvaluator { get }
}

public class InterpreterContext {
    public var variables: [String: Any]
    
    public init(variables: [String: Any] = [:]) {
        self.variables = variables
    }
    
    func merge(with other: InterpreterContext? = nil) -> InterpreterContext {
        if let other = other {
            return InterpreterContext(variables: self.variables.merging(other.variables) { (key, value) in key } )
        } else {
            return self
        }
    }
}

func matchStatement<T, E>(amongst statements: [Matcher<T, E>], in input: String, from start: Int = 0, until length: Int = 1, interpreter: E, context: InterpreterContext) -> MatchResult<T> {
    let results = statements.map { statement -> (element: Matcher<T, E>, result: MatchResult<T>) in
        let result = statement.matches(string: input, from: start, until: length, interpreter: interpreter, context: context)
        return (element: statement, result: result)
    }
    let elements = results.filter { !$0.result.isNoMatch() }
    
    if elements.count == 0 {
        return .noMatch
    }
    if let matchingElement = elements.first(where: { $0.result.isMatch() }),
        case .exactMatch(let length, let output, let variables) = matchingElement.result {
        return .exactMatch(length: length, output: output, variables: variables)
    }
    if elements.contains(where: { $0.result.isPossibleMatch() }) {
        if input.count == start + length {
            return .possibleMatch
        } else {
            return matchStatement(amongst: statements, in: input, from: start, until: length + 1, interpreter: interpreter, context: context)
        }
    }
    return .noMatch
}
