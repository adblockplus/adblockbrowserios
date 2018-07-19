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

public enum Result<T> {
    case success(T)
    case failure(Error)

    var isSuccess: Bool {
        if case .success(_) = self {
            return true
        } else {
            return false
        }
    }
}

/**
 Verifying true non-nilness of function parameters coming from legacy
 iOS delegate calls bridged (but not checked) to non-optional Swift types.
 It looks silly indeed, but it does one important thing: forcing the parameter
 to be optional, so that the nil equality is compilable.
 */
public func isOptionalObjectNil(_ testable: AnyObject?) -> Bool {
    return testable == nil
}

typealias StandardCompletion = (Result<Any?>) -> Void

final class MultipleResultsListener<T> {
    var results = [Result<T>]()
    let completion: ([Result<T>]) -> Void

    init(completion: @escaping ([Result<T>]) -> Void) {
        self.completion = completion
    }

    deinit {
        let completion = self.completion
        let results = self.results
        DispatchQueue.main.async {
            completion(results)
        }
    }

    func createCompletionListener() -> ((Result<T>) -> Void) {
        assert(Thread.isMainThread)
        results.append(.failure(NSError(message: "Completion not fulfilled")))
        let index = results.count - 1
        return { result in
            self.results[index] = result
        }
    }
}

func completionHandler<T>(from handler: @escaping ((Result<T>) -> Void)) -> ((Error?, T) -> Void) {
    return { error, result in
        if let error = error {
            handler(.failure(error))
        } else {
            handler(.success(result))
        }
    }
}

func completionHandler(from handler: @escaping ((Result<Any?>) -> Void)) -> ((Error?, Any?
    ) -> Void) {
    return { error, result in
        if let error = error {
            handler(.failure(error))
        } else {
            handler(.success(result))
        }
    }
}
