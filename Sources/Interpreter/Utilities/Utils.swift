import Foundation

public func +(left: Element, right: Element) -> [Element] {
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
    
    public func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
