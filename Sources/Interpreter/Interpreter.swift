import Foundation

public class Interpreter {
    let language: Language
    
    public init(language: Language) {
        self.language = language
    }
    
    public func interpret(_ input: String) -> String {
        return language.interpret(input: input)
    }
}
