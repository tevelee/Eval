import Foundation

class Scanner {
    let input: String
    let position: Int
    
    init(input: String, position: Int = 0) {
        self.input = input
        self.position = position
    }
    
    func isEmpty() -> Bool {
        return input.isEmpty
    }
    
//    func nextCharacter() -> Character {
//        
//    }
//    
//    func readNext() -> Scanner {
//        
//    }
//    
//    func readUntil() -> String {
//        
//    }
}
