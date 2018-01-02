import Foundation

public protocol Evaluator {
    associatedtype EvaluatedType
    func evaluate(_ expression: String) -> EvaluatedType
}

public protocol ContextAware {
    var context: InterpreterContext { get }
}

public protocol VariableEvaluator: Evaluator, ContextAware {
    associatedtype VariableEvaluator: Evaluator
    var interpreterForEvaluatingVariables: VariableEvaluator { get }
}

public class InterpreterContext {
    var variables: [String: Any]
    
    init(variables: [String: Any] = [:]) {
        self.variables = variables
    }
}

func matchStatement<T, E>(amongst statements: [Matcher<T, E>], in input: String, from start: Int = 0, until length: Int = 1, interpreter: E) -> MatchResult<T> {
    let results = statements.map { (element: $0, result: $0.matches(string: input, from: start, until: length, interpreter: interpreter)) }
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
            return matchStatement(amongst: statements, in: input, from: start, until: length + 1, interpreter: interpreter)
        }
    }
    return .noMatch
}
