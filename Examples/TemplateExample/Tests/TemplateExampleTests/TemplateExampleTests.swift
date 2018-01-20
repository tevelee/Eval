import XCTest
import Eval
@testable import TemplateExample

class TemplateExampleTests: XCTestCase {
    let interpreter = TemplateLanguage()
    
    //MARK: Statements
    
    func testIfElseStatement() {
        XCTAssertEqual(eval("{% if x in [1,2,3] %}Hello{% else %}Bye{% endif %} {{ name }}!", ["x": 2, "name": "Teve"]), "Hello Teve!")
    }
    
    func testIfStatement() {
        XCTAssertEqual(eval("{% if true %}Hello{% endif %} {{ name }}!", ["name": "Teve"]), "Hello Teve!")
    }
    
//    func testEmbeddedIfStatement() {
//        XCTAssertEqual(eval("Result: {% if x > 1 %}{% if x < 5 %}1<x<5{% else %}x>=5{% endif %}{% else %}x<=1{% endif %}", ["x": 2]), "Result: 1<x<5")
//    }
    
    func testPrintStatement() {
        XCTAssertEqual(eval("{{ x }}", ["x": "Yo"]), "Yo")
        XCTAssertEqual(eval("{{ x + 1 }}", ["x": 5]), "6")
    }
    
    func testSetStatement() {
        _ = eval("{% set x = 4.0 %}")
        XCTAssertEqual(eval("{{ x }}"), "4")
    }
    
    func testSetWithBodyStatement() {
        _ = eval("{% set x %}this{% endset %}")
        XCTAssertEqual(eval("Check {{ x }} out"), "Check this out")
    }
    
    func testForInStatement() {
        XCTAssertEqual(eval("{% for i in [1,2,3] %}a{% endfor %}"), "aaa")
        XCTAssertEqual(eval("{% for i in x %}{{i*2}} {% endfor %}", ["x": [1, 2, 3]]), "2 4 6 ")
        XCTAssertEqual(eval("{% for i in [1,2,3] %}{{i * 2}} {% endfor %}"), "2 4 6 ")
    }
    
    //MARK: Data types
    
    func testString() {
        XCTAssertEqual(eval("{{ 'hello' }}"), "hello")
    }
    
    func testBoolean() {
        XCTAssertEqual(eval("{{ true }}"), "true")
        XCTAssertEqual(eval("{{ false }}"), "false")
        XCTAssertEqual(eval("{{ 1 < 2 }}"), "true")
    }
    
    func testDate() {
        XCTAssertEqual(eval("{{ Date(2018,12,13).format('dd/MM/yy') }}"), "13/12/18")
    }
    
    func testInteger() {
        XCTAssertEqual(eval("{{ 1 }}"), "1")
    }
    
    func testDouble() {
        XCTAssertEqual(eval("{{ 2.5 }}"), "2.5")
    }
    
    func testDictionary() {
        XCTAssertEqual(eval("{{ {'a': 1, 'b': 2} }}"), "[a: 1, b: 2]")
    }
    
    func testArray() {
        XCTAssertEqual(eval("{{ [1,2,3] }}"), "1,2,3")
    }
    
    //MARK: Functions and operators
    
    func testParentheses() {
        XCTAssertEqual(eval("{{ ( 1 + 2 ) * 3 }}"), "9")
        XCTAssertEqual(eval("{{ ( (9/3) + 2 ) * 3 }}"), "15")
        XCTAssertEqual(eval("{{ (((2))) }}"), "2")
    }
    
    func testTernary() {
        XCTAssertEqual(eval("{{ true ? 1 : 2 }}"), "1")
        XCTAssertEqual(eval("{{ false ? 1 : 2 }}"), "2")
    }
    
    func testRange() {
        XCTAssertEqual(eval("{{ 1...3 }}"), "1,2,3")
        XCTAssertEqual(eval("{{ 'a'...'c' }}"), "a,b,c")
    }
    
    func testRangeBySteps() {
        XCTAssertEqual(eval("{{ range(start=1, end=7, step=2) }}"), "1,3,5,7")
    }
    
    func testStartsWith() {
        XCTAssertEqual(eval("{{ 'Hello' starts with 'H' }}"), "true")
        XCTAssertEqual(eval("{{ 'Hello' starts with 'Hell' }}"), "true")
        XCTAssertEqual(eval("{{ 'Hello' starts with 'Yo' }}"), "false")
    }
    
    func testEndsWith() {
        XCTAssertEqual(eval("{{ 'Hello' ends with 'o' }}"), "true")
        XCTAssertEqual(eval("{{ 'Hello' ends with 'ello' }}"), "true")
        XCTAssertEqual(eval("{{ 'Hello' ends with 'Yo' }}"), "false")
    }
    
    func testContains() {
        XCTAssertEqual(eval("{{ 'Partly' contains 'art' }}"), "true")
        XCTAssertEqual(eval("{{ 'Hello' contains 'art' }}"), "false")
    }
    
    func testMatches() {
        XCTAssertEqual(eval("{{ 'Partly' matches '[A-Z]art[a-z]{2}' }}"), "true")
        XCTAssertEqual(eval("{{ 'Partly' matches '\\d+' }}"), "false")
    }
    
    func testConcat() {
        XCTAssertEqual(eval("{{ 'This' + ' is ' + 'Sparta' }}"), "This is Sparta")
    }
    
    func testAddition() {
        XCTAssertEqual(eval("{{ 1 + 2 }}"), "3")
        XCTAssertEqual(eval("{{ 1 + 2 + 3 }}"), "6")
    }
    
    func testSubstraction() {
        XCTAssertEqual(eval("{{ 5 - 2 }}"), "3")
//        XCTAssertEqual(eval("{{ 5 - 2 - 3 }}"), "0")
    }
    
    func testMultiplication() {
        XCTAssertEqual(eval("{{ 5 * 2 }}"), "10")
        XCTAssertEqual(eval("{{ 5 * 2 * 3 }}"), "30")
    }
    
    func testDivision() {
        XCTAssertEqual(eval("{{ 5 / 5 }}"), "1")
//        XCTAssertEqual(eval("{{ 144 / 12 / 4 }}"), "3")
    }
    
    func testNumericPrecedence() {
        XCTAssertEqual(eval("{{ 4 + 2 * 3 }}"), "10")
        XCTAssertEqual(eval("{{ 4 - 2 * 3 }}"), "-2")
        XCTAssertEqual(eval("{{ 4 * 3 / 2 + 2 - 8 }}"), "0")
    }
    
    func testLessThan() {
        XCTAssertEqual(eval("{{ 2 < 3 }}"), "true")
        XCTAssertEqual(eval("{{ 3 < 2 }}"), "false")
        XCTAssertEqual(eval("{{ 2 < 2 }}"), "false")
    }
    
    func testLessThanOrEqual() {
        XCTAssertEqual(eval("{{ 2 <= 3 }}"), "true")
        XCTAssertEqual(eval("{{ 3 <= 2 }}"), "false")
        XCTAssertEqual(eval("{{ 2 <= 2 }}"), "true")
    }
    
    func testGreaterThan() {
        XCTAssertEqual(eval("{{ 2 > 3 }}"), "false")
        XCTAssertEqual(eval("{{ 3 > 2 }}"), "true")
        XCTAssertEqual(eval("{{ 2 > 2 }}"), "false")
    }
    
    func testGreaterThanOrEqual() {
        XCTAssertEqual(eval("{{ 2 >= 3 }}"), "false")
        XCTAssertEqual(eval("{{ 3 >= 2 }}"), "true")
        XCTAssertEqual(eval("{{ 2 >= 2 }}"), "true")
    }
    
    func testEquals() {
        XCTAssertEqual(eval("{{ 2 == 3 }}"), "false")
        XCTAssertEqual(eval("{{ 2 == 2 }}"), "true")
    }
    
    func testNotEquals() {
        XCTAssertEqual(eval("{{ 2 != 2 }}"), "false")
        XCTAssertEqual(eval("{{ 2 != 3 }}"), "true")
    }
    
    func testInNumericArray() {
        XCTAssertEqual(eval("{{ 2 in [1,2,3] }}"), "true")
        XCTAssertEqual(eval("{{ 5 in [1,2,3] }}"), "false")
    }
    
    func testInStringArray() {
        XCTAssertEqual(eval("{{ 'a' in ['a', 'b', 'c'] }}"), "true")
        XCTAssertEqual(eval("{{ 'z' in ['a', 'b', 'c'] }}"), "false")
    }
    
    func testIncrement() {
        XCTAssertEqual(eval("{{ 2++ }}"), "3")
        XCTAssertEqual(eval("{{ -1++ }}"), "0")
    }
    
    func testDecrement() {
        XCTAssertEqual(eval("{{ 7-- }}"), "6")
        XCTAssertEqual(eval("{{ -7-- }}"), "-8")
    }
    
    func testNegation() {
        XCTAssertEqual(eval("{{ not true }}"), "false")
        XCTAssertEqual(eval("{{ not false }}"), "true")
        XCTAssertEqual(eval("{{ !true }}"), "false")
        XCTAssertEqual(eval("{{ !false }}"), "true")
    }
    
    func testIsEven() {
        XCTAssertEqual(eval("{{ 8 is even }}"), "true")
        XCTAssertEqual(eval("{{ 1 is even }}"), "false")
        XCTAssertEqual(eval("{{ -1 is even }}"), "false")
    }
    
    func testIsOdd() {
        XCTAssertEqual(eval("{{ 8 is odd }}"), "false")
        XCTAssertEqual(eval("{{ 1 is odd }}"), "true")
        XCTAssertEqual(eval("{{ -1 is odd }}"), "true")
    }
    
    func testMax() {
        XCTAssertEqual(eval("{{ [5,3,7,1].max }}"), "7")
        XCTAssertEqual(eval("{{ [-5,-3,-7,-1].max }}"), "-1")
    }
    
    func testMin() {
        XCTAssertEqual(eval("{{ [5,3,7,1].min }}"), "1")
        XCTAssertEqual(eval("{{ [-5,-3,-7,-1].min }}"), "-7")
    }
    
    func testCount() {
        XCTAssertEqual(eval("{{ [5,3,7,1].count }}"), "4")
        XCTAssertEqual(eval("{{ [].count }}"), "0")
    }
    
    func testAverage() {
        XCTAssertEqual(eval("{{ [1,2,3,4].avg }}"), "2.5")
        XCTAssertEqual(eval("{{ [2,2].avg }}"), "2")
    }
    
    func testSqrt() {
        XCTAssertEqual(eval("{{ sqrt(225) }}"), "15")
        XCTAssertEqual(eval("{{ sqrt(4) }}"), "2")
    }
    
    func testArraySubscript() {
        XCTAssertEqual(eval("{{ array.1 }}", ["array": [1,2,3]]), "2")
        XCTAssertEqual(eval("{{ [1,2,3].1 }}"), "2")
        XCTAssertEqual(eval("{{ ['a', 'b', 'c'].1 }}"), "b")
    }
    
    func testDictionarySubscript() {
        XCTAssertEqual(eval("{{ dict.b }}", ["dict": ["a": 1, "b": 2]]), "2")
        XCTAssertEqual(eval("{{ {'a': 1, 'b': 2}.b }}"), "2")
    }
    
    func testDictionaryKeys() {
        XCTAssertEqual(eval("{{ {'a': 1, 'b': 2}.keys }}"), "a,b")
    }

    func testDictionaryValues() {
        XCTAssertEqual(eval("{{ {'a': 1, 'b': 2}.values }}"), "1,2")
    }
    
    //MARK: Helpers
    
    func eval(_ template: String, _ variables: [String: Any] = [:]) -> String {
        let context = InterpreterContext(variables: variables)
        let result = interpreter.evaluate(template, context: context)
        if !context.debugInfo.isEmpty {
            print(context.debugInfo)
        }
        return result
    }
}
