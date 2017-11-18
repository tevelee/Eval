import Foundation

public protocol Interpreter {
    associatedtype T
    func evaluate(_ expression: String) -> T
}
