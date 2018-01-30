@testable import AttributedStringExample
import Eval
import XCTest

class AttributedStringExampleTests: XCTestCase {
    let interpreter: AttributedStringInterpreter = AttributedStringInterpreter()

    func testExample() {
        let interpreter = AttributedStringInterpreter()

        XCTAssertEqual(interpreter.evaluate("<bold>Hello</bold>"), NSAttributedString(string: "Hello", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))

        XCTAssertEqual(interpreter.evaluate("It's <red>red</red>"), NSAttributedString(string: "It's ").appending(NSAttributedString(string: "red", attributes: [.foregroundColor: NSColor.red])))

        let style = interpreter.evaluate("<center>Centered text</center>").attribute(.paragraphStyle, at: 0, effectiveRange: nil) as! NSParagraphStyle
        XCTAssertEqual(style.alignment, .center)
    }
}
