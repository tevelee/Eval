import Foundation

public protocol Evaluator {
    associatedtype T
    var context: InterpreterContext { get }
    func evaluate(_ expression: String) -> T
}

public class InterpreterContext {
    var variables: [String: Any]
    
    init(variables: [String: Any] = [:]) {
        self.variables = variables
    }
}

func isStatement<T, E>(statements: [Matcher<T, E>], in input: String, from start: Int = 0, until length: Int = 1, interpreter: E) -> MatchResult<T> {
    let prefix = String(input[start ..< start + length])
    let isLast = input.count == start + length
    let results = statements.map { (element: $0, result: $0.matches(prefix: prefix, interpreter: interpreter, isLast: isLast)) }
    let elements = results.filter { !$0.result.isNoMatch() }
    
    if elements.count == 0 {
        return .noMatch
    }
    if let matchingElement = elements.first(where: { $0.result.isMatch() }),
        case .exactMatch(let length, let output, let variables) = matchingElement.result {
        return .exactMatch(length: length, output: output, variables: variables)
    }
    if elements.contains(where: { $0.result.isPossibleMatch() }) {
        if isLast {
            return .noMatch
        } else {
            return isStatement(statements: statements, in: input, from: start, until: length + 1, interpreter: interpreter)
        }
    }
    return .noMatch
}
