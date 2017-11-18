import Foundation

public enum MatchResult: Equatable {
    case noMatch
    case possibleMatch
    case exactMatch(length: Int, output: String, variables: [String: String])
    case anyMatch(shortest: Bool)
    
    public static func ==(lhs: MatchResult, rhs: MatchResult) -> Bool {
        switch (lhs, rhs) {
        case (.noMatch, .noMatch), (.possibleMatch, .possibleMatch):
            return true
        case (.anyMatch(let leftShortest), .anyMatch(let rightShortest)):
            return leftShortest == rightShortest
        case (.exactMatch(let leftLength, let leftOutput, let leftVariables),
              .exactMatch(let rightLength, let rightOutput, let rightVariables)):
            return leftLength == rightLength && leftOutput == rightOutput && leftVariables == rightVariables
        default:
            return false
        }
    }
    
    func isMatch() -> Bool {
        if case .exactMatch(length: _, output: _, variables: _) = self {
            return true
        }
        return false
    }
}
