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

/**
 Any kind of resolving FunctionResolvable (resolve or reject) must be called _AFTER_
 the object is removed from the waiters storage! The resolving function may be calling
 a get/set cache function again, which results in an endless invocation cycle.
 */
typealias ResolverFunction<ValueType> = (_: ValueType?) -> Void

private var creationOrdinal: Int = 0

/// This implementation is backed by NSCache and stores the waiters in array
/// (not ideal design as it needs index lookup when rejecting a single Resolvable
final class CacheResolver<KeyType, ValueType>
    where KeyType: AnyObject & Hashable, ValueType: AnyObject {
    private let cache = NSCache<KeyType, ValueType>()
    private var waiters = [KeyType: ContiguousArray<(id: Int, resolver: ResolverFunction<ValueType>)>]()

    typealias Rejector = (KeyType, Int)

    deinit {
        removeAndRejectAllWaiters()
    }

    func set(_ key: KeyType, value: ValueType) {
        cache.setObject(value, forKey: key)
        // Call all waiters on this key, and remove
        if let waitersArray = waiters[key] {
            waiters.removeValue(forKey: key)
            for waiter in waitersArray {
                waiter.resolver(value)
            }
        }
    }

    func get(_ key: KeyType) -> ValueType? {
        return cache.object(forKey: key)
    }

    func getAsync(_ key: KeyType, resolverFunction: @escaping ResolverFunction<ValueType>) -> Rejector? {
        // try immediate first
        if let value = get(key) {
            resolverFunction(value)
            return nil
        }

        creationOrdinal += 1
        let identifier = creationOrdinal
        let waiter = (id: identifier, resolver: resolverFunction)

        if waiters[key] == nil {
            waiters[key] = [waiter]
        } else {
            waiters[key]?.append(waiter)
        }

        return (key, waiter.id)
    }

    func reject(_ resolver: Rejector) {
        let key = resolver.0
        // find, reject, remove
        if let index = waiters[key]?.index(where: { $0.id == resolver.1 }) {
            if let waiter = waiters[key]?[index] {
                waiters[key]?.remove(at: index)
                // if it was the last one, remove the key completely
                if waiters[key]?.isEmpty ?? false {
                    waiters.removeValue(forKey: key)
                }
                waiter.resolver(nil)
            }
        }
    }

    func clear() {
        cache.removeAllObjects()
        removeAndRejectAllWaiters()
    }

    private func removeAndRejectAllWaiters() {
        let allWaiters = waiters.flatMap { $1 }
        waiters.removeAll()
        for waiter in allWaiters {
            waiter.resolver(nil)
        }
    }
}
