import Foundation

public protocol Language {
    func interpret(input: String) -> String
}
