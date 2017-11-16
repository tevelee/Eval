import Foundation

protocol Token {
    
}

struct TextToken : Token {
    
}

class Tokenizer {
    let input: String
    
    init(input: String) {
        self.input = input
    }
    
    func tokenize() -> [Token] {
        return []
    }
}
