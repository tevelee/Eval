import XCTest
@testable import Eval

class MatchResultTests: XCTestCase {
    
    //MARK: isMatch
    
    func test_whenMatchIsExactMatch_thenIsMatchReturnsTrue() {
        let matchResult = MatchResult.exactMatch(length: 1, output: "a", variables: [:])
        
        XCTAssertTrue(matchResult.isMatch())
    }
    
    func test_whenMatchIsNotExactMatch_thenIsMatchReturnsFalse() {
        let matchResult = MatchResult<String>.anyMatch(exhaustive: true)
        
        XCTAssertFalse(matchResult.isMatch())
    }
    
    //MARK: isPossibleMatch
    
    func test_whenMatchIsPossibleyMatch_thenIsPossibleMatchReturnsTrue() {
        let matchResult = MatchResult<Int>.possibleMatch
        
        XCTAssertTrue(matchResult.isPossibleMatch())
    }
    
    func test_whenMatchIsNotPossibleyMatch_thenIsPossibleMatchReturnsFalse() {
        let matchResult = MatchResult<Int>.noMatch
        
        XCTAssertFalse(matchResult.isPossibleMatch())
    }
    
    //MARK: isNoMatch
    
    func test_whenMatchIsNoMatch_thenIsNoMatchReturnsTrue() {
        let matchResult = MatchResult<Int>.noMatch
        
        XCTAssertTrue(matchResult.isNoMatch())
    }
    
    func test_whenMatchIsNotNoMatch_thenIsNoMatchReturnsFalse() {
        let matchResult = MatchResult<Int>.anyMatch(exhaustive: false)
        
        XCTAssertFalse(matchResult.isNoMatch())
    }
    
    //MARK: isAnyMatch
    
    func test_whenMatchIsAnyMatch_thenIsAnyMatchReturnsTrue() {
        let matchResult = MatchResult<Int>.anyMatch(exhaustive: true)
        
        XCTAssertTrue(matchResult.isAnyMatch(exhaustive: true))
    }
    
    func test_whenMatchIsAnyMatch_thenIsAnyMatchWithParameterReturnsTrue() {
        let matchResult = MatchResult<Int>.anyMatch(exhaustive: false)
        
        XCTAssertTrue(matchResult.isAnyMatch(exhaustive: false))
    }
    
    func test_whenMatchIsNotAnyMatch_thenIsAnyMatchReturnsFalse() {
        let matchResult = MatchResult<Int>.possibleMatch
        
        XCTAssertFalse(matchResult.isAnyMatch())
    }
    
    //MARK: Equality
    
    func test_whenTwoAnyMatchesAreCompared_thenResultIsEqual() {
        let one = MatchResult<Int>.anyMatch(exhaustive: false)
        let two = MatchResult<Int>.anyMatch(exhaustive: false)
        
        XCTAssertTrue(one == two)
    }
    
    func test_whenTwoAnyMatchesWithDifferentPropertiesAreCompared_thenResultIsNotEqual() {
        let one = MatchResult<Int>.anyMatch(exhaustive: false)
        let two = MatchResult<Int>.anyMatch(exhaustive: true)
        
        XCTAssertFalse(one == two)
    }
    
    func test_whenTwoNoMatchesAreCompared_thenResultIsEqual() {
        let one = MatchResult<Int>.noMatch
        let two = MatchResult<Int>.noMatch
        
        XCTAssertTrue(one == two)
    }
    
    func test_whenTwoPossibleMatchesAreCompared_thenResultIsEqual() {
        let one = MatchResult<Int>.possibleMatch
        let two = MatchResult<Int>.possibleMatch
        
        XCTAssertTrue(one == two)
    }
    
    func test_whenTwoExactMatchesAreCompared_thenResultIsEqual() {
        let one = MatchResult<String>.exactMatch(length: 1, output: "a", variables: [:])
        let two = MatchResult<String>.exactMatch(length: 1, output: "a", variables: [:])
        
        XCTAssertTrue(one == two)
    }
    
    func test_whenTwoExactMatchesWithDifferentPropertiesAreCompared_thenResultIsNotEqual() {
        let one = MatchResult<String>.exactMatch(length: 1, output: "a", variables: [:])
        let two = MatchResult<String>.exactMatch(length: 2, output: "b", variables: ["1": 2])

        XCTAssertFalse(one == two)
    }
    
    func test_whenTwoDifferentMatchesAreCompared_thenResultIsNotEqual() {
        let one = MatchResult<String>.exactMatch(length: 1, output: "a", variables: [:])
        let two = MatchResult<String>.anyMatch(exhaustive: true)
        
        XCTAssertFalse(one == two)
    }
}
