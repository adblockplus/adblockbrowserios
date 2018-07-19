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

public extension Collection {
    public func separate(_ isInFirstPart: (Iterator.Element) throws -> Bool) rethrows
        -> ([Iterator.Element], [Iterator.Element]) {
            // swiftlint:disable:next syntactic_sugar
            var result = (Array<Iterator.Element>(), Array<Iterator.Element>())
            for element in self {
                if try isInFirstPart(element) {
                    result.0.append(element)
                } else {
                    result.1.append(element)
                }
            }
            return result
    }
}

public extension Collection where Index == Int, Indices == CountableRange<Index> {
    public func element(at index: Index) -> Iterator.Element? {
        if indices.contains(index) {
            return self[index]
        } else {
            return nil
        }
    }
}
