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
/// - parameter left: Left hand side
/// - parameter right: Right hand side
/// - returns: An array with two elements (left and right in this order)
public func + (left: PatternElement, right: PatternElement) -> [PatternElement] {
    return [left, right]
}

/// Syntactic sugar for appended arrays
/// - parameter array: The array to append
/// - parameter element: The appended element
/// - returns: A new array by appending `array` with `element`
internal func + <A>(array: [A], element: A) -> [A] {
    return array + [element]
}

/// Syntactic sugar for appending mutable arrays
/// - parameter array: The array to append
/// - parameter element: The appended element
internal func += <A> (array: inout [A], element: A) {
    array = array + element //swiftlint:disable:this shorthand_operator
}

/// Helpers on `String` to provide `Int` based subscription features and easier usage
extension String {
    /// Shorter syntax for trimming
    /// - returns: The `String` without the prefix and postfix whitespace characters
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
