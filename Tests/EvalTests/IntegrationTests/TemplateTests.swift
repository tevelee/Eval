@testable import Eval
import class Eval.Pattern
import XCTest

class TemplateTests: XCTestCase {
    func test_flow() {
        let parenthesis = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { $0.variables["body"] }
        let subtractOperator = infixOperator("-") { (lhs: Double, rhs: Double) in lhs - rhs }

        let interpreter = TypedInterpreter(dataTypes: [numberDataType()], functions: [parenthesis, subtractOperator])

        XCTAssertEqual(interpreter.evaluate("6 - (4 - 2)") as! Double, 4)
    }

    func test_whenAddingALotOfFunctions_thenInterpretationWorksCorrectly() {
        let parenthesis = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { $0.variables["body"] }
        let plusOperator = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }

        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType()],
                                           functions: [concat, parenthesis, plusOperator, lessThan],
                                           context: Context(variables: ["name": "Laszlo Teveli"]))

        let ifStatement = Pattern<String, TemplateInterpreter<String>>([Keyword("{%"), Keyword("if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), Keyword("{% endif %}")]) {
            guard let condition = $0.variables["condition"] as? Bool, let body = $0.variables["body"] as? String else { return nil }
            return condition ? body : nil
        }

        let printStatement = Pattern<String, TemplateInterpreter<String>>([Keyword("{{"), Variable<Any>("body"), Keyword("}}")]) {
            guard let body = $0.variables["body"] else { return nil }
            return $0.interpreter.typedInterpreter.print(body)
        }

        let template = StringTemplateInterpreter(statements: [ifStatement, printStatement], interpreter: interpreter, context: Context())
        XCTAssertEqual(template.evaluate("{{ 1 + 2 }}"), "3.0")
        XCTAssertEqual(template.evaluate("{{ 'Hello' + ' ' + 'World' + '!' }}"), "Hello World!")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}Hello{% endif %} asd"), "asd Hello asd")
        XCTAssertEqual(template.evaluate("ehm, {% if 10 < 21 %}{{ 'Hello ' + name }}{% endif %}!"), "ehm, Hello Laszlo Teveli!")
    }

    func test_whenEmbeddingTags_thenInterpretationWorksCorrectly() {
        let parenthesis = Function<Any>([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { $0.variables["body"] }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType(), booleanDataType()], functions: [parenthesis, lessThan], context: Context())

        let braces = Pattern<String, TemplateInterpreter<String>>([OpenKeyword("("), TemplateVariable("body"), CloseKeyword(")")]) { $0.variables["body"] as? String }
        let ifStatement = Pattern<String, TemplateInterpreter<String>>([OpenKeyword("{% if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), CloseKeyword("{% endif %}")]) {
            guard let condition = $0.variables["condition"] as? Bool, let body = $0.variables["body"] as? String else { return nil }
            return condition ? body : nil
        }

        let template = StringTemplateInterpreter(statements: [braces, ifStatement], interpreter: interpreter, context: Context())
        XCTAssertEqual(template.evaluate("(a)"), "a")
        XCTAssertEqual(template.evaluate("(a(b))"), "ab")
        XCTAssertEqual(template.evaluate("((a)b)"), "ab")
        XCTAssertEqual(template.evaluate("(a(b)c)"), "abc")
        XCTAssertEqual(template.evaluate("{% if 10 < 21 %}Hello {% if true %}you{% endif %}!{% endif %}"), "Hello you!")
    }

    // MARK: Helpers - data types

    func numberDataType() -> DataType<Double> {
        return DataType(type: Double.self,
                        literals: [Literal { Double($0.value) },
                                   Literal("pi", convertsTo: Double.pi) ]) { String(describing: $0.value) }
    }

    func stringDataType() -> DataType<String> {
        let singleQuotesLiteral = Literal { literal -> String? in
            guard let first = literal.value.first, let last = literal.value.last, first == last, first == "'" else { return nil }
            let trimmed = literal.value.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
        }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0.value }
    }

    func booleanDataType() -> DataType<Bool> {
        return DataType(type: Bool.self, literals: [Literal("false", convertsTo: false), Literal("true", convertsTo: true)]) { $0.value ? "true" : "false" }
    }

    // MARK: Helpers - operators

        func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")]) {
            guard let lhs = $0.variables["lhs"] as? A, let rhs = $0.variables["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
}
