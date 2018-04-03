@_exported import Eval
@_exported import class Eval.Pattern
import Foundation

public class TemplateLanguage: EvaluatorWithLocalContext {
    public typealias EvaluatedType = String

    let language: StringTemplateInterpreter
    let macroReplacer: StringTemplateInterpreter

    init(dataTypes: [DataTypeProtocol] = StandardLibrary.dataTypes,
         functions: [FunctionProtocol] = StandardLibrary.functions,
         templates: [Pattern<String, TemplateInterpreter<String>>] = TemplateLibrary.templates,
         context: Context = Context()) {
        TemplateLanguage.preprocess(context)

        let interpreter = TypedInterpreter(dataTypes: dataTypes, functions: functions, context: context)
        let language = StringTemplateInterpreter(statements: templates, interpreter: interpreter, context: context)
        self.language = language

        let block = Pattern<String, TemplateInterpreter<String>>([OpenKeyword("{{{"), TemplateVariable("name", options: .notInterpreted), CloseKeyword("}}}")]) { variables, _, _ in
            guard let name = variables["name"] as? String else { return nil }
            return language.context.blocks[name]?.last?(language.context)
        }
        macroReplacer = StringTemplateInterpreter(statements: [block])
    }

    public func evaluate(_ expression: String) -> String {
        return evaluate(expression, context: Context())
    }

    public func evaluate(_ expression: String, context: Context) -> String {
        TemplateLanguage.preprocess(context)
        let input = replaceWhitespaces(expression)
        let result = language.evaluate(input, context: context)
        let finalResult = macroReplacer.evaluate(result)
        return finalResult.contains(TemplateLibrary.tagPrefix) ? language.evaluate(finalResult, context: context) : finalResult
    }

    public func evaluate(template from: URL) throws -> String {
        let expression = try String(contentsOf: from)
        return evaluate(expression)
    }

    public func evaluate(template from: URL, context: Context) throws -> String {
        let expression = try String(contentsOf: from)
        return evaluate(expression, context: context)
    }

    static func preprocess(_ context: Context) {
        context.variables = context.variables.mapValues { value in
            convert(value) {
                if let integerValue = $0 as? Int {
                    return Double(integerValue)
                }
                return $0
            }
        }
    }

    static func convert(_ value: Any, recursively: Bool = true, convert: @escaping (Any) -> Any) -> Any {
        if recursively, let array = value as? [Any] {
            return array.map { convert($0) }
        }
        if recursively, let dictionary = value as? [String: Any] {
            return dictionary.mapValues { convert($0) }
        }
        return convert(value)
    }

    func replaceWhitespaces(_ input: String) -> String {
        let tag = "{-}"
        var input = input
        repeat {
            if var range = input.range(of: tag) {
                searchForward: while true {
                    if range.upperBound < input.index(before: input.endIndex) {
                        let nextIndex = range.upperBound
                        if let unicodeScalar = input[nextIndex].unicodeScalars.first,
                            CharacterSet.whitespacesAndNewlines.contains(unicodeScalar) {
                            range = Range(uncheckedBounds: (lower: range.lowerBound, upper: input.index(after: range.upperBound)))
                        } else {
                            break searchForward
                        }
                    } else {
                        break searchForward
                    }
                }
                searchBackward: while true {
                    if range.lowerBound > input.startIndex {
                        let nextIndex = input.index(before: range.lowerBound)
                        if let unicodeScalar = input[nextIndex].unicodeScalars.first,
                            CharacterSet.whitespacesAndNewlines.contains(unicodeScalar) {
                            range = Range(uncheckedBounds: (lower: input.index(before: range.lowerBound), upper: range.upperBound))
                        } else {
                            break searchBackward
                        }
                    } else {
                        break searchBackward
                    }
                }
                input.replaceSubrange(range, with: "")
            }
        } while input.contains(tag)
        return input
    }
}

internal typealias Macro = (arguments: [String], body: String)
internal typealias BlockRenderer = (_ context: Context) -> String

extension Context {
    static let macrosKey: String = "__macros"
    var macros: [String: Macro] {
        get {
            return variables[Context.macrosKey] as? [String: Macro] ?? [:]
        }
        set {
            variables[Context.macrosKey] = macros.merging(newValue) { _, new in new }
        }
    }

    static let blocksKey: String = "__blocks"
    var blocks: [String: [BlockRenderer]] {
        get {
            return variables[Context.blocksKey] as? [String: [BlockRenderer]] ?? [:]
        }
        set {
            variables[Context.blocksKey] = blocks.merging(newValue) { _, new in new }
        }
    }
}

public class TemplateLibrary {
    public static var standardLibrary: StandardLibrary = StandardLibrary()
    public static var templates: [Pattern<String, TemplateInterpreter<String>>] {
        return [
            ifElseStatement,
            ifStatement,
            printStatement,
            forInStatement,
            setUsingBodyStatement,
            setStatement,
            blockStatement,
            macroStatement,
            commentStatement,
            importStatement,
            spacelessStatement
        ]
    }

    public static var tagPrefix: String = "{%"
    public static var tagSuffix: String = "%}"

    public static var ifStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([Keyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body", options: .notTrimmed) { value, _ in
            guard let content = value as? String, !content.contains(tagPrefix + " else " + tagSuffix) else { return nil }
            return content
        }, Keyword("{%"), Keyword("endif"), Keyword("%}")]) { variables, _, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            }
            return ""
        }
    }

    public static var ifElseStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body", options: .notTrimmed) { value, _ in
            guard let content = value as? String, !content.contains(tagPrefix + " else " + tagSuffix) else { return nil }
            return content
        }, Keyword(tagPrefix + " else " + tagSuffix), TemplateVariable("else", options: .notTrimmed) { value, _ in
            guard let content = value as? String, !content.contains(tagPrefix + " else " + tagSuffix) else { return nil }
            return content
        }, CloseKeyword(tagPrefix + " endif " + tagSuffix)]) { variables, _, _ in
            guard let condition = variables["condition"] as? Bool, let body = variables["body"] as? String else { return nil }
            if condition {
                return body
            } else {
                return variables["else"] as? String
            }
        }
    }

    public static var printStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword("{{"), Variable<Any>("body"), CloseKeyword("}}")]) { variables, interpreter, _ in
            guard let body = variables["body"] else { return nil }
            return interpreter.typedInterpreter.print(body)
        }
    }

    public static var forInStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " for"),
                        GenericVariable<String, StringTemplateInterpreter>("variable", options: .notInterpreted), Keyword("in"),
                        Variable<[Any]>("items"),
                        Keyword(tagSuffix),
                        GenericVariable<String, StringTemplateInterpreter>("body", options: [.notInterpreted, .notTrimmed]),
                        CloseKeyword(tagPrefix + " endfor " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String,
                let items = variables["items"] as? [Any],
                let body = variables["body"] as? String else { return nil }
            var result = ""
            context.push()
            context.variables["__loop"] = items
            for (index, item) in items.enumerated() {
                context.variables["__first"] = index == items.startIndex
                context.variables["__last"] = index == items.index(before: items.endIndex)
                context.variables[variableName] = item
                result += interpreter.evaluate(body, context: context)
            }
            context.pop()
            return result
        }
    }

    public static var setStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword(tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endset " + tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String, let body = variables["body"] as? String else { return nil }
            interpreter.context.variables[variableName] = body
            return ""
        }
    }

    public static var setUsingBodyStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword("="), Variable<Any>("value"), CloseKeyword(tagSuffix)]) { variables, interpreter, context in
            guard let variableName = variables["variable"] as? String else { return nil }
            interpreter.context.variables[variableName] = variables["value"]
            return ""
        }
    }

    public static var blockStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " block"),
                        GenericVariable<String, StringTemplateInterpreter>("name", options: .notInterpreted),
                        Keyword(tagSuffix),
                        GenericVariable<String, StringTemplateInterpreter>("body", options: .notInterpreted),
                        CloseKeyword(tagPrefix + " endblock " + tagSuffix)]) { variables, interpreter, localContext in
            guard let name = variables["name"] as? String, let body = variables["body"] as? String else { return nil }
            let block: BlockRenderer = { context in
                context.push()
                context.merge(with: localContext) { existing, _ in existing }
                context.variables["__block"] = name
                if let last = context.blocks[name] {
                    context.blocks[name] = Array(last.dropLast())
                }
                let result = interpreter.evaluate(body, context: context)
                context.pop()
                return result
            }
            if let last = interpreter.context.blocks[name] {
                interpreter.context.blocks[name] = last + [block]
                return ""
            } else {
                interpreter.context.blocks[name] = [block]
                return "{{{\(name)}}}"
            }
        }
    }

    public static var macroStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " macro"), GenericVariable<String, StringTemplateInterpreter>("name", options: .notInterpreted), Keyword("("), GenericVariable<[String], StringTemplateInterpreter>("arguments", options: .notInterpreted) { arguments, _ in
                guard let arguments = arguments as? String else { return nil }
                return arguments.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }, Keyword(")"), Keyword(tagSuffix), GenericVariable<String, StringTemplateInterpreter>("body", options: .notInterpreted), CloseKeyword(tagPrefix + " endmacro " + tagSuffix)]) { variables, interpreter, context in
            guard let name = variables["name"] as? String,
                let arguments = variables["arguments"] as? [String],
                let body = variables["body"] as? String else { return nil }
            interpreter.context.macros[name] = (arguments: arguments, body: body)
            return ""
        }
    }

    public static var commentStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword("{#"), GenericVariable<String, StringTemplateInterpreter>("body", options: .notInterpreted), CloseKeyword("#}")]) { _, _, _ in "" }
    }

    public static var importStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " import"), Variable<String>("file"), CloseKeyword(tagSuffix)]) { variables, interpreter, context in
            guard let file = variables["file"] as? String,
                let url = Bundle.allBundles.compactMap({ $0.url(forResource: file, withExtension: nil) }).first,
                let expression = try? String(contentsOf: url) else { return nil }
            return interpreter.evaluate(expression, context: context)
        }
    }

    public static var spacelessStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " spaceless " + tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endspaceless " + tagSuffix)]) { variables, _, _ in
            guard let body = variables["body"] as? String else { return nil }
            return body.self.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined()
        }
    }
}

// swiftlint:disable:next type_body_length
public class StandardLibrary {
    public static var dataTypes: [DataTypeProtocol] {
        return [
            stringType,
            booleanType,
            arrayType,
            dictionaryType,
            dateType,
            numericType,
            emptyType
        ]
    }
    public static var functions: [FunctionProtocol] {
        return [
            parentheses,
            macro,
            blockParent,
            ternaryOperator,

            rangeFunction,
            rangeOfStringFunction,
            rangeBySteps,

            loopIsFirst,
            loopIsLast,
            loopIsNotFirst,
            loopIsNotLast,

            startsWithOperator,
            endsWithOperator,
            containsOperator,
            matchesOperator,
            capitalise,
            lowercase,
            uppercase,
            lowercaseFirst,
            uppercaseFirst,
            trim,
            urlEncode,
            urlDecode,
            escape,
            nl2br,

            stringConcatenationOperator,

            multiplicationOperator,
            divisionOperator,
            additionOperator,
            subtractionOperator,
            moduloOperator,
            powOperator,

            lessThanOperator,
            lessThanOrEqualsOperator,
            moreThanOperator,
            moreThanOrEqualsOperator,
            equalsOperator,
            notEqualsOperator,

            stringEqualsOperator,
            stringNotEqualsOperator,

            inNumericArrayOperator,
            inStringArrayOperator,

            incrementOperator,
            decrementOperator,

            negationOperator,
            notOperator,
            orOperator,
            andOperator,

            absoluteValue,
            defaultValue,

            isEvenOperator,
            isOddOperator,

            minFunction,
            maxFunction,
            sumFunction,
            sqrtFunction,
            roundFunction,
            averageFunction,

            arraySubscript,
            arrayCountFunction,
            arrayMapFunction,
            arrayFilterFunction,
            arraySortFunction,
            arrayReverseFunction,
            arrayMinFunction,
            arrayMaxFunction,
            arrayFirstFunction,
            arrayLastFunction,
            arrayJoinFunction,
            arraySplitFunction,
            arrayMergeFunction,
            arraySumFunction,
            arrayAverageFunction,

            dictionarySubscript,
            dictionaryCountFunction,
            dictionaryFilterFunction,
            dictionaryKeys,
            dictionaryValues,

            dateFactory,
            dateFormat,

            stringFactory
        ]
    }

    // MARK: Types

    public static var numericType: DataType<Double> {
        let numberLiteral = Literal { value, _ in Double(value) }
        let piLiteral = Literal("pi", convertsTo: Double.pi)
        return DataType(type: Double.self, literals: [numberLiteral, piLiteral]) { value, _ in String(format: "%g", value) }
    }

    public static var stringType: DataType<String> {
        let singleQuotesLiteral = literal(opening: "'", closing: "'") { input, _ in input }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { value, _ in value }
    }

    public static var dateType: DataType<Date> {
        let dateFormatter = DateFormatter(with: "yyyy-MM-dd HH:mm:ss")
        let now = Literal<Date>("now", convertsTo: Date())
        return DataType(type: Date.self, literals: [now]) { value, _ in dateFormatter.string(from: value) }
    }

    public static var arrayType: DataType<[CustomStringConvertible]> {
        let arrayLiteral = literal(opening: "[", closing: "]") { input, interpreter -> [CustomStringConvertible]? in
            return input
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        return DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { value, printer in value.map { printer.print($0) }.joined(separator: ",") }
    }

    public static var dictionaryType: DataType<[String: CustomStringConvertible?]> {
        let dictionaryLiteral = literal(opening: "{", closing: "}") { input, interpreter -> [String: CustomStringConvertible?]? in
            let values = input
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let parsedValues : [(key: String, value: CustomStringConvertible?)] = values
                .map { $0.split(separator: ":").map { interpreter.evaluate(String($0)) } }
                .compactMap {
                    guard let first = $0.first, let key = first as? String, let value = $0.last else { return nil }
                    return (key: key, value: value as? CustomStringConvertible)
                }
            return Dictionary(grouping: parsedValues) { $0.key }.mapValues { $0.first?.value }
        }
        return DataType(type: [String: CustomStringConvertible?].self, literals: [dictionaryLiteral]) { value, printer in
            let items = value.map { key, value in
                if let value = value {
                    return "\(printer.print(key)): \(printer.print(value))"
                } else {
                    return "\(printer.print(key)): nil"
                }
            }.sorted().joined(separator: ", ")
            return "[\(items)]"
        }
    }

    public static var booleanType: DataType<Bool> {
        let trueLiteral = Literal("true", convertsTo: true)
        let falseLiteral = Literal("false", convertsTo: false)
        return DataType(type: Bool.self, literals: [trueLiteral, falseLiteral]) { value, _ in value ? "true" : "false" }
    }

    public static var emptyType: DataType<Any?> {
        let nullLiteral = Literal<Any?>("null", convertsTo: nil)
        let nilLiteral = Literal<Any?>("nil", convertsTo: nil)
        return DataType(type: Any?.self, literals: [nullLiteral, nilLiteral]) { _, _ in "null" }
    }

    // MARK: Functions

    public static var parentheses: Function<Any> {
        return Function([OpenKeyword("("), Variable<Any>("body"), CloseKeyword(")")]) { arguments, _, _ in arguments["body"] }
    }

    public static var macro: Function<Any> {
        return Function([Variable<String>("name", options: .notInterpreted) { value, interpreter in
            guard let value = value as? String else { return nil }
            return interpreter.context.macros.keys.contains(value) ? value : nil
        }, OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { variables, interpreter, context in
            guard let arguments = variables["arguments"] as? String,
                let name = variables["name"] as? String,
                let macro = interpreter.context.macros[name.trimmingCharacters(in: .whitespacesAndNewlines)] else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            context.push()
            for (key, value) in zip(macro.arguments, interpretedArguments) {
                context.variables[key] = value
            }
            let result = interpreter.evaluate(macro.body, context: context)
            context.pop()
            return result
        }
    }

    public static var blockParent: Function<Any> {
        return Function([Keyword("parent"), OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { variables, interpreter, context in
            guard let arguments = variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = interpreter.evaluate(String(value))
                }
            }
            guard let name = context.variables["__block"] as? String, let block = context.blocks[name]?.last else { return nil }
            context.push()
            context.variables.merge(interpretedArguments) { _, new in new }
            let result = block(context)
            context.pop()
            return result
        }
    }

    public static var ternaryOperator: Function<Any> {
        return Function([Variable<Bool>("condition"), Keyword("?"), Variable<Any>("body"), Keyword(": "), Variable<Any>("else")]) { arguments, _, _ in
            guard let condition = arguments["condition"] as? Bool else { return nil }
            return condition ? arguments["body"] : arguments["else"]
        }
    }

    public static var rangeFunction: Function<[Double]> {
        return infixOperator("...") { (lhs: Double, rhs: Double) in
            CountableClosedRange(uncheckedBounds: (lower: Int(lhs), upper: Int(rhs))).map { Double($0) }
        }
    }

    public static var rangeOfStringFunction: Function<[String]> {
        return infixOperator("...") { (lhs: String, rhs: String) in
            CountableClosedRange(uncheckedBounds: (lower: Character(lhs), upper: Character(rhs))).map { String($0) }
        }
    }

    public static var startsWithOperator: Function<Bool> {
        return infixOperator("starts with") { (lhs: String, rhs: String) in lhs.hasPrefix(rhs) }
    }

    public static var endsWithOperator: Function<Bool> {
        return infixOperator("ends with") { (lhs: String, rhs: String) in lhs.hasSuffix(rhs) }
    }

    public static var containsOperator: Function<Bool> {
        return infixOperator("contains") { (lhs: String, rhs: String) in lhs.contains(rhs) }
    }

    public static var matchesOperator: Function<Bool> {
        return infixOperator("matches") { (lhs: String, rhs: String) in
            if let regex = try? NSRegularExpression(pattern: rhs) {
                let matches = regex.numberOfMatches(in: lhs, range: NSRange(lhs.startIndex..., in: lhs))
                return matches > 0
            }
            return false
        }
    }

    public static var capitalise: Function<String> {
        return objectFunction("capitalise") { (value: String) -> String? in value.capitalized }
    }

    public static var lowercase: Function<String> {
        return objectFunction("lower") { (value: String) -> String? in value.lowercased() }
    }

    public static var uppercase: Function<String> {
        return objectFunction("upper") { (value: String) -> String? in value.uppercased() }
    }

    public static var lowercaseFirst: Function<String> {
        return objectFunction("lowerFirst") { (value: String) -> String? in
            guard let first = value.first else { return nil }
            return String(first).lowercased() + value[value.index(value.startIndex, offsetBy: 1)...]
        }
    }

    public static var uppercaseFirst: Function<String> {
        return objectFunction("upperFirst") { (value: String) -> String? in
            guard let first = value.first else { return nil }
            return String(first).uppercased() + value[value.index(value.startIndex, offsetBy: 1)...]
        }
    }

    public static var trim: Function<String> {
        return objectFunction("trim") { (value: String) -> String? in value.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    public static var urlEncode: Function<String> {
        return objectFunction("urlEncode") { (value: String) -> String? in value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) }
    }

    public static var urlDecode: Function<String> {
        return objectFunction("urlDecode") { (value: String) -> String? in value.removingPercentEncoding }
    }

    public static var escape: Function<String> {
        return objectFunction("escape") { (value: String) -> String? in value.html }
    }

    public static var nl2br: Function<String> {
        return objectFunction("nl2br") { (value: String) -> String? in value
            .replacingOccurrences(of: "\r\n", with: "<br/>")
            .replacingOccurrences(of: "\n", with: "<br/>")
        }
    }

    public static var stringConcatenationOperator: Function<String> {
        return infixOperator("+") { (lhs: String, rhs: String) in lhs + rhs }
    }

    public static var additionOperator: Function<Double> {
        return infixOperator("+") { (lhs: Double, rhs: Double) in lhs + rhs }
    }

    public static var subtractionOperator: Function<Double> {
        return infixOperator("-") { (lhs: Double, rhs: Double) in lhs - rhs }
    }

    public static var multiplicationOperator: Function<Double> {
        return infixOperator("*") { (lhs: Double, rhs: Double) in lhs * rhs }
    }

    public static var divisionOperator: Function<Double> {
        return infixOperator("/") { (lhs: Double, rhs: Double) in lhs / rhs }
    }

    public static var moduloOperator: Function<Double> {
        return infixOperator("%") { (lhs: Double, rhs: Double) in Double(Int(lhs) % Int(rhs)) }
    }

    public static var powOperator: Function<Double> {
        return infixOperator("**") { (lhs: Double, rhs: Double) in pow(lhs, rhs) }
    }

    public static var lessThanOperator: Function<Bool> {
        return infixOperator("<") { (lhs: Double, rhs: Double) in lhs < rhs }
    }

    public static var moreThanOperator: Function<Bool> {
        return infixOperator("<=") { (lhs: Double, rhs: Double) in lhs <= rhs }
    }

    public static var lessThanOrEqualsOperator: Function<Bool> {
        return infixOperator(">") { (lhs: Double, rhs: Double) in lhs > rhs }
    }

    public static var moreThanOrEqualsOperator: Function<Bool> {
        return infixOperator(">=") { (lhs: Double, rhs: Double) in lhs >= rhs }
    }

    public static var equalsOperator: Function<Bool> {
        return infixOperator("==") { (lhs: Double, rhs: Double) in lhs == rhs }
    }

    public static var notEqualsOperator: Function<Bool> {
        return infixOperator("!=") { (lhs: Double, rhs: Double) in lhs != rhs }
    }

    public static var stringEqualsOperator: Function<Bool> {
        return infixOperator("==") { (lhs: String, rhs: String) in lhs == rhs }
    }

    public static var stringNotEqualsOperator: Function<Bool> {
        return infixOperator("!=") { (lhs: String, rhs: String) in lhs != rhs }
    }

    public static var inStringArrayOperator: Function<Bool> {
        return infixOperator("in") { (lhs: String, rhs: [String]) in rhs.contains(lhs) }
    }

    public static var inNumericArrayOperator: Function<Bool> {
        return infixOperator("in") { (lhs: Double, rhs: [Double]) in rhs.contains(lhs) }
    }

    public static var negationOperator: Function<Bool> {
        return prefixOperator("!") { (expression: Bool) in !expression }
    }

    public static var notOperator: Function<Bool> {
        return prefixOperator("not") { (expression: Bool) in !expression }
    }

    public static var andOperator: Function<Bool> {
        return infixOperator("and") { (lhs: Bool, rhs: Bool) in lhs && rhs }
    }

    public static var orOperator: Function<Bool> {
        return infixOperator("or") { (lhs: Bool, rhs: Bool) in lhs || rhs }
    }

    public static var absoluteValue: Function<Double> {
        return objectFunction("abs") { (value: Double) -> Double? in abs(value) }
    }

    public static var defaultValue: Function<Any> {
        return Function([Variable<Any>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == "default" else { return nil }
            return value
        }, Keyword("("), Variable<Any>("fallback"), Keyword(")")], options: .backwardMatch) { variables, _, _ in
            guard let value = variables["lhs"], variables["rhs"] != nil else { return nil }
            return isNilOrWrappedNil(value: value) ? variables["fallback"] : value
        }
    }

    public static var incrementOperator: Function<Double> {
        return suffixOperator("++") { (expression: Double) in expression + 1 }
    }

    public static var decrementOperator: Function<Double> {
        return suffixOperator("--") { (expression: Double) in expression - 1 }
    }

    public static var isEvenOperator: Function<Bool> {
        return suffixOperator("is even") { (expression: Double) in Int(expression) % 2 == 0 }
    }

    public static var isOddOperator: Function<Bool> {
        return suffixOperator("is odd") { (expression: Double) in abs(Int(expression) % 2) == 1 }
    }

    public static var minFunction: Function<Double> {
        return function("min") { (arguments: [Any]) -> Double? in
            guard let arguments = arguments as? [Double] else { return nil }
            return arguments.min()
        }
    }

    public static var maxFunction: Function<Double> {
        return function("max") { (arguments: [Any]) -> Double? in
            guard let arguments = arguments as? [Double] else { return nil }
            return arguments.max()
        }
    }

    public static var arraySortFunction: Function<[Double]> {
        return objectFunction("sort") { (object: [Double]) -> [Double]? in object.sorted() }
    }

    public static var arrayReverseFunction: Function<[Double]> {
        return objectFunction("reverse") { (object: [Double]) -> [Double]? in object.reversed() }
    }

    public static var arrayMinFunction: Function<Double> {
        return objectFunction("min") { (object: [Double]) -> Double? in object.min() }
    }

    public static var arrayMaxFunction: Function<Double> {
        return objectFunction("max") { (object: [Double]) -> Double? in object.max() }
    }

    public static var arrayFirstFunction: Function<Double> {
        return objectFunction("first") { (object: [Double]) -> Double? in object.first }
    }

    public static var arrayLastFunction: Function<Double> {
        return objectFunction("last") { (object: [Double]) -> Double? in object.last }
    }

    public static var arrayJoinFunction: Function<String> {
        return objectFunctionWithParameters("join") { (object: [String], arguments: [Any]) -> String? in
            guard let separator = arguments.first as? String else { return nil }
            return object.joined(separator: separator)
        }
    }

    public static var arraySplitFunction: Function<[String]> {
        return Function([Variable<String>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == "split" else { return nil }
            return value
        }, Keyword("("), Variable<String>("separator"), Keyword(")")]) { variables, _, _ in
            guard let object = variables["lhs"] as? String, variables["rhs"] != nil, let separator = variables["separator"] as? String else { return nil }
            return object.split(separator: Character(separator)).map { String($0) }
        }
    }

    public static var arrayMergeFunction: Function<[Any]> {
        return Function([Variable<[Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == "merge" else { return nil }
            return value
        }, Keyword("("), Variable<[Any]>("other"), Keyword(")")]) { variables, _, _ in
            guard let object = variables["lhs"] as? [Any], variables["rhs"] != nil, let other = variables["other"] as? [Any] else { return nil }
            return object + other
        }
    }

    public static var arraySumFunction: Function<Double> {
        return objectFunction("sum") { (object: [Double]) -> Double? in object.reduce(0, +) }
    }

    public static var arrayAverageFunction: Function<Double> {
        return objectFunction("avg") { (object: [Double]) -> Double? in object.reduce(0, +) / Double(object.count) }
    }

    public static var arrayCountFunction: Function<Double> {
        return objectFunction("count") { (object: [Double]) -> Double? in Double(object.count) }
    }

    public static var dictionaryCountFunction: Function<Double> {
        return objectFunction("count") { (object: [String: Any]) -> Double? in Double(object.count) }
    }

    public static var arrayMapFunction: Function<[Any]> {
        return Function([Variable<[Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == "map" else { return nil }
            return value
        }, Keyword("("), Variable<String>("variable", options: .notInterpreted), Keyword("=>"), Variable<Any>("body", options: .notInterpreted), Keyword(")")]) { variables, interpreter, context in
            guard let object = variables["lhs"] as? [Any], variables["rhs"] != nil,
                let variable = variables["variable"] as? String,
                let body = variables["body"] as? String else { return nil }
            context.push()
            let result: [Any] = object.compactMap { item in
                context.variables[variable] = item
                return interpreter.evaluate(body, context: context)
            }
            context.pop()
            return result
        }
    }

    public static var arrayFilterFunction: Function<[Any]> {
        return Function([Variable<[Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == "filter" else { return nil }
            return value
        }, Keyword("("), Variable<String>("variable", options: .notInterpreted), Keyword("=>"), Variable<Any>("body", options: .notInterpreted), Keyword(")")]) { variables, interpreter, context in
            guard let object = variables["lhs"] as? [Any], variables["rhs"] != nil,
                let variable = variables["variable"] as? String,
                let body = variables["body"] as? String else { return nil }
            context.push()
            let result: [Any] = object.filter { item in
                context.variables[variable] = item
                if let result = interpreter.evaluate(body, context: context) as? Bool {
                    return result
                }
                return false
            }
            context.pop()
            return result
        }
    }

    public static var dictionaryFilterFunction: Function<[String: Any]> {
        return Function([Variable<[String: Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == "filter" else { return nil }
            return value
        }, Keyword("("), Variable<String>("key", options: .notInterpreted), Keyword(","), Variable<String>("value", options: .notInterpreted), Keyword("=>"), Variable<Any>("body", options: .notInterpreted), Keyword(")")]) { variables, interpreter, context in
                guard let object = variables["lhs"] as? [String: Any], variables["rhs"] != nil,
                    let keyVariable = variables["key"] as? String,
                    let valueVariable = variables["value"] as? String,
                    let body = variables["body"] as? String else { return nil }
                context.push()
                let result: [String: Any] = object.filter { key, value in
                    context.variables[keyVariable] = key
                    context.variables[valueVariable] = value
                    if let result = interpreter.evaluate(body, context: context) as? Bool {
                        return result
                    }
                    return false
                }
                context.pop()
                return result
        }
    }

    public static var sumFunction: Function<Double> {
        return function("sum") { (arguments: [Any]) -> Double? in
            guard let arguments = arguments as? [Double] else { return nil }
            return arguments.reduce(0, +)
        }
    }

    public static var averageFunction: Function<Double> {
        return function("avg") { (arguments: [Any]) -> Double? in
            guard let arguments = arguments as? [Double] else { return nil }
            return arguments.reduce(0, +) / Double(arguments.count)
        }
    }

    public static var sqrtFunction: Function<Double> {
        return function("sqrt") { (arguments: [Any]) -> Double? in
            guard let value = arguments.first as? Double else { return nil }
            return sqrt(value)
        }
    }

    public static var roundFunction: Function<Double> {
        return function("round") { (arguments: [Any]) -> Double? in
            guard let value = arguments.first as? Double else { return nil }
            return round(value)
        }
    }

    public static var dateFactory: Function<Date?> {
        return function("Date") { (arguments: [Any]) -> Date? in
            guard let arguments = arguments as? [Double], arguments.count >= 3 else { return nil }
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.year = Int(arguments[0])
            components.month = Int(arguments[1])
            components.day = Int(arguments[2])
            components.hour = arguments.count > 3 ? Int(arguments[3]) : 0
            components.minute = arguments.count > 4 ? Int(arguments[4]) : 0
            components.second = arguments.count > 5 ? Int(arguments[5]) : 0
            return components.date
        }
    }

    public static var stringFactory: Function<String?> {
        return function("String") { (arguments: [Any]) -> String? in
            guard let argument = arguments.first as? Double else { return nil }
            return String(format: "%g", argument)
        }
    }

    public static var rangeBySteps: Function<[Double]> {
        return functionWithNamedParameters("range") { (arguments: [String: Any]) -> [Double]? in
            guard let start = arguments["start"] as? Double, let end = arguments["end"] as? Double, let step = arguments["step"] as? Double else { return nil }
            var result = [start]
            var value = start
            while value <= end - step {
                value += step
                result.append(value)
            }
            return result
        }
    }

    public static var loopIsFirst: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is first")]) { _, _, context in
            return context.variables["__first"] as? Bool
        }
    }

    public static var loopIsLast: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is last")]) { _, _, context in
            return context.variables["__last"] as? Bool
        }
    }

    public static var loopIsNotFirst: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is not first")]) { _, _, context in
            guard let isFirst = context.variables["__first"] as? Bool else { return nil }
            return !isFirst
        }
    }

    public static var loopIsNotLast: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is not last")]) { _, _, context in
            guard let isLast = context.variables["__last"] as? Bool else { return nil }
            return !isLast
        }
    }

    public static var dateFormat: Function<String> {
        return objectFunctionWithParameters("format") { (object: Date, arguments: [Any]) -> String? in
            guard let format = arguments.first as? String else { return nil }
            let dateFormatter = DateFormatter(with: format)
            return dateFormatter.string(from: object)
        }
    }

    public static var arraySubscript: Function<Any?> {
        return Function([Variable<[Any]>("array"), Keyword("."), Variable<Double>("index")]) { variables, _, _ in
            guard let array = variables["array"] as? [Any], let index = variables["index"] as? Double, index > 0, Int(index) < array.count else { return nil }
            return array[Int(index)]
        }
    }

    public static var dictionarySubscript: Function<Any?> {
        return Function([Variable<[String: Any]>("dictionary"), Keyword("."), Variable<String>("key", options: .notInterpreted)]) { variables, _, _ in
            guard let dictionary = variables["dictionary"] as? [String: Any], let key = variables["key"] as? String else { return nil }
            return dictionary[key]
        }
    }

    public static var dictionaryKeys: Function<[String]> {
        return objectFunction("keys") { (object: [String: Any?]) -> [String] in
            return object.keys.sorted()
        }
    }

    public static var dictionaryValues: Function<[Any?]> {
        return objectFunction("values") { (object: [String: Any?]) -> [Any?] in
            if let values = object as? [String: Double] {
                return values.values.sorted()
            }
            if let values = object as? [String: String] {
                return values.values.sorted()
            }
            return Array(object.values)
        }
    }

    public static var methodCallWithIntResult: Function<Double> {
        return Function([Variable<Any>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted)]) { arguments, _, _ -> Double? in
            if let lhs = arguments["lhs"] as? NSObjectProtocol,
                let rhs = arguments["rhs"] as? String,
                let result = lhs.perform(Selector(rhs)) {
                return Double(Int(bitPattern: result.toOpaque()))
            }
            return nil
        }
    }

    // MARK: Literal helpers

    public static func literal<T>(opening: String, closing: String, convert: @escaping (_ input: String, _ interpreter: TypedInterpreter) -> T?) -> Literal<T> {
        return Literal { input, interpreter -> T? in
            guard input.hasPrefix(opening), input.hasSuffix(closing), input.count > 1 else { return nil }
            let inputWithoutOpening = String(input.suffix(from: input.index(input.startIndex, offsetBy: opening.count)))
            let inputWithoutSides = String(inputWithoutOpening.prefix(upTo: inputWithoutOpening.index(inputWithoutOpening.endIndex, offsetBy: -closing.count)))
            guard !inputWithoutSides.contains(opening) && !inputWithoutSides.contains(closing) else { return nil }
            return convert(inputWithoutSides, interpreter)
        }
    }

    // MARK: Operator helpers

    public static func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")], options: .backwardMatch) { arguments, _, _ in
            guard let lhs = arguments["lhs"] as? A, let rhs = arguments["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }

    public static func prefixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T> {
        return Function([Keyword(symbol), Variable<A>("value")]) { arguments, _, _ in
            guard let value = arguments["value"] as? A else { return nil }
            return body(value)
        }
    }

    public static func suffixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T> {
        return Function([Variable<A>("value"), Keyword(symbol)]) { arguments, _, _ in
            guard let value = arguments["value"] as? A else { return nil }
            return body(value)
        }
    }

    // MARK: Function helpers

    public static func function<T>(_ name: String, body: @escaping ([Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { variables, interpreter, _ in
            guard let arguments = variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return body(interpretedArguments)
        }
    }

    public static func functionWithNamedParameters<T>(_ name: String, body: @escaping ([String: Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { variables, interpreter, _ in
            guard let arguments = variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = interpreter.evaluate(String(value))
                }
            }
            return body(interpretedArguments)
        }
    }

    public static func objectFunction<O, T>(_ name: String, body: @escaping (O) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }], options: .backwardMatch) { variables, _, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil else { return nil }
            return body(object)
        }
    }

    public static func objectFunctionWithParameters<O, T>(_ name: String, body: @escaping (O, [Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }, Keyword("("), Variable<String>("arguments", options: .notInterpreted), Keyword(")")]) { variables, interpreter, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil, let arguments = variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return body(object, interpretedArguments)
        }
    }

    public static func objectFunctionWithNamedParameters<O, T>(_ name: String, body: @escaping (O, [String: Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) { value, _ in
            guard let value = value as? String, value == name else { return nil }
            return value
        }, OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { variables, interpreter, _ in
            guard let object = variables["lhs"] as? O, variables["rhs"] != nil, let arguments = variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = interpreter.evaluate(String(value))
                }
            }
            return body(object, interpretedArguments)
        }
    }
}

public extension DateFormatter {
    convenience init(with format: String) {
        self.init()
        self.calendar = Calendar(identifier: .gregorian)
        self.dateFormat = format
    }
}

extension Character: Strideable {
    public typealias Stride = Int

    var value: UInt32 {
        return unicodeScalars.first?.value ?? 0
    }

    public func distance(to other: Character) -> Int {
        return Int(other.value) - Int(self.value)
    }

    public func advanced(by offset: Int) -> Character {
        let advancedValue = offset + Int(self.value)
        guard let advancedScalar = UnicodeScalar(advancedValue) else {
            fatalError("\(String(advancedValue, radix: 16)) does not represent a valid unicode scalar value.")
        }
        return Character(advancedScalar)
    }
}

extension String {
    static let enc: [Character: String] =
        [" ": "&emsp;", " ": "&ensp;", " ": "&nbsp;", " ": "&thinsp;", "‾": "&oline;", "–": "&ndash;", "—": "&mdash;",
         "¡": "&iexcl;", "¿": "&iquest;", "…": "&hellip;", "·": "&middot;", "'": "&apos;", "‘": "&lsquo;", "’": "&rsquo;",
         "‚": "&sbquo;", "‹": "&lsaquo;", "›": "&rsaquo;", "‎": "&lrm;", "‏": "&rlm;", "­": "&shy;", "‍": "&zwj;", "‌": "&zwnj;",
         "\"": "&quot;", "“": "&ldquo;", "”": "&rdquo;", "„": "&bdquo;", "«": "&laquo;", "»": "&raquo;", "⌈": "&lceil;",
         "⌉": "&rceil;", "⌊": "&lfloor;", "⌋": "&rfloor;", "〈": "&lang;", "〉": "&rang;", "§": "&sect;", "¶": "&para;",
         "&": "&amp;", "‰": "&permil;", "†": "&dagger;", "‡": "&Dagger;", "•": "&bull;", "′": "&prime;", "″": "&Prime;",
         "´": "&acute;", "˜": "&tilde;", "¯": "&macr;", "¨": "&uml;", "¸": "&cedil;", "ˆ": "&circ;", "°": "&deg;",
         "©": "&copy;", "®": "&reg;", "℘": "&weierp;", "←": "&larr;", "→": "&rarr;", "↑": "&uarr;", "↓": "&darr;",
         "↔": "&harr;", "↵": "&crarr;", "⇐": "&lArr;", "⇑": "&uArr;", "⇒": "&rArr;", "⇓": "&dArr;", "⇔": "&hArr;",
         "∀": "&forall;", "∂": "&part;", "∃": "&exist;", "∅": "&empty;", "∇": "&nabla;", "∈": "&isin;", "∉": "&notin;",
         "∋": "&ni;", "∏": "&prod;", "∑": "&sum;", "±": "&plusmn;", "÷": "&divide;", "×": "&times;", "<": "&lt;", "≠": "&ne;",
         ">": "&gt;", "¬": "&not;", "¦": "&brvbar;", "−": "&minus;", "⁄": "&frasl;", "∗": "&lowast;", "√": "&radic;",
         "∝": "&prop;", "∞": "&infin;", "∠": "&ang;", "∧": "&and;", "∨": "&or;", "∩": "&cap;", "∪": "&cup;", "∫": "&int;",
         "∴": "&there4;", "∼": "&sim;", "≅": "&cong;", "≈": "&asymp;", "≡": "&equiv;", "≤": "&le;", "≥": "&ge;", "⊄": "&nsub;",
         "⊂": "&sub;", "⊃": "&sup;", "⊆": "&sube;", "⊇": "&supe;", "⊕": "&oplus;", "⊗": "&otimes;", "⊥": "&perp;",
         "⋅": "&sdot;", "◊": "&loz;", "♠": "&spades;", "♣": "&clubs;", "♥": "&hearts;", "♦": "&diams;", "¤": "&curren;",
         "¢": "&cent;", "£": "&pound;", "¥": "&yen;", "€": "&euro;", "¹": "&sup1;", "½": "&frac12;", "¼": "&frac14;",
         "²": "&sup2;", "³": "&sup3;", "¾": "&frac34;", "á": "&aacute;", "Á": "&Aacute;", "â": "&acirc;", "Â": "&Acirc;",
         "à": "&agrave;", "À": "&Agrave;", "å": "&aring;", "Å": "&Aring;", "ã": "&atilde;", "Ã": "&Atilde;", "ä": "&auml;",
         "Ä": "&Auml;", "ª": "&ordf;", "æ": "&aelig;", "Æ": "&AElig;", "ç": "&ccedil;", "Ç": "&Ccedil;", "ð": "&eth;",
         "Ð": "&ETH;", "é": "&eacute;", "É": "&Eacute;", "ê": "&ecirc;", "Ê": "&Ecirc;", "è": "&egrave;", "È": "&Egrave;",
         "ë": "&euml;", "Ë": "&Euml;", "ƒ": "&fnof;", "í": "&iacute;", "Í": "&Iacute;", "î": "&icirc;", "Î": "&Icirc;",
         "ì": "&igrave;", "Ì": "&Igrave;", "ℑ": "&image;", "ï": "&iuml;", "Ï": "&Iuml;", "ñ": "&ntilde;", "Ñ": "&Ntilde;",
         "ó": "&oacute;", "Ó": "&Oacute;", "ô": "&ocirc;", "Ô": "&Ocirc;", "ò": "&ograve;", "Ò": "&Ograve;", "º": "&ordm;",
         "ø": "&oslash;", "Ø": "&Oslash;", "õ": "&otilde;", "Õ": "&Otilde;", "ö": "&ouml;", "Ö": "&Ouml;", "œ": "&oelig;", "Œ": "&OElig;", "ℜ": "&real;", "š": "&scaron;", "Š": "&Scaron;", "ß": "&szlig;", "™": "&trade;", "ú": "&uacute;",
         "Ú": "&Uacute;", "û": "&ucirc;", "Û": "&Ucirc;", "ù": "&ugrave;", "Ù": "&Ugrave;", "ü": "&uuml;", "Ü": "&Uuml;",
         "ý": "&yacute;", "Ý": "&Yacute;", "ÿ": "&yuml;", "Ÿ": "&Yuml;", "þ": "&thorn;", "Þ": "&THORN;", "α": "&alpha;",
         "Α": "&Alpha;", "β": "&beta;", "Β": "&Beta;", "γ": "&gamma;", "Γ": "&Gamma;", "δ": "&delta;", "Δ": "&Delta;",
         "ε": "&epsilon;", "Ε": "&Epsilon;", "ζ": "&zeta;", "Ζ": "&Zeta;", "η": "&eta;", "Η": "&Eta;", "θ": "&theta;",
         "Θ": "&Theta;", "ϑ": "&thetasym;", "ι": "&iota;", "Ι": "&Iota;", "κ": "&kappa;", "Κ": "&Kappa;", "λ": "&lambda;",
         "Λ": "&Lambda;", "µ": "&micro;", "μ": "&mu;", "Μ": "&Mu;", "ν": "&nu;", "Ν": "&Nu;", "ξ": "&xi;", "Ξ": "&Xi;",
         "ο": "&omicron;", "Ο": "&Omicron;", "π": "&pi;", "Π": "&Pi;", "ϖ": "&piv;", "ρ": "&rho;", "Ρ": "&Rho;",
         "σ": "&sigma;", "Σ": "&Sigma;", "ς": "&sigmaf;", "τ": "&tau;", "Τ": "&Tau;", "ϒ": "&upsih;", "υ": "&upsilon;",
         "Υ": "&Upsilon;", "φ": "&phi;", "Φ": "&Phi;", "χ": "&chi;", "Χ": "&Chi;", "ψ": "&psi;", "Ψ": "&Psi;",
         "ω": "&omega;", "Ω": "&Omega;", "ℵ": "&alefsym;"]

    var html: String {
        var html = ""
        for character in self {
            if let entity = String.enc[character] {
                html.append(entity)
            } else {
                html.append(character)
            }
        }
        return html
    }
}

internal func isNilOrWrappedNil(value: Any) -> Bool {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        if let first = mirror.children.first {
            return isNilOrWrappedNil(value: first.value)
        } else {
            return true
        }
    }
    return false
}
// swiftlint:disable:this file_length
