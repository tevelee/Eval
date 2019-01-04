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

        let block = Pattern<String, TemplateInterpreter<String>>([OpenKeyword("{{{"), TemplateVariable("name", options: .notInterpreted), CloseKeyword("}}}")]) {
            guard let name = $0.variables["name"] as? String else { return nil }
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
        return Pattern([Keyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body", options: .notTrimmed) {
            guard let content = $0.value as? String, !content.contains(tagPrefix + " else " + tagSuffix) else { return nil }
            return content
        }, Keyword("{%"), Keyword("endif"), Keyword("%}")]) {
            guard let condition = $0.variables["condition"] as? Bool, let body = $0.variables["body"] as? String else { return nil }
            return condition ? body : ""
        }
    }

    public static var ifElseStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " if"), Variable<Bool>("condition"), Keyword(tagSuffix), TemplateVariable("body", options: .notTrimmed) {
            guard let content = $0.value as? String, !content.contains(tagPrefix + " else " + tagSuffix) else { return nil }
            return content
        }, Keyword(tagPrefix + " else " + tagSuffix), TemplateVariable("else", options: .notTrimmed) {
            guard let content = $0.value as? String, !content.contains(tagPrefix + " else " + tagSuffix) else { return nil }
            return content
        }, CloseKeyword(tagPrefix + " endif " + tagSuffix)]) {
            guard let condition = $0.variables["condition"] as? Bool, let body = $0.variables["body"] as? String else { return nil }
            return condition ? body : $0.variables["else"] as? String
        }
    }

    public static var printStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword("{{"), Variable<Any>("body"), CloseKeyword("}}")]) {
            guard let body = $0.variables["body"] else { return nil }
            return $0.interpreter.typedInterpreter.print(body)
        }
    }

    public static var forInStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " for"),
                        GenericVariable<String, StringTemplateInterpreter>("variable", options: .notInterpreted), Keyword("in"),
                        Variable<[Any]>("items"),
                        Keyword(tagSuffix),
                        GenericVariable<String, StringTemplateInterpreter>("body", options: [.notInterpreted, .notTrimmed]),
                        CloseKeyword(tagPrefix + " endfor " + tagSuffix)]) {
            guard let variableName = $0.variables["variable"] as? String,
                let items = $0.variables["items"] as? [Any],
                let body = $0.variables["body"] as? String else { return nil }
            var result = ""
            $0.context.push()
            $0.context.variables["__loop"] = items
            for (index, item) in items.enumerated() {
                $0.context.variables["__first"] = index == items.startIndex
                $0.context.variables["__last"] = index == items.index(before: items.endIndex)
                $0.context.variables[variableName] = item
                result += $0.interpreter.evaluate(body, context: $0.context)
            }
            $0.context.pop()
            return result
        }
    }

    public static var setStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword(tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endset " + tagSuffix)]) {
            guard let variableName = $0.variables["variable"] as? String, let body = $0.variables["body"] as? String else { return nil }
            $0.interpreter.context.variables[variableName] = body
            return ""
        }
    }

    public static var setUsingBodyStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " set"), TemplateVariable("variable"), Keyword("="), Variable<Any>("value"), CloseKeyword(tagSuffix)]) {
            guard let variableName = $0.variables["variable"] as? String else { return nil }
            $0.interpreter.context.variables[variableName] = $0.variables["value"]
            return ""
        }
    }

    public static var blockStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " block"),
                        GenericVariable<String, StringTemplateInterpreter>("name", options: .notInterpreted),
                        Keyword(tagSuffix),
                        GenericVariable<String, StringTemplateInterpreter>("body", options: .notInterpreted),
                        CloseKeyword(tagPrefix + " endblock " + tagSuffix)]) { match in
            guard let name = match.variables["name"] as? String, let body = match.variables["body"] as? String else { return nil }
            let block: BlockRenderer = { context in
                context.push()
                context.merge(with: match.context) { existing, _ in existing }
                context.variables["__block"] = name
                if let last = context.blocks[name] {
                    context.blocks[name] = Array(last.dropLast())
                }
                let result = match.interpreter.evaluate(body, context: context)
                context.pop()
                return result
            }
            if let last = match.interpreter.context.blocks[name] {
                match.interpreter.context.blocks[name] = last + [block]
                return ""
            } else {
                match.interpreter.context.blocks[name] = [block]
                return "{{{\(name)}}}"
            }
        }
    }

    public static var macroStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " macro"), GenericVariable<String, StringTemplateInterpreter>("name", options: .notInterpreted), Keyword("("), GenericVariable<[String], StringTemplateInterpreter>("arguments", options: .notInterpreted) {
                guard let arguments = $0.value as? String else { return nil }
                return arguments.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }, Keyword(")"), Keyword(tagSuffix), GenericVariable<String, StringTemplateInterpreter>("body", options: .notInterpreted), CloseKeyword(tagPrefix + " endmacro " + tagSuffix)]) {
            guard let name = $0.variables["name"] as? String,
                let arguments = $0.variables["arguments"] as? [String],
                let body = $0.variables["body"] as? String else { return nil }
            $0.interpreter.context.macros[name] = (arguments: arguments, body: body)
            return ""
        }
    }

    public static var commentStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword("{#"), GenericVariable<String, StringTemplateInterpreter>("body", options: .notInterpreted), CloseKeyword("#}")]) { _ in "" }
    }

    public static var importStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " import"), Variable<String>("file"), CloseKeyword(tagSuffix)]) {
            guard let file = $0.variables["file"] as? String,
                let url = Bundle.allBundles.compactMap({ $0.url(forResource: file, withExtension: nil) }).first,
                let expression = try? String(contentsOf: url) else { return nil }
            return $0.interpreter.evaluate(expression, context: $0.context)
        }
    }

    public static var spacelessStatement: Pattern<String, TemplateInterpreter<String>> {
        return Pattern([OpenKeyword(tagPrefix + " spaceless " + tagSuffix), TemplateVariable("body"), CloseKeyword(tagPrefix + " endspaceless " + tagSuffix)]) {
            guard let body = $0.variables["body"] as? String else { return nil }
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
        let numberLiteral = Literal { Double($0.value) }
        let piLiteral = Literal("pi", convertsTo: Double.pi)
        return DataType(type: Double.self, literals: [numberLiteral, piLiteral]) { String(format: "%g", $0.value) }
    }

    public static var stringType: DataType<String> {
        let singleQuotesLiteral = literal(opening: "'", closing: "'") { $0.value }
        return DataType(type: String.self, literals: [singleQuotesLiteral]) { $0.value }
    }

    public static var dateType: DataType<Date> {
        let dateFormatter = DateFormatter(with: "yyyy-MM-dd HH:mm:ss")
        let now = Literal<Date>("now", convertsTo: Date())
        return DataType(type: Date.self, literals: [now]) { dateFormatter.string(from: $0.value) }
    }

    public static var arrayType: DataType<[CustomStringConvertible]> {
        let arrayLiteral = literal(opening: "[", closing: "]") { literal -> [CustomStringConvertible]? in
            literal.value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { literal.interpreter.evaluate(String($0)) as? CustomStringConvertible ?? String($0) }
        }
        return DataType(type: [CustomStringConvertible].self, literals: [arrayLiteral]) { dataType in dataType.value.map { dataType.printer.print($0) }.joined(separator: ",") }
    }

    public static var dictionaryType: DataType<[String: CustomStringConvertible?]> {
        let dictionaryLiteral = literal(opening: "{", closing: "}") { body -> [String: CustomStringConvertible?]? in
            let values = body.value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let parsedValues : [(key: String, value: CustomStringConvertible?)] = values
                .map { $0.split(separator: ":").map { body.interpreter.evaluate(String($0)) } }
                .compactMap {
                    guard let first = $0.first, let key = first as? String, let value = $0.last else { return nil }
                    return (key: key, value: value as? CustomStringConvertible)
                }
            return Dictionary(grouping: parsedValues) { $0.key }.mapValues { $0.first?.value }
        }
        return DataType(type: [String: CustomStringConvertible?].self, literals: [dictionaryLiteral]) { dataType in
            let items = dataType.value.map { key, value in
                if let value = value {
                    return "\(dataType.printer.print(key)): \(dataType.printer.print(value))"
                } else {
                    return "\(dataType.printer.print(key)): nil"
                }
            }.sorted().joined(separator: ", ")
            return "[\(items)]"
        }
    }

    public static var booleanType: DataType<Bool> {
        let trueLiteral = Literal("true", convertsTo: true)
        let falseLiteral = Literal("false", convertsTo: false)
        return DataType(type: Bool.self, literals: [trueLiteral, falseLiteral]) { $0.value ? "true" : "false" }
    }

    public static var emptyType: DataType<Any?> {
        let nullLiteral = Literal<Any?>("null", convertsTo: nil)
        let nilLiteral = Literal<Any?>("nil", convertsTo: nil)
        return DataType<Any?>(type: Any?.self, literals: [nullLiteral, nilLiteral]) { _ in "null" }
    }

    // MARK: Functions

    public static var parentheses: Function<Double> {
        return Function([OpenKeyword("("), Variable<Double>("body"), CloseKeyword(")")]) { $0.variables["body"] as? Double }
    }

    public static var macro: Function<Any> {
        return Function([Variable<String>("name", options: .notInterpreted) {
            guard let value = $0.value as? String else { return nil }
            return $0.interpreter.context.macros.keys.contains(value) ? value : nil
        }, Keyword("("), Variable<String>("arguments", options: .notInterpreted), Keyword(")")]) { match in
            guard let arguments = match.variables["arguments"] as? String,
                let name = match.variables["name"] as? String,
                let macro = match.interpreter.context.macros[name.trimmingCharacters(in: .whitespacesAndNewlines)] else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { match.interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            match.context.push()
            for (key, value) in zip(macro.arguments, interpretedArguments) {
                match.context.variables[key] = value
            }
            let result = match.interpreter.evaluate(macro.body, context: match.context)
            match.context.pop()
            return result
        }
    }

    public static var blockParent: Function<Any> {
        return Function([Keyword("parent"), Keyword("("), Variable<String>("arguments", options: .notInterpreted), Keyword(")")]) {
            guard let arguments = $0.variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = $0.interpreter.evaluate(String(value))
                }
            }
            guard let name = $0.context.variables["__block"] as? String, let block = $0.context.blocks[name]?.last else { return nil }
            $0.context.push()
            $0.context.variables.merge(interpretedArguments) { _, new in new }
            let result = block($0.context)
            $0.context.pop()
            return result
        }
    }

    public static var ternaryOperator: Function<Any> {
        return Function([Variable<Bool>("condition"), Keyword("?"), Variable<Any>("body"), Keyword(": "), Variable<Any>("else")]) {
            guard let condition = $0.variables["condition"] as? Bool else { return nil }
            return condition ? $0.variables["body"] : $0.variables["else"]
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
        return Function([Variable<Any>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == "default" else { return nil }
            return value
        }, Keyword("("), Variable<Any>("fallback"), Keyword(")")], options: .backwardMatch) {
            guard let value = $0.variables["lhs"], $0.variables["rhs"] != nil else { return nil }
            return isNilOrWrappedNil(value: value) ? $0.variables["fallback"] : value
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
        return Function([Variable<String>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == "split" else { return nil }
            return value
        }, Keyword("("), Variable<String>("separator"), Keyword(")")]) {
            guard let object = $0.variables["lhs"] as? String, $0.variables["rhs"] != nil, let separator = $0.variables["separator"] as? String else { return nil }
            return object.split(separator: Character(separator)).map { String($0) }
        }
    }

    public static var arrayMergeFunction: Function<[Any]> {
        return Function([Variable<[Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == "merge" else { return nil }
            return value
        }, Keyword("("), Variable<[Any]>("other"), Keyword(")")]) {
            guard let object = $0.variables["lhs"] as? [Any], $0.variables["rhs"] != nil, let other = $0.variables["other"] as? [Any] else { return nil }
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
        return Function([Variable<[Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == "map" else { return nil }
            return value
        }, Keyword("("), Variable<String>("variable", options: .notInterpreted), Keyword("=>"), Variable<Any>("body", options: .notInterpreted), Keyword(")")]) { match in
            guard let object = match.variables["lhs"] as? [Any], match.variables["rhs"] != nil,
                let variable = match.variables["variable"] as? String,
                let body = match.variables["body"] as? String else { return nil }
            match.context.push()
            let result: [Any] = object.compactMap { item in
                match.context.variables[variable] = item
                return match.interpreter.evaluate(body, context: match.context)
            }
            match.context.pop()
            return result
        }
    }

    public static var arrayFilterFunction: Function<[Any]> {
        return Function([Variable<[Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == "filter" else { return nil }
            return value
        }, Keyword("("), Variable<String>("variable", options: .notInterpreted), Keyword("=>"), Variable<Any>("body", options: .notInterpreted), Keyword(")")]) { match in
            guard let object = match.variables["lhs"] as? [Any], match.variables["rhs"] != nil,
                let variable = match.variables["variable"] as? String,
                let body = match.variables["body"] as? String else { return nil }
            match.context.push()
            let result: [Any] = object.filter { item in
                match.context.variables[variable] = item
                if let result = match.interpreter.evaluate(body, context: match.context) as? Bool {
                    return result
                }
                return false
            }
            match.context.pop()
            return result
        }
    }

    public static var dictionaryFilterFunction: Function<[String: Any]> {
        return Function([Variable<[String: Any]>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == "filter" else { return nil }
            return value
        }, Keyword("("), Variable<String>("key", options: .notInterpreted), Keyword(","), Variable<String>("value", options: .notInterpreted), Keyword("=>"), Variable<Any>("body", options: .notInterpreted), Keyword(")")]) { match in
                guard let object = match.variables["lhs"] as? [String: Any], match.variables["rhs"] != nil,
                    let keyVariable = match.variables["key"] as? String,
                    let valueVariable = match.variables["value"] as? String,
                    let body = match.variables["body"] as? String else { return nil }
                match.context.push()
                let result: [String: Any] = object.filter { key, value in
                    match.context.variables[keyVariable] = key
                    match.context.variables[valueVariable] = value
                    if let result = match.interpreter.evaluate(body, context: match.context) as? Bool {
                        return result
                    }
                    return false
                }
                match.context.pop()
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
        return Function([Variable<Any>("value"), Keyword("is first")]) {
            $0.context.variables["__first"] as? Bool
        }
    }

    public static var loopIsLast: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is last")]) {
            $0.context.variables["__last"] as? Bool
        }
    }

    public static var loopIsNotFirst: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is not first")]) {
            guard let isFirst = $0.context.variables["__first"] as? Bool else { return nil }
            return !isFirst
        }
    }

    public static var loopIsNotLast: Function<Bool?> {
        return Function([Variable<Any>("value"), Keyword("is not last")]) {
            guard let isLast = $0.context.variables["__last"] as? Bool else { return nil }
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
        return Function([Variable<[Any]>("array"), Keyword("."), Variable<Double>("index")]) {
            guard let array = $0.variables["array"] as? [Any], let index = $0.variables["index"] as? Double, index > 0, Int(index) < array.count else { return nil }
            return array[Int(index)]
        }
    }

    public static var dictionarySubscript: Function<Any?> {
        return Function([Variable<[String: Any]>("dictionary"), Keyword("."), Variable<String>("key", options: .notInterpreted)]) {
            guard let dictionary = $0.variables["dictionary"] as? [String: Any], let key = $0.variables["key"] as? String else { return nil }
            return dictionary[key]
        }
    }

    public static var dictionaryKeys: Function<[String]> {
        return objectFunction("keys") { (object: [String: Any?]) -> [String] in
            object.keys.sorted()
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
        return Function([Variable<Any>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted)]) {
            if let lhs = $0.variables["lhs"] as? NSObjectProtocol,
                let rhs = $0.variables["rhs"] as? String,
                let result = lhs.perform(Selector(rhs)) {
                return Double(Int(bitPattern: result.toOpaque()))
            }
            return nil
        }
    }

    // MARK: Literal helpers

    public static func literal<T>(opening: String, closing: String, convert: @escaping (_ literal: LiteralBody) -> T?) -> Literal<T> {
        return Literal { literal -> T? in
            guard literal.value.hasPrefix(opening), literal.value.hasSuffix(closing), literal.value.count > 1 else { return nil }
            let inputWithoutOpening = String(literal.value.suffix(from: literal.value.index(literal.value.startIndex, offsetBy: opening.count)))
            let inputWithoutSides = String(inputWithoutOpening.prefix(upTo: inputWithoutOpening.index(inputWithoutOpening.endIndex, offsetBy: -closing.count)))
            guard !inputWithoutSides.contains(opening) && !inputWithoutSides.contains(closing) else { return nil }
            return convert(LiteralBody(value: inputWithoutSides, interpreter: literal.interpreter))
        }
    }

    // MARK: Operator helpers

    public static func infixOperator<A, B, T>(_ symbol: String, body: @escaping (A, B) -> T) -> Function<T> {
        return Function([Variable<A>("lhs"), Keyword(symbol), Variable<B>("rhs")], options: .backwardMatch) {
            guard let lhs = $0.variables["lhs"] as? A, let rhs = $0.variables["rhs"] as? B else { return nil }
            return body(lhs, rhs)
        }
    }

    public static func prefixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T> {
        return Function([Keyword(symbol), Variable<A>("value")]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }

    public static func suffixOperator<A, T>(_ symbol: String, body: @escaping (A) -> T) -> Function<T> {
        return Function([Variable<A>("value"), Keyword(symbol)]) {
            guard let value = $0.variables["value"] as? A else { return nil }
            return body(value)
        }
    }

    // MARK: Function helpers

    public static func function<T>(_ name: String, body: @escaping ([Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { match in
            guard let arguments = match.variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { match.interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return body(interpretedArguments)
        }
    }

    public static func functionWithNamedParameters<T>(_ name: String, body: @escaping ([String: Any]) -> T?) -> Function<T> {
        return Function([Keyword(name), OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) {
            guard let arguments = $0.variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = $0.interpreter.evaluate(String(value))
                }
            }
            return body(interpretedArguments)
        }
    }

    public static func objectFunction<O, T>(_ name: String, body: @escaping (O) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == name else { return nil }
            return value
        }], options: .backwardMatch) {
            guard let object = $0.variables["lhs"] as? O, $0.variables["rhs"] != nil else { return nil }
            return body(object)
        }
    }

    public static func objectFunctionWithParameters<O, T>(_ name: String, body: @escaping (O, [Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == name else { return nil }
            return value
        }, Keyword("("), Variable<String>("arguments", options: .notInterpreted), Keyword(")")]) { match in
            guard let object = match.variables["lhs"] as? O, match.variables["rhs"] != nil, let arguments = match.variables["arguments"] as? String else { return nil }
            let interpretedArguments = arguments.split(separator: ",").compactMap { match.interpreter.evaluate(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return body(object, interpretedArguments)
        }
    }

    public static func objectFunctionWithNamedParameters<O, T>(_ name: String, body: @escaping (O, [String: Any]) -> T?) -> Function<T> {
        return Function([Variable<O>("lhs"), Keyword("."), Variable<String>("rhs", options: .notInterpreted) {
            guard let value = $0.value as? String, value == name else { return nil }
            return value
        }, OpenKeyword("("), Variable<String>("arguments", options: .notInterpreted), CloseKeyword(")")]) { match in
            guard let object = match.variables["lhs"] as? O, match.variables["rhs"] != nil, let arguments = match.variables["arguments"] as? String else { return nil }
            var interpretedArguments: [String: Any] = [:]
            for argument in arguments.split(separator: ",") {
                let parts = String(argument).trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=")
                if let key = parts.first, let value = parts.last {
                    interpretedArguments[String(key)] = match.interpreter.evaluate(String(value))
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
