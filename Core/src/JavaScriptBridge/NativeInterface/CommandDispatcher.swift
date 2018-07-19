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

struct CommandDispatcherContext {
    let `extension`: BrowserExtension
    let chrome: Chrome
    let source: WebViewFacade
    let sourceFrame: WebKitFrame?

    var sourceTab: ChromeTab? {
        return (source as? SAContentWebView)?.chromeTab
    }
    var sourceWindow: ChromeWindow? {
        return sourceTab?.window
    }
}

protocol HandlerFactory {
    associatedtype Handler

    func create(_ context: CommandDispatcherContext) -> Handler
}

public final class CommandDispatcher: NSObject {
    fileprivate typealias InternalHandler = (CommandDispatcherContext, Any?, @escaping StandardCompletion) throws -> Bool

    fileprivate var internalHandlers = [String: [InternalHandler]]()

    init(handlers: [String: (CommandDispatcher) -> Void]) {
        super.init()
        for (_, register) in handlers {
            register(self)
        }
    }

    // MARK: - Interface

    // swiftlint:disable:next function_parameter_count
    func dispatch(_ command: String,
                  _ parameters: Any?,
                  _ extension: BrowserExtension,
                  _ webView: WebViewFacade,
                  _ sourceFrame: WebKitFrame?,
                  _ completion: @escaping StandardCompletion) {
        if let handlers = internalHandlers[command] {
            let context = CommandDispatcherContext(extension: `extension`,
                                                   chrome: Chrome.sharedInstance,
                                                   source: webView,
                                                   sourceFrame: sourceFrame)

            for handler in handlers {
                do {
                    if try handler(context, parameters, completion) {
                        return
                    }
                } catch let error {
                    completion(.failure(error))
                    return
                }
            }
            completion(.failure(NSError(code: .commandParametersDidNotMatch, message: "Command parameters did match")))
        } else {
            completion(.failure(NSError(code: .commandNotFound, message: "Command has not been found")))
        }
    }

    func register<F>
        (_ factory: F, handler: @escaping (F.Handler) -> (() throws -> Any?), forName name: String) where F: HandlerFactory {
        register({context, _, completion in
            let result = try handler(factory.create(context))()
            completion(.success(result))
            return true
        }, forName: name)
    }

    func register<F, T1>
        (_ factory: F, handler: @escaping (F.Handler) -> ((T1) throws -> Any?), forName name: String) where F: HandlerFactory, T1: JSParameter {
        register({context, output, completion in
            if let outputArray = convertToArray(output, expectedLength: 1),
                let output1 = T1(json: outputArray[0]) {
                let result = try handler(factory.create(context))(output1)
                completion(.success(result))
                return true
            }
            return false
        }, forName: name)
    }

    func register<F, T1>
        (_ factory: F, handler: @escaping (F.Handler) -> ((T1, StandardCompletion?) throws -> Void), forName name: String)
        where F: HandlerFactory, T1: JSParameter {
        register({context, output, completion in
            if let outputArray = convertToArray(output, expectedLength: 1),
                let output1 = T1(json: outputArray[0]) {
                try handler(factory.create(context))(output1, completion)
                return true
            }
            return false
        }, forName: name)
    }

    func register<F, T1, T2>
        (_ factory: F, handler: @escaping (F.Handler) -> ((T1, T2) throws -> Any?), forName name: String)
        where F: HandlerFactory, T1: JSParameter, T2: JSParameter {
        register({context, output, completion in
            if let outputArray = convertToArray(output, expectedLength: 2),
                let output1 = T1(json: outputArray[0]),
                let output2 = T2(json: outputArray[1]) {
                let result = try handler(factory.create(context))(output1, output2)
                completion(.success(result))
                return true
            }
            return false
        }, forName: name)
    }

    func register<F, T1, T2>
        (_ factory: F, handler: @escaping (F.Handler) -> ((T1, T2, StandardCompletion?) throws -> Void), forName name: String)
        where F: HandlerFactory, T1: JSParameter, T2: JSParameter {
        register({context, output, completion in
            if let outputArray = convertToArray(output, expectedLength: 2),
                let output1 = T1(json: outputArray[0]),
                let output2 = T2(json: outputArray[1]) {
                try handler(factory.create(context))(output1, output2, completion)
                return true
            }
            return false
        }, forName: name)
    }

    func register<F, T1, T2, T3>
        (_ factory: F, handler: @escaping (F.Handler) -> ((T1, T2, T3) throws -> Any?), forName name: String)
        where F: HandlerFactory, T1: JSParameter, T2: JSParameter, T3: JSParameter {
        register({context, output, completion in
            if let outputArray = convertToArray(output, expectedLength: 3),
                let output1 = T1(json: outputArray[0]),
                let output2 = T2(json: outputArray[1]),
                let output3 = T3(json: outputArray[2]) {
                let result = try handler(factory.create(context))(output1, output2, output3)
                completion(.success(result))
                return true
            }
            return false
        }, forName: name)
    }

    // MARK: - fileprivate

    fileprivate func register(_ internalHandler: @escaping InternalHandler, forName name: String) {
        var handlers = internalHandlers[name] ?? []
        handlers.append(internalHandler)
        internalHandlers[name] = handlers
    }
}

private func convertToArray(_ output: Any?, expectedLength: Int) -> [Any]? {
    if let uwOutput = output as? [Any], uwOutput.count == expectedLength {
        return uwOutput
    } else {
        return nil
    }
}
