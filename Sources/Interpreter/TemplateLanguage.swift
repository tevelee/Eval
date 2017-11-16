import Foundation

public enum MatchResult: Equatable {
    case noMatch
    case prefix
    case match(position: Int, output: String)
    case any
    
    public static func ==(lhs: MatchResult, rhs: MatchResult) -> Bool {
        switch (lhs, rhs) {
        case (.noMatch, .noMatch), (.prefix, .prefix), (.any, .any):
            return true
        case (.match(let leftPosition, let leftOutput), .match(let rightPosition, let rightOutput)):
            return leftPosition == rightPosition && leftOutput == rightOutput
        default:
            return false
        }
    }
    
    func isMatch() -> Bool {
        if case .match(position: _, output: _) = self {
            return true
        }
        return false
    }
}

public protocol Element {
    func matches(prefix: String) -> MatchResult
}

func +(left: Element, right: Element) -> [Element] {
    return [left, right]
}

func +<A>(left: [A], right: A) -> [A] {
    return left + [right]
}

func +=<A> (left: inout [A], right: A) {
    left = left + right
}

func += (left: inout String, right: Character) {
    left = left + String(right)
}

extension CharacterSet {
    func contains(_ character: Character) -> Bool {
        if let string = String(character).unicodeScalars.first {
            return self.contains(string)
        } else {
            return false
        }
    }
}

extension String {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    
    subscript (range: CountableRange<Int>) -> Substring {
        return self[index(startIndex, offsetBy: range.startIndex) ..< index(startIndex, offsetBy: range.endIndex)]
    }
    
    subscript (range: PartialRangeUpTo<Int>) -> Substring {
        return self[..<index(startIndex, offsetBy: range.upperBound)]
    }
}

public struct Pattern : Element {
    let elements: [Element]
    let handler: ([String: String]) -> String?
    
    public init(_ elements: [Element], handler: @escaping ([String: String]) -> String? = { _ in nil }) {
        self.elements = elements
        self.handler = handler
    }
    
    public func matches(prefix: String) -> MatchResult {
        var elements = self.elements
        
        var position = 1
        repeat {
            let stringSoFar = String(prefix[..<position])
            if let current = elements.first {
                let result = current.matches(prefix: stringSoFar)
                switch result {
                case .noMatch:
                    return .noMatch
                case .prefix, .any:
                    position += 1
                    continue
                case .match(let position, let output):
                    elements.remove(at: 0)
                    if elements.count == 0 {
                        return .match(position: position, output: output)
                    }
                }
            }
        } while position < prefix.count
        
        return .prefix
    }
}

public struct Keyword : Element {
    let name: String
    
    public init(_ name: String) {
        self.name = name
    }
    
    public func matches(prefix: String) -> MatchResult {
        if name == prefix {
            return .match(position: name.count, output: name)
        } else if name.hasPrefix(prefix) {
            return .prefix
        } else {
            return .noMatch
        }
    }
}

public struct Variable : Element {
    let name: String
    
    public init(_ name: String) {
        self.name = name
    }
    
    public func matches(prefix: String) -> MatchResult {
        return .any
    }
}

public protocol Filter {
    
}

public class TemplateLanguage : Language {
    let statements: [Pattern]
    let filters: [Filter]
    
    init(statements: [Pattern], filters: [Filter]) {
        self.statements = statements
        self.filters = filters
    }
    
    public func interpret(input: String) -> String {
        var output = ""
        
        var position = 0
        repeat {
            let result = matchStatements(in: input, from: position)
            switch result {
            case .noMatch:
                output += input[position]
                position += 1
            case .match(let endPosition, let matchOutput):
                output += matchOutput
                position += endPosition
            default:
                assertionFailure("Invalid result")
            }
        } while position < input.count
        
        return output
    }
    
    func matchStatements(in input: String, from start: Int, until length: Int = 1) -> MatchResult {
        let prefix = String(input[start ..< start + length])
        let elements = statements.map { ($0, result: $0.matches(prefix: prefix)) }.filter { $0.result != .noMatch }
        
        if elements.count == 0 {
            return .noMatch
        }
        if let matchingElement = elements.first(where: { $0.result.isMatch() }), case .match(let position, let output) = matchingElement.result {
            return .match(position: start + position, output: output)
        }
        if elements.contains(where: { $0.result == .prefix }) {
            if input.count == start + length {
                return .match(position: start + length, output: prefix)
            } else {
                return matchStatements(in: input, from: start, until: length + 1)
            }
        }
        return .noMatch
    }
}

public protocol Expression {
    
}

public struct BooleanExpression : Expression {
    let expression: String
    
    public init(_ expression: String) {
        self.expression = expression
    }
    
    public func evaluate() -> Bool {
        return true
    }
}

