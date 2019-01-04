import AppKit
@_exported import Eval
@_exported import class Eval.Pattern
import Foundation

public class ColorParser: EvaluatorWithLocalContext {
    let interpreter: TypedInterpreter

    init() {
        interpreter = TypedInterpreter(dataTypes: [ColorParser.colorDataType()], functions: [ColorParser.mixFunction()])
    }

    static func colorDataType() -> DataType<NSColor> {
        let hex = Literal<NSColor> {
            guard $0.value.first == "#", $0.value.count == 7,
            let red = Int($0.value[1...2], radix: 16),
            let green = Int($0.value[3...4], radix: 16),
            let blue = Int($0.value[5...6], radix: 16) else { return nil }
            return NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }

        let red = Literal("red", convertsTo: NSColor.red)

        return DataType(type: NSColor.self, literals: [hex, red]) { $0.value.description }
    }

    static func mixFunction() -> Function<NSColor> {
        return Function([Variable<NSColor>("lhs"), Keyword("mixed with"), Variable<NSColor>("rhs")]) {
            guard let lhs = $0.variables["lhs"] as? NSColor, let rhs = $0.variables["rhs"] as? NSColor else { return nil }
            return lhs.blend(with: rhs)
        }
    }

    public func evaluate(_ expression: String) -> Any? {
        return interpreter.evaluate(expression)
    }

    public func evaluate(_ expression: String, context: Context) -> Any? {
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
        let inverseFactor = 1.0 - factor

        var leftRed: CGFloat = 0
        var leftGreen: CGFloat = 0
        var leftBlue: CGFloat = 0
        var leftAlpha: CGFloat = 0
        getRed(&leftRed, green: &leftGreen, blue: &leftBlue, alpha: &leftAlpha)

        var rightRed: CGFloat = 0
        var rightGreen: CGFloat = 0
        var rightBlue: CGFloat = 0
        var rightAlpha: CGFloat = 0
        other.getRed(&rightRed, green: &rightGreen, blue: &rightBlue, alpha: &rightAlpha)

        return NSColor(calibratedRed: leftRed * factor + rightRed * inverseFactor,
                       green: leftGreen * factor + rightGreen * inverseFactor,
                       blue: leftBlue * factor + rightBlue * inverseFactor,
                       alpha: leftAlpha * factor + rightAlpha * inverseFactor)
    }
}
