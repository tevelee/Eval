import Foundation

public protocol Interpreter {
    associatedtype T
    init()
    func evaluate(_ expression: String) throws -> T
}
