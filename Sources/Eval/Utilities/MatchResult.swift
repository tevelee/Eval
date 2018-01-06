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

/// Whenever a match operation is performed, the result is going to be a `MatchResult` instance.
public enum MatchResult<T> {
    /// The input could not be matched
    case noMatch
    /// The input can possibly match, if it were continuted. (It's the prefix of the matching expression)
    case possibleMatch
    /// The input matches the expression. It provides information about the `length` of the matched input, the `output` after the evaluation, and the `variables` that were processed during the process.
    case exactMatch(length: Int, output: T, variables: [String: Any])
    /// In case the matching sequence only consists of one variable, the result is going to be anyMatch
    case anyMatch(shortest: Bool)

    func isMatch() -> Bool {
        if case .exactMatch(_, _, _) = self {
            return true
        }
        return false
    }

    func isNoMatch() -> Bool {
        if case .noMatch = self {
            return true
        }
        return false
    }

    func isPossibleMatch() -> Bool {
        if case .possibleMatch = self {
            return true
        }
        return false
    }
}
