@testable import Eval
import XCTest

class VariableProcessorTests: XCTestCase {

    // init

    func test_whenInitialising_thenSetsParametersCorrectly() {
        let interpreter = DummyInterpreter()
        let context = Context()
        let processor = VariableProcessor(interpreter: interpreter, context: context)

        XCTAssertTrue(interpreter === processor.interpreter)
        XCTAssertTrue(context === processor.context)
    }

    // process

    func test_whenProcessing_thenUsesMap() {
        let variable: VariableValue = (metadata: GenericVariable<String, DummyInterpreter>("name") { _, _ in "xyz" }, value: "asd")
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())

        let result = processor.process(variable)

        XCTAssertEqual(result as! String, "xyz")
    }

    func test_whenProcessingAndInterpreted_thenUsesInterpreter() {
        let variable: VariableValue = (metadata: GenericVariable<String, DummyInterpreter>("name", options: .notTrimmed), value: "asd")
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())

        let result = processor.process(variable)

        XCTAssertEqual(result as! String, "a")
    }

    func test_whenProcessingAndNotTrimmed_thenDoesNotTrim() {
        let variable: VariableValue = (metadata: GenericVariable<String, DummyInterpreter>("name", options: [.notTrimmed, .notInterpreted]), value: "  asd  ")
        let processor = VariableProcessor(interpreter: DummyInterpreter(), context: Context())

        let result = processor.process(variable)

        XCTAssertEqual(result as! String, "  asd  ")
    }
}
