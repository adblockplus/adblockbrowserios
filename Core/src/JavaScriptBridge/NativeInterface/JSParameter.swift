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

protocol JSParameter {
    init?(json: Any?)
}

struct JSAny: JSParameter {
    let any: Any

    init?(json: Any?) {
        // Converts possible nil value to NSNull
        any = json as Any
    }
}

struct Countdown: Sequence, IteratorProtocol {
    var count: Int

    mutating func next() -> Int? {
        if count == 0 {
            return nil
        } else {
            defer { count -= 1 }
            return count
        }
    }
}

struct JSArray<T>: JSParameter, Collection, ExpressibleByArrayLiteral where T: JSParameter {
    public func index(after index: Int) -> Int {
        return contents.index(after: index)
    }

    public subscript(bounds: Range<Int>) -> ArraySlice<T> {
        return contents[bounds]
    }

    let contents: [T]

    init?(json: Any?) {
        if let jsonArray = json as? [Any], let contents = jsonArray.reduce(Optional([T]()), { result, output in
            if let uwResult = result, let uwOutput = T(json: output) {
                return uwResult + [uwOutput]
            } else {
                return nil
            }
        }) {
            self.contents = contents
        } else {
            return nil
        }
    }

    init(arrayLiteral elements: Element...) {
        contents = elements
    }

    init<S: Sequence>(_ sequence: S) where S.Iterator.Element == T {
        contents = Array(sequence)
    }

    typealias Element = T
    typealias Index = Array<T>.Index
    typealias SubSequence = Array<T>.SubSequence
    typealias Iterator = Array<T>.Iterator

    var startIndex: Int {
        return contents.startIndex
    }

    var endIndex: Int {
        return contents.endIndex
    }

    subscript(index: Int) -> T {
        return contents[index]
    }

    func makeIterator() -> Iterator {
        return contents.makeIterator()
    }

    var underestimatedCount: Int {
        return 0
    }
}

struct JSObject<V>: JSParameter, Collection where V: JSParameter {
    let contents: [String: V]

    init?(json: Any?) {
        if let jsonMap = json as? [String: Any] {
            var contents = [String: V]()
            for (key, value) in jsonMap {
                if let jsParam = V(json: value) {
                    contents[key] = jsParam
                } else {
                    return nil
                }
            }
            self.contents = contents
        } else {
            return nil
        }
    }

    subscript(index: String) -> V? {
        return contents[index]
    }

    public func index(after index: DictionaryIndex<String, V>) -> DictionaryIndex<String, V> {
        return contents.index(after: index)
    }

    typealias Element = Dictionary<String, V>.Element
    typealias Index = Dictionary<String, V>.Index

    var startIndex: Index {
        return contents.startIndex
    }

    var endIndex: Index {
        return contents.endIndex
    }

    subscript(index: Index) -> Element {
        return contents[index]
    }
}

func toDictionary(_ object: JSObject<JSAny>) -> [String: Any] {
    var dictionary = [String: Any]()
    for (key, value) in object {
        dictionary[key] = value.any
    }
    return dictionary
}

enum JSOptional<Wrapped>: JSParameter where Wrapped: JSParameter {
    case none
    case some(Wrapped)

    var content: Wrapped? {
        switch self {
        case .none:
            return nil
        case .some(let wrapped):
            return wrapped
        }
    }

    init?(json: Any?) {
        switch json {
        case .none:
            self = .none
        case .some(_ as NSNull):
            self = .none
        case .some(let data):
            if let wrapped = Wrapped(json: data) {
                self = .some(wrapped)
            } else {
                return nil
            }
        }
    }
}

protocol JSPlainParameter: JSParameter {
}

extension JSPlainParameter {
    init?(json: Any?) {
        if let value = json as? Self {
            self = value
        } else {
            return nil
        }
    }
}

extension UInt: JSPlainParameter {
}

extension String: JSPlainParameter {
}

protocol JSObjectConvertibleParameter: JSParameter {
    init?(object: [AnyHashable: Any])
}

extension JSObjectConvertibleParameter {
    init?(json: Any?) {
        if let jsonObject = json as? [AnyHashable: Any] {
            self.init(object: jsonObject)
        } else {
            return nil
        }
    }
}
