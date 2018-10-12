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

import UIKit

@UIApplicationMain
@objc
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    // must be public for XCTest access
    var components: ControllerComponents?
    // browser is ready only after potential welcome screens, so it's asynchronous event
    typealias BrowserReadyHandler = (BrowserContainerViewController) -> Void
    var browserReadyHandlers = [BrowserReadyHandler]()
    // Dedicated container for logging and crash reporting
    fileprivate let debugReporting = DebugReporting()

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return Settings.testLaunchOptions(launchOptions, contains: nil)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        var url: NSURL?
        guard Settings.testLaunchOptions(launchOptions, contains: &url) else {
            return false
        }

        guard let bootstrapController = window?.rootViewController as? BootstrapController else {
            inhibitApp(with: .rootControllerInstantiation, failureController: nil)
            return false
        }
        bootstrapController.changeRootController = { controller in
            self.changeRootController(controller) {
                if let browser = self.components?.browserController {
                    self.browserReadyHandlers.forEach {
                        $0(browser)
                    }
                }
            }
        }
        bootstrapController.makeComponents(
            onFinished: {
                self.components = $0
                self.components?.eventHandlingStatusAccess = self.debugReporting.statusAccess
                self.components?.debugReporting = self.debugReporting
                return self.components
            },
            onError: {
                self.inhibitApp(with: $0, failureController: bootstrapController)
            }
        )
        return true
    }

    private func inhibitApp(with error: BootstrapError, failureController: UIViewController?) {
        debugReporting.confirmAppAbortReport(with: error, modalPresentingController: window?.rootViewController) {
            guard
                let failureController = failureController,
                let ctrl = failureController.storyboard?.instantiateViewController(withIdentifier: "Failure") else {
                    return
            }
            self.changeRootController(ctrl)
        }
    }

    // deprecated since iOS9
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return tryOpenURL(url)
    }

    // recommended since iOS9
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return tryOpenURL(url)
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Chrome.sharedInstance.prune()
    }

    fileprivate func tryOpenURL(_ url: URL) -> Bool {
        var resultingURL: NSURL?
        guard Settings.testOpenability(of: url, resultingURL: &resultingURL) else {
            return false
        }

        guard let resultingURL2 = resultingURL as URL? else {
            return false
        }
        let openerBlock = { (opener: BrowserControlDelegate) in
            opener.showNewTab(with: resultingURL2, fromSource: nil)
        }

        if let browser = components?.browserController {
            // The browser is already through welcome screens
            openerBlock(browser)
        } else {
            // Wait for the browser go through welcome screens
            browserReadyHandlers.append(openerBlock)
        }
        return true
    }

    ///
    /// Presents view controller with custom "push" animation.
    ///
    fileprivate func changeRootController(_ viewController: UIViewController, completion: (() -> Void)? = nil) {
        if let _: UIView = window?.rootViewController?.view {
            if let toView: UIView = viewController.view {

                // Forces controller's view to relayout for given screen size and orientation.
                // This is especially required when phone screen is the landscape mode. Without this hack,
                // views are animated in wrong orientation.
                let rootViewController = window?.rootViewController
                window?.rootViewController = viewController
                window?.rootViewController = rootViewController

                window?.addSubview(toView)

                var frame = toView.frame
                frame.origin.x = frame.size.width
                toView.frame = frame

                UIView.animate(withDuration: 0.4, animations: { () in
                    var frame = toView.frame
                    frame.origin.x = 0
                    frame.origin.y = 0
                    toView.frame = frame

                    return
                }, completion: { _ -> Void in
                    self.window?.rootViewController = viewController
                    completion?()
                })
                return
            }
        }
        window?.rootViewController = viewController
    }
}
