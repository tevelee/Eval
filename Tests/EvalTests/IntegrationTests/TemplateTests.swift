import XCTest
@testable import Eval

class TemplateTests: XCTestCase {
    func test_whenAddingALotOfFunctions_thenInterpretationWorksCorrectly() {
        let parenthesis = Function([Keyword("("), Variable<Any>("body"), Keyword(")")]) { arguments,_,_ in arguments["body"] }
        let plusOperator = infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
        let concat = infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
        
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType()],
                                           functions: [concat, parenthesis, plusOperator, lessThan],
                                           context: InterpreterContext(variables: ["name": "Laszlo Teveli"]))
        
        let ifStatement = Matcher([Keyword("{%"), Keyword("if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), Keyword("{%"), Keyword("endif"), Keyword("%}")]) { (variables, interpreter: TemplateInterpreter, _) -> String? in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }
        
        let printStatement = Matcher([Keyword("{{"), Variable<Any>("body"), Keyword("}}")]) { (variables, interpreter: TemplateInterpreter, _) -> String? in
            guard let body = variables["body"] else { return nil }
            return interpreter.typedInterpreter.print(body)
        }
        
        let template = TemplateInterpreter(statements: [ifStatement, printStatement], interpreter: interpreter, context: InterpreterContext())
        XCTAssertEqual(template.evaluate("{{ 1 + 2 }}"), "3.0")
        XCTAssertEqual(template.evaluate("{{ 'Hello' + ' ' + 'World' + '!' }}"), "Hello World!")
        XCTAssertEqual(template.evaluate("asd {% if 10 < 21 %}Hello{% endif %} asd"), "asd Hello asd")
        XCTAssertEqual(template.evaluate("ehm, {% if 10 < 21 %}{{ 'Hello ' + name }}{% endif %}!"), "ehm, Hello Laszlo Teveli!")
    }
    
    func test_whenEmbeddingTags_thenInterpretationWorksCorrectly() {
        let parenthesis = Function<Any>([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { variables,_,_ in variables["body"] }
        let lessThan = infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
        let interpreter = TypedInterpreter(dataTypes: [numberDataType(), stringDataType(), booleanDataType()], functions: [parenthesis, lessThan], context: InterpreterContext())

        let braces = Matcher([OpenKeyword("("), TemplateVariable("body"), CloseKeyword(")")]) { (variables, interpreter: TemplateInterpreter, _) -> String? in
            return variables["body"] as? String
        }
        let ifStatement = Matcher([OpenKeyword("{% if"), Variable<Bool>("condition"), Keyword("%}"), TemplateVariable("body"), CloseKeyword("{% endif %}")]) { (variables, interpreter: TemplateInterpreter, _) -> String? in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return nil
        }
        
        let template = TemplateInterpreter(statements: [braces, ifStatement], interpreter: interpreter, context: InterpreterContext())
        XCTAssertEqual(template.evaluate("(a)"), "a")
        XCTAssertEqual(template.evaluate("(a(b))"), "ab")
        XCTAssertEqual(template.evaluate("((a)b)"), "ab")
        XCTAssertEqual(template.evaluate("(a(b)c)"), "abc")
        XCTAssertEqual(template.evaluate("{% if 10 < 21 %}Hello {% if true %}you{% endif %}!{% endif %}"), "Hello you!")
    }
    
    //MARK: Helpers - data types

    func numberDataType() -> DataType<Double> {
        return DataType(type: Double.self, literals: [Literal { v,_ in Double(v) },
                                                      Literal("pi", convertsTo: Double.pi) ]) { String(describing: $0) }
    }
    
    func stringDataType() -> DataType<String> {
        let singleQuotesLiteral = Literal { (input, _) -> String? in
            guard let first = input.first, let last = input.last, first == last, first == "'" else { return nil }
            let trimmed = input.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            return trimmed.contains("'") ? nil : trimmed
        }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0 }
    }
    
    func booleanDataType() -> DataType<Bool> {
        return DataType(type: Bool.self, literals: [Literal("false", convertsTo: false),
                                                    Literal("true", convertsTo: true)]) { $0 ? "true" : "false" }
    }
    
    //MARK: Helpers - operators
    
    func infixOperator<A,B,T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T?> {
        return Function([Variable<A>("lhs", shortest: true), Keyword(symbol), Variable<B>("rhs", shortest: false)]) { arguments,_,_ in
            guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }
}
