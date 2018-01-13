import XCTest
import Eval
@testable import ColorParserExample

class ColorParserExampleTests: XCTestCase {
    let colorParser = ColorParser()
    
    func testExample() {
        XCTAssertEqual(colorParser.evaluate("#00ff00") as! NSColor, .green)
        XCTAssertEqual(colorParser.evaluate("red") as! NSColor, .red)
        XCTAssertEqual(colorParser.evaluate("#ff0000 mixed with #0000ff") as! NSColor, NSColor(calibratedRed: 0.5, green: 0, blue: 0.5, alpha: 1))
    }
}
