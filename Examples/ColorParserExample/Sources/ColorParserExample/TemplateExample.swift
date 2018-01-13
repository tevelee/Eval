import Foundation
import AppKit
import Eval

public class ColorParser: EvaluatorWithContext {
    let interpreter: TypedInterpreter
    
    init() {
        interpreter = TypedInterpreter(dataTypes: [ColorParser.colorDataType()], functions: [ColorParser.mixFunction()])
    }
    
    static func colorDataType() -> DataType<NSColor> {
        let hex = Literal { value, _ -> NSColor? in
            guard value.first == "#", value.count == 7,
            let red = Int(value[1...2], radix: 16),
            let green = Int(value[3...4], radix: 16),
            let blue = Int(value[5...6], radix: 16) else { return nil }
            return NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
        
        let red = Literal("red", convertsTo: NSColor.red)
        
        return DataType(type: NSColor.self, literals: [hex, red]) { $0.description }
    }
    
    static func mixFunction() -> Function<NSColor> {
        return Function([Variable<NSColor>("lhs"), Keyword("mixed with"), Variable<NSColor>("rhs")]) { variables, _, _ in
            guard let lhs = variables["lhs"] as? NSColor, let rhs = variables["rhs"] as? NSColor else { return nil }
            return lhs.blend(with: rhs)
        }
    }
    
    public func evaluate(_ expression: String) -> Any? {
        return interpreter.evaluate(expression)
    }
    
    public func evaluate(_ expression: String, context: InterpreterContext) -> Any? {
        return interpreter.evaluate(expression, context: context)
    }
}

extension String {
    subscript (range: CountableClosedRange<Int>) -> Substring {
        return self[index(startIndex, offsetBy: range.lowerBound) ..< index(startIndex, offsetBy: range.upperBound)]
    }
}

extension NSColor {
    func blend(with other: NSColor, using factor: CGFloat = 0.5) -> NSColor {
        let rightFactor = 1.0 - factor
        
        var lr : CGFloat = 0
        var lg : CGFloat = 0
        var lb : CGFloat = 0
        var la : CGFloat = 0
        getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        
        var rr : CGFloat = 0
        var rg : CGFloat = 0
        var rb : CGFloat = 0
        var ra : CGFloat = 0
        other.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        
        return NSColor(calibratedRed: lr * factor + rr * rightFactor,
                       green: lg * factor + rg * rightFactor,
                       blue: lb * factor + rb * rightFactor,
                       alpha: la * factor + ra * rightFactor)
    }
}
