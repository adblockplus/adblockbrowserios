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

import Foundation

extension Array {
    mutating func remove(at removedIndices: IndexSet) {
        let indices = self.indices
        var handle = startIndex
        for index in indices {
            self[handle] = self[index]
            if !removedIndices.contains(index) {
                handle += 1
            }
        }
        removeLast(endIndex - handle)
    }

    mutating func insert(_ elements: [Int: Element]) {
        append(contentsOf: elements.values)
        let indices = self.indices
        var offest = elements.values.count
        for index in indices.reversed() {
            if let element = elements[index] {
                self[index] = element
                offest -= 1
            } else {
                self[index] = self[index - offest]
            }
        }
    }
}
