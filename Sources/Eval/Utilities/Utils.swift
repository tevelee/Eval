/*
 *  Copyright (c) 2018 Laszlo Teveli.
 *
 *  Licensed to the Apache Software Foundation (ASF) under one
 *  or more contributor license agreements.  See the NOTICE file
 *  distributed with this work for additional information
 *  regarding copyright ownership.  The ASF licenses this file
 *  to you under the Apache License, Version 2.0 (the
 *  "License"); you may not use this file except in compliance
 *  with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

import Foundation

/// Syntactic sugar for `MatchElement` instances to feel like concatenation, whenever the input requires an array of elements.
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
