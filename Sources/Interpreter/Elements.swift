import Foundation

public protocol MatchElement {
    func matches(prefix: String, isLast: Bool) -> MatchResult<Any>
}

public class Keyword : MatchElement {
    public typealias T = String
    
    let name: String
    
    public init(_ name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult<Any> {
        if name == prefix || prefix.hasPrefix(name) {
            return .exactMatch(length: name.count, output: name, variables: [:])
        } else if name.hasPrefix(prefix) {
            return .possibleMatch
        } else {
            return .noMatch
        }
    }
}

protocol VariableProtocol {
    var name: String { get }
    var shortest: Bool { get }
    var interpreted: Bool { get }
    var acceptsNilValue: Bool { get }
    func performMap(input: Any, interpreter: Any) -> Any?
}

public class GenericVariable<T, E: VariableEvaluator> : VariableProtocol, MatchElement {
    let name: String
    let shortest: Bool
    let interpreted: Bool
    let acceptsNilValue: Bool
    let map: (Any, E) -> T?
    
    public init(_ name: String, shortest: Bool = true, interpreted: Bool = true, acceptsNilValue: Bool = false, map: @escaping (Any, E) -> T? = { (value,_) in value as? T }) {
        self.name = name
        self.shortest = shortest
        self.interpreted = interpreted
        self.acceptsNilValue = acceptsNilValue
        self.map = map
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult<Any> {
        return .anyMatch(shortest: shortest)
    }
    
    func mapped<K>(_ map: @escaping ValueMap<T, K>) -> GenericVariable<K, E> {
        return GenericVariable<K, E>(name, shortest: shortest, interpreted: interpreted, map: { value, interpreter in
            guard let value = self.map(value, interpreter) else { return nil }
            return map(value)
        })
    }
    
    func performMap(input: Any, interpreter: Any) -> Any? {
        guard let interpreter = interpreter as? E else { return nil }
        return map(input, interpreter)
    }
}
