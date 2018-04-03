@testable import ColorParserExample
import Eval
import XCTest

class ColorParserExampleTests: XCTestCase {
    let colorParser: ColorParser = ColorParser()

    func testExample() {
        XCTAssertEqual(colorParser.evaluate("#00ff00") as! NSColor, NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1))
        XCTAssertEqual(colorParser.evaluate("red") as! NSColor, .red)
        XCTAssertEqual(colorParser.evaluate("#ff0000 mixed with #0000ff") as! NSColor, NSColor(calibratedRed: 0.5, green: 0, blue: 0.5, alpha: 1))
    }
}
