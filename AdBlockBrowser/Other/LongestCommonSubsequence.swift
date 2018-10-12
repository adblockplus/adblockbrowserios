/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

// swiftlint:disable:next cyclomatic_complexity function_body_length
public func longestCommonSubsequence<C>(_ sequence1: C,
                                        _ sequence2: C) -> [(Int, Int)] where C: Collection,
                                                                              C.Iterator.Element: Equatable,
                                                                              C.Index == Int {
    let row = Array(repeating: (length: 0, indices: (i: -1, j: -1)), count: Int(sequence2.count))
    var matrix: [[(length: Int, indices: (i: Int, j: Int))]] = Array(repeating: row, count: sequence1.count)

    if sequence1.count == 0 || sequence2.count == 0 {
        return []
    }

    let computeNext = { (result: (length: Int, indices: (i: Int, j: Int))) -> (length: Int, indices: (i: Int, j: Int)) in
        if sequence1[result.indices.i] == sequence2[result.indices.j] {
            return (result.length, result.indices)
        } else {
            return (result.length, matrix[result.indices.i][result.indices.j].indices)
        }
    }

    // swiftlint:disable:next identifier_name
    for i in sequence1.startIndex ..< sequence1.endIndex {
        if sequence1[i] == sequence2[0] {
            matrix[i][0] = (1, (-1, -1))
        } else if i == 0 || matrix[i - 1][0].length == 0 {
            matrix[i][0] = (0, (-1, -1))
        } else {
            matrix[i][0] = computeNext((1, (i - 1, 0)))
        }
    }

    // swiftlint:disable:next identifier_name
    for j in sequence2.index(after: sequence2.startIndex) ..< sequence2.endIndex {
        if sequence1[0] == sequence2[j] {
            matrix[0][j] = (1, (-1, -1))
        } else if matrix[0][j - 1].length == 0 {
            matrix[0][j] = (0, (-1, -1))
        } else {
            matrix[0][j] = computeNext((1, (0, j - 1)))
        }
    }

    // swiftlint:disable:next identifier_name
    for i in sequence1.index(after: sequence1.startIndex) ..< sequence1.endIndex {
        // swiftlint:disable:next identifier_name
        for j in sequence2.index(after: sequence2.startIndex) ..< sequence2.endIndex {
            let result: (length: Int, indices: (i: Int, j: Int))
            if sequence1[i] == sequence2[j] {
                result = (matrix[i - 1][j - 1].length + 1, (i - 1, j - 1))
            } else {
                let length1 = matrix[i - 1][j].length
                let length2 = matrix[i][j - 1].length

                if length1 > length2 {
                    result = (length1, (i - 1, j))
                } else {
                    result = (length2, (i, j - 1))
                }
            }

            matrix[i][j] = computeNext(result)
        }
    }

    var result = [(Int, Int)]()
    var indices = (i: sequence1.count - 1, j: sequence2.count - 1)

    while indices.i != -1 && indices.j != -1 {

        if sequence1[indices.i] == sequence2[indices.j] {
            result.append(indices)
        }

        indices = matrix[indices.i][indices.j].indices
    }

    return result.reversed()
}
