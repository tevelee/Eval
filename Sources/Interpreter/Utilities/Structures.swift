import Foundation

public enum MatchResult: Equatable {
    case noMatch
    case possibleMatch
    case exactMatch(length: Int, output: String, variables: [String: String])
    case anyMatch
    
    public static func ==(lhs: MatchResult, rhs: MatchResult) -> Bool {
        switch (lhs, rhs) {
        case (.noMatch, .noMatch), (.possibleMatch, .possibleMatch), (.anyMatch, .anyMatch):
            return true
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
