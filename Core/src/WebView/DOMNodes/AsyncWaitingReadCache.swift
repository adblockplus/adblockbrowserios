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
 An asynchronous cache with special properties
 - gets wait after any sets (have lower priority)
 - gets are tried once right away and if not successful,
 - gets will wait for a set of the wanted key, or a configured timeout

 Can act as a buffer between slow/deferred producer
 and eager (but still asynchronous) consumer.
 */
typealias KeyType = String

final class AsyncWaitingReadCache<ValueType> where ValueType: AnyObject {
    let queue: OperationQueue
    private let dispatchQueue: DispatchQueue
    private let getterTimeout: Double
    private let cache: CacheResolver<NSString, ValueType>

    /// - Parameter getterTimeout: number = ns to wait, 0 means just a dispatch
    required init(getterTimeout: Double) {
        self.queue = OperationQueue()
        self.queue.maxConcurrentOperationCount = 1
        self.dispatchQueue = DispatchQueue(label: "AsyncWaitingReadCache")
        self.queue.underlyingQueue = dispatchQueue
        self.getterTimeout = getterTimeout
        // This ideally goes to constructor in the spirit of IOC but now it would induce
        // further ObjC compatibility hacking
        self.cache = CacheResolver()
    }

    /// setter of higher priority
    func set(_ key: KeyType, value: ValueType) {
        let operation = BlockOperation { [cache] () in
            // must hold strongly because even if this instance wants to get dropped,
            // the waiters must get called
            cache.set(key as NSString, value: value)
        }
        operation.queuePriority = .high
        queue.addOperation(operation)
    }

    /// getter of lower priority
    func getAsync(_ key: KeyType, valueCompletion: @escaping (_: ValueType?) -> Void) {
        getAsync(key, priority: .normal, valueCompletion: valueCompletion)
    }

    // complete clear with low priority - can wait after any get/set
    func clear() {
        let operation = BlockOperation { [cache] () in
            cache.clear()
        }
        operation.queuePriority = .low
        queue.addOperation(operation)
    }

    /**
     Use case: an existing URL string key being redirected to another URL
     Not very generic API but needed as higher priority despite having a getter inside.
     */
    func cloneValue(of key: KeyType, toKey: KeyType) {
        getAsync(key, priority: .high) { [cache] value in
            if let value = value {
                cache.set(toKey as NSString, value: value)
            }
        }
    }

    private func getAsync(_ key: KeyType,
                          priority: Operation.QueuePriority,
                          valueCompletion: @escaping (_ : ValueType?) -> Void) {
        let operation = BlockOperation { [dispatchQueue, cache, getterTimeout] () in
            // if there was no resolver created, cache get succeeded right away
            if let resolver = cache.getAsync(key as NSString, resolverFunction: valueCompletion) {
                dispatchQueue.asyncAfter(deadline: DispatchTime.now() + getterTimeout) { [weak cache] () in
                    cache?.reject(resolver)
                }
            }
        }
        operation.queuePriority = priority
        queue.addOperation(operation)
    }
}
