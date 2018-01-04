import Foundation

public func +(left: MatchElement, right: MatchElement) -> [MatchElement] {
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
    
    subscript (range: CountablePartialRangeFrom<Int>) -> Substring {
        return self[index(startIndex, offsetBy: range.lowerBound)...]
    }
    
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func position(of target: String, from: Int = 0) -> Int? {
        return range(of: target, options: [], range: Range(uncheckedBounds: (index(startIndex, offsetBy: from), endIndex)))?.lowerBound.encodedOffset
    }
}
