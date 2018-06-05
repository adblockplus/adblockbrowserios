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
    func firstOfType<U>() -> U? {
        for element in self {
            if let result = element as? U {
                return result
            }
        }
        return nil
    }
}

extension NSObject {
    func setObserverTo<T: NSObject>(_ property: inout T?, _ newValue: T?, _ keyPaths: [String], _ options: NSKeyValueObservingOptions) {
        for keyPath in keyPaths {
            property?.removeObserver(self,
                                     forKeyPath: keyPath,
                                     context: nil)
        }
        property = newValue
        for keyPath in keyPaths {
            property?.addObserver(self,
                                  forKeyPath: keyPath,
                                  options: options,
                                  context: nil)
        }
    }
}

func setObservedProperty<T: NSObject>(_ property: inout T?, _ newValue: T?, _ observer: NSObject, _ keyPaths: [String]) {
    for keyPath in keyPaths {
        property?.removeObserver(observer,
                                 forKeyPath: keyPath,
                                 context: nil)
    }
    property = newValue
    for keyPath in keyPaths {
        property?.addObserver(observer,
                              forKeyPath: keyPath,
                              options: [.new, .initial],
                              context: nil)
    }
}

/// Check if value is in range of expected allValues. Prevention from certain unexpected behavior
/// of NSFetchedResultsControllerDelegate. For more context, see the places of usage.
func isValueValid<T: RawRepresentable>(_ value: T, allValues: [T]) -> Bool where T.RawValue: Equatable {
    if #available(iOS 9.0, *) {
        return true
    } else {
        return allValues.contains { allValuesValue -> Bool in
            return allValuesValue.rawValue == value.rawValue
        }
    }
}

public enum FailableResult<Result, Error> {
    case success(Result)
    case failure(Error)
}
