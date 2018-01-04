import Foundation

public enum MatchResult<T> {
    case noMatch
    case possibleMatch
    case exactMatch(length: Int, output: T, variables: [String: Any])
    case anyMatch(shortest: Bool)
    
    func isMatch() -> Bool {
        if case .exactMatch(_,_,_) = self {
            return true
        }
        return false
    }
    
    func isNoMatch() -> Bool {
        if case .noMatch = self {
            return true
        }
        return false
    }
    
    func isPossibleMatch() -> Bool {
        if case .possibleMatch = self {
            return true
        }
        return false
    }
}
