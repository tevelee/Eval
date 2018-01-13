import Foundation
import AppKit
import Eval

class AttributedStringTemplateInterpreter: TemplateInterpreter<NSAttributedString> {
    typealias EvaluatedType = NSAttributedString
    
    override func evaluate(_ expression: String, context: InterpreterContext = InterpreterContext()) -> NSAttributedString {
        return evaluate(expression, context: context, reducer: (initialValue: NSAttributedString(), reduceValue: { existing, next in
            return existing.appending(next)
        }, reduceCharacter: { existing, next in
            return existing.appending(NSAttributedString(string: String(next)))
        }))
    }
}

public class AttributedStringInterpreter: EvaluatorWithContext {
    public typealias EvaluatedType = NSAttributedString
    
    let interpreter : AttributedStringTemplateInterpreter
    
    init() {
        let context = InterpreterContext()
        
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
    
    public func evaluate(_ expression: String, context: InterpreterContext) -> AttributedStringInterpreter.EvaluatedType {
        return interpreter.evaluate(expression, context: context)
    }
    
    static func attributeMatcher(name: String, attributes: [NSAttributedStringKey: Any]) -> Matcher<NSAttributedString, TemplateInterpreter<NSAttributedString>> {
        return Matcher([OpenKeyword("<\(name)>"), GenericVariable<String, AttributedStringTemplateInterpreter>("body", interpreted: false), CloseKeyword("</\(name)>")]) { variables, _, _ in
            guard let body = variables["body"] as? String else { return nil }
            return NSAttributedString(string: body, attributes: attributes)
        }
    }
}

public extension NSAttributedString {
    public func appending(_ other: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        mutable.append(other)
        return mutable
    }
}
