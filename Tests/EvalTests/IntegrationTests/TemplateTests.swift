@testable import Eval
import class Eval.Pattern
import XCTest

class TemplateTests: XCTestCase {
    func test_whenAddingALotOfFunctions_thenInterpretationWorksCorrectly() {
        let parenthesis = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { arguments, _, _ in arguments["body"] }
        let plusOperator = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }

        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType()],
                                           functions: [concat, parenthesis, plusOperator, lessThan],
                                           context: Context(variables: ["name": "Laszlo Teveli"]))

        let ifStatement = Pattern<String, TemplateInterpreter<String>>([Keyword("{%"), Keyword("if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), Keyword("{% endif %}")]) { variables, _, _ -> String? in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }

        let printStatement = Pattern([Keyword("{{"), Variable<Any>("body"), Keyword("}}")]) { (variables, interpreter: TemplateInterpreter<String>, _) -> String? in
            guard let body = variables["body"] else { return nil }
            return interpreter.typedInterpreter.print(body)
        }

        let template = StringTemplateInterpreter(statements: [ifStatement, printStatement], interpreter: interpreter, context: Context())
        XCTAssertEqual(template.evaluate("{{ 1 + 2 }}"), "3.0")
        XCTAssertEqual(template.evaluate("{{ 'Hello' + ' ' + 'World' + '!' }}"), "Hello World!")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}Hello{% endif %} asd"), "asd Hello asd")
        XCTAssertEqual(template.evaluate("ehm, {% if 10 < 21 %}{{ 'Hello ' + name }}{% endif %}!"), "ehm, Hello Laszlo Teveli!")
    }

    func test_whenEmbeddingTags_thenInterpretationWorksCorrectly() {
        let parenthesis = Function<Any>([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { variables, _, _ in variables["body"] }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType(), booleanDataType()], functions: [parenthesis, lessThan], context: Context())

        let braces = Pattern<String, TemplateInterpreter<String>>([OpenKeyword("("), TemplateVariable("body"), CloseKeyword(")")]) { variables, _, _ -> String? in
            variables["body"] as? String
        }
        let ifStatement = Pattern<String, TemplateInterpreter<String>>([OpenKeyword("{% if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), CloseKeyword("{% endif %}")]) { variables, _, _ -> String? in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
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
                        literals: [Literal { value, _ in Double(value) },
                                   Literal("pi", convertsTo: Double.pi) ]) { value, _ in String(describing: value) }
    }

    func stringDataType() -> DataType<String> {
        let singleQuotesLiteral = Literal { input, _ -> String? in
            guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
            let trimmed = input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
        }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { value, _ in value }
    }

    func booleanDataType() -> DataType<Bool> {
        return DataType(type: Bool.self, literals: [Literal("false", convertsTo: false), Literal("true", convertsTo: true)]) { value, _ in value ? "true" : "false" }
    }

    // MARK: Helpers - operators

    func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")]) { arguments, _, _ in
            guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
}
