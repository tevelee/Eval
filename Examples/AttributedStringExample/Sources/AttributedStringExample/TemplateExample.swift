import AppKit
@_exported import Eval
import Foundation
@_exported import class Eval.Pattern

// swiftlint:disable:next type_name
public class AttributedStringTemplateInterpreter: TemplateInterpreter<NSAttributedString> {
    typealias EvaluatedType = NSAttributedString

    override public func evaluate(_ expression: String, context: Context = Context()) -> NSAttributedString {
        return evaluate(expression, context: context, reducer: (initialValue: NSAttributedString(), reduceValue: { existing, next in
            existing.appending(next)
        }, reduceCharacter: { existing, next in
            existing.appending(NSAttributedString(string: String(next)))
        }))
    }
}

// swiftlint:disable:next type_name
public class AttributedStringInterpreter: EvaluatorWithLocalContext {
    public typealias EvaluatedType = NSAttributedString

    let interpreter: AttributedStringTemplateInterpreter

    init() {
        let context = Context()

        let center = NSMutableParagraphStyle()
        center.alignment = .center

        interpreter = AttributedStringTemplateInterpreter(statements: [AttributedStringInterpreter.attributeMatcher(name: "bold", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]),
                                                                       AttributedStringInterpreter.attributeMatcher(name: "red", attributes: [.foregroundColor: NSColor.red]),
                                                                       AttributedStringInterpreter.attributeMatcher(name: "center", attributes: [.paragraphStyle: center])],
                                                          interpreter: TypedInterpreter(context: context),
                                                          context: context)
    }

    public func evaluate(_ expression: String) -> AttributedStringInterpreter.EvaluatedType {
        return interpreter.evaluate(expression)
    }

    public func evaluate(_ expression: String, context: Context) -> AttributedStringInterpreter.EvaluatedType {
        return interpreter.evaluate(expression, context: context)
    }

    static func attributeMatcher(name: String, attributes: [NSAttributedStringKey: Any]) -> Pattern<NSAttributedString, TemplateInterpreter<NSAttributedString>> {
        return Pattern([OpenKeyword("<\(name)>"), GenericVariable<String, AttributedStringTemplateInterpreter>("body", options: .notInterpreted), CloseKeyword("</\(name)>")]) { variables, _, _ in
            guard let body = variables["body"] as? String else { return nil }
            return NSAttributedString(string: body, attributes: attributes)
        }
    }
}

public extension NSAttributedString {
    func appending(_ other: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        mutable.append(other)
        return mutable
    }
}
