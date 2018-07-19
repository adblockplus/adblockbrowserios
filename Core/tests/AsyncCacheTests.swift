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
@testable import KittCore
import XCTest

class AsyncCacheTests: XCTestCase {
    func testCacheIntegrity() {
        let cache = AsyncWaitingReadCache<NSString>(getterTimeout: 1)

        var keys = Set<String>()
        var loadedKeys = Set<String>()
        for keyID in 0..<1000 {
            let key = "key-\(keyID)"
            keys.insert(key)
            cache.getAsync(key, valueCompletion: watch { key in
                if let key = key as String? {
                    loadedKeys.insert(key)
                }
            })
        }

        assert(loadedKeys.isEmpty)

        for key in keys {
            cache.set(key, value: key as NSString)
        }

        cache.queue.waitUntilAllOperationsAreFinished()
        assert(keys == loadedKeys)
    }

    func testCacheThreadSafety() {
        let queue = OperationQueue()
        queue.isSuspended = true
        queue.maxConcurrentOperationCount = 10

        let cache = AsyncWaitingReadCache<NSString>(getterTimeout: 0.1)
        var cacheShouldBeEmpty = false

        for _ in 0..<10 {
            queue.addOperation {
                for _ in 0..<10000 {
                    let key = "key-\(arc4random_uniform(10000))"
                    if arc4random_uniform(2) > 0 {
                        cache.set(key, value: key as NSString)
                    } else {
                        cache.getAsync(key, valueCompletion: watch { value in
                            assert(!cacheShouldBeEmpty)
                            assert(value == nil || key == value as String?)
                        })
                    }
                }
            }
        }

        queue.isSuspended = false

        // Wait until all operation are finished
        queue.waitUntilAllOperationsAreFinished()
        cache.queue.waitUntilAllOperationsAreFinished()
        // Let cleanup timers to be executed
        Thread.sleep(forTimeInterval: 2.0)
        // Now, cache must be empty
        cacheShouldBeEmpty = true
        cache.clear()
        // Wait for clear operaiton
        cache.queue.waitUntilAllOperationsAreFinished()
    }

    func testCallbackCompletion() {
        var cache = Optional.some(AsyncWaitingReadCache<NSString>(getterTimeout: 0.5))
        cache?.queue.addOperation {
            Thread.sleep(forTimeInterval: 2)
        }

        // Assign waiters
        for index in 0..<16 {
            let key = "key-\(index)"
            let error = expectation(description: "Expectation-\(index)")
            cache?.getAsync(key, valueCompletion: watch { value in
                assert(value == nil)
                error.fulfill()
            })
        }

        // Flush cache and remove waiters
        cache = nil
        waitForExpectations(timeout: 5) { error in
            assert(error == nil)
        }
    }
}

final class CallbackWatcher<T> {
    private var callback: ((T?) -> Void)?

    init(callback: @escaping (T?) -> Void) {
        self.callback = callback
    }

    deinit {
        assert(callback == nil, "Callback was not called")
    }

    func invoke(input: T?) {
        assert(callback != nil, "Callback has been called multiple times")
        callback?(input)
        callback = nil
    }
}

func watch<T>(_ callback: @escaping (T?) -> Void) -> ((T?) -> Void) {
    return CallbackWatcher(callback: callback).invoke
}
