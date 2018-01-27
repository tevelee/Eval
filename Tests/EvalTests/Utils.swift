import Foundation
import Eval

class DummyInterpreter: Interpreter {
    typealias VariableEvaluator = DummyInterpreter
    typealias EvaluatedType = String
    var context: Context
    var interpreterForEvaluatingVariables: DummyInterpreter { return self }
    func evaluate(_ expression: String) -> String { return "a" }
    func evaluate(_ expression: String, context: Context) -> String { return "a" }
    init() { context = Context()}
}
