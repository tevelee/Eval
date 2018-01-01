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
    func performMap(input: Any) -> Any?
}

public class Variable<T> : VariableProtocol, MatchElement {
    let name: String
    let shortest: Bool
    let interpreted: Bool
    let map: ValueMap<Any, T>
    
    public init(_ name: String, shortest: Bool = true, interpreted: Bool = true, map: @escaping ValueMap<Any, T> = { $0 as? T }) {
        self.name = name
        self.shortest = shortest
        self.interpreted = interpreted
        self.map = map
    }
    
    public func matches(prefix: String, isLast: Bool = false) -> MatchResult<Any> {
        return .anyMatch(shortest: shortest)
    }
    
    func mapped<K>(_ map: @escaping ValueMap<T, K>) -> Variable<K> {
        return Variable<K>(name, shortest: shortest, interpreted: interpreted, map: {
            guard let value = self.map($0) else { return nil }
            return map(value)
        })
    }
    
    func performMap(input: Any) -> Any? {
        return map(input)
    }
}
