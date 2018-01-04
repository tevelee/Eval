import Foundation

public protocol MatchElement {
    func matches(prefix: String, isLast: Bool) -> MatchResult<Any>
}

public class Keyword : MatchElement {
    public enum KeywordType {
        case generic
        case openingStatement
        case closingStatement
    }
    
    public typealias T = String
    
    let name: String
    let type: KeywordType
    
    public init(_ name: String, type: KeywordType = .generic) {
        self.name = name.trim()
        self.type = type
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

public class OpenKeyword : Keyword {
    public init(_ name: String) {
        super.init(name, type: .openingStatement)
    }
}

public class CloseKeyword : Keyword {
    public init(_ name: String) {
        super.init(name, type: .closingStatement)
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
