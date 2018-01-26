import XCTest
@testable import Eval

class KeywordTests: XCTestCase {
    
    //MARK: Initialisation
    
    func test_whenKeywordIsCreated_thenNameAndTypeIsSet() {
        let dummyName = "test name"
        let dummyType = Keyword.KeywordType.generic
        
        let keyword = Keyword(dummyName, type: dummyType)
        
        XCTAssertEqual(keyword.name, dummyName)
        XCTAssertEqual(keyword.type, dummyType)
    }
    
    func test_whenKeywordIsCreated_thenTypeIsGenericByDefault() {
        let keyword = Keyword("test name")
        
        XCTAssertEqual(keyword.type, .generic)
    }
    
    //MARK: Equality
    
    func test_whenIdenticalKeywordsAreCreated_thenTheyAreEqual() {
        let keyword1 = Keyword("test name", type: .openingStatement)
        let keyword2 = Keyword("test name", type: .openingStatement)
        
        XCTAssertEqual(keyword1, keyword2)
    }
    
    func test_whenKeywordsWithDifferentNamesAreCreated_thenTheyAreNotEqual() {
        let keyword1 = Keyword("test name", type: .openingStatement)
        let keyword2 = Keyword("different", type: .openingStatement)
        
        XCTAssertNotEqual(keyword1, keyword2)
    }
    
    func test_whenKeywordsWithDifferentTypesAreCreated_thenTheyAreNotEqual() {
        let keyword1 = Keyword("test name", type: .openingStatement)
        let keyword2 = Keyword("test name", type: .closingStatement)
        
        XCTAssertNotEqual(keyword1, keyword2)
    }
    
    //MARK: Match
    
//    func test_whenPartlyMatches_thenReturnsPossibleMatch() {
//        let keyword = Keyword("checking prefix")
//        
//        let result = keyword.matches(prefix: "check")
//        
//        XCTAssertTrue(result.isPossibleMatch())
//    }
//    
//    func test_whenNotMatches_thenReturnsNoMatch() {
//        let keyword = Keyword("checking prefix")
//        
//        let result = keyword.matches(prefix: "example")
//        
//        XCTAssertTrue(result.isNoMatch())
//    }
//    
//    func test_whenMatches_thenReturnsExactMatch() {
//        let keyword = Keyword("checking prefix")
//        
//        let result = keyword.matches(prefix: "checking prefix")
//        
//        verifyMatch(expectation: "checking prefix", result: result)
//    }
//    
//    func test_whenMatchesAndContinues_thenReturnsExactMatch() {
//        let keyword = Keyword("checking prefix")
//        
//        let result = keyword.matches(prefix: "checking prefix with extra content")
//        
//        verifyMatch(expectation: "checking prefix", result: result)
//    }
//    
//    //MARK: OpenKeyword
//    
//    func test_whenCreatingOpenKeyword_thenTheTypeIsSetCorrectly() {
//        let keyword = OpenKeyword("checking prefix")
//        
//        XCTAssertEqual(keyword.type, .openingStatement)
//        XCTAssertEqual(keyword.name, "checking prefix")
//    }
//    
//    //MARK: CloseKeyword
//    
//    func test_whenCreatingCloseKeyword_thenTheTypeIsSetCorrectly() {
//        let keyword = CloseKeyword("checking prefix")
//        
//        XCTAssertEqual(keyword.type, .closingStatement)
//        XCTAssertEqual(keyword.name, "checking prefix")
//    }
//    
//    //MARK: Match performance
//    
//    func test_whenShortKeywordMatchesShortInput_thenPerformsWell() {
//        let keyword = Keyword("=")
//        self.measure {
//            _ = keyword.matches(prefix: "= asd")
//        }
//    }
//    
//    func test_whenShortKeywordNotMatchesInput_thenPerformsWell() {
//        let keyword = Keyword("=")
//        self.measure {
//            _ = keyword.matches(prefix: "checking prefix")
//        }
//    }
//    
//    func test_whenShortKeywordHureInput_thenPerformsWell() {
//        let keyword = Keyword("=")
//        self.measure {
//            _ = keyword.matches(prefix: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.")
//        }
//    }
//    
//    func test_whenLargeKeywordMatchesShortInput_thenPerformsWell() {
//        let keyword = Keyword("this is an example to match")
//        self.measure {
//            _ = keyword.matches(prefix: "this is an example to match and some other things")
//        }
//    }
//    
//    func test_whenLargeKeywordNotMatchesInput_thenPerformsWell() {
//        let keyword = Keyword("this is an example to match")
//        self.measure {
//            _ = keyword.matches(prefix: "x and y")
//        }
//    }
//    
//    func test_whenLargeKeywordHureInput_thenPerformsWell() {
//        let keyword = Keyword("=")
//        self.measure {
//            _ = keyword.matches(prefix: "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.")
//        }
//    }
    
    //MARK: Helpers
    
    func verifyMatch(expectation: String, result: MatchResult<Any>) {
        if case .exactMatch(let length, let output, let variables) = result {
            XCTAssertEqual(length, expectation.count)
            XCTAssertEqual(output as! String, expectation)
            XCTAssertTrue(variables.isEmpty)
        } else {
            fatalError()
        }
    }
}
