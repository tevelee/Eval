//: Playground - noun: a place where people can play
import Foundation
import Eval

let context = InterpreterContext()

let interpreter = TypedInterpreter(dataTypes: [numberDataType, stringDataType, arrayDataType, booleanDataType, dateDataType],
                                   functions: [parentheses, multipication, addition, lessThan],
                                   context: context)

let template = TemplateInterpreter(statements: [ifStatement, printStatement],
                                   interpreter: interpreter,
                                   context: context)

interpreter.evaluate("2 + 3 * 4")

template.evaluate("{% if 10 < 21 %}Hello{% endif %} {{ name }}!", context: InterpreterContext(variables: ["name": "Eval"]))
