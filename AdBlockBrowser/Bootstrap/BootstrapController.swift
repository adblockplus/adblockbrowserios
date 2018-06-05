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

/**
 View controller for Bootstrap storyboard. The storyboard contains initial screen
 which is equal to the launch screen and optionally welcome sequence screens.
 The controller is a listener to welcome sequence progress events.
 There is two functional scenarios:
 1. welcome sequence is displayed and finish handler is called asynchronously
 2. welcome sequence is not displayed and finish handler is called immediately
    after the assembling
 */
import Foundation

class BootstrapController: UIViewController, WelcomeProgressDelegate {
    var changeRootController: ((UIViewController) -> Void)?

    // a closure over final changeRootController to avoid needing BrowserController as explicit property
    fileprivate var browserReadyClosure: (() -> Void)?

    fileprivate let willShowWelcome = WelcomeController.shouldShowWelcomeController()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if willShowWelcome {
            if let welcomeStart = storyboard?.instantiateViewController(withIdentifier: "Welcome1") as? WelcomeController {
                welcomeStart.progressDelegate = self
                changeRootController?(welcomeStart)
            }
        }
    }

    #if DEVBUILD_FEATURES
    private static let failBootstrapKey = "FailOnNextBootstrap"

    static var failOnNextBootstrap: Bool {
        get {
            return UserDefaults.standard.bool(forKey: failBootstrapKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: failBootstrapKey)
            UserDefaults.standard.synchronize()
        }
    }
    #endif

    /**
     The components are provided through callback not retval intentionally.
     1. the assembly may be asynchronous, even if it is not currently
     2. components must be ready before changing root controller. Invoking callbacks in correct order
        is cleaner than dispatching the root changing so that it would happen after retval.

     @note onFinished retval gives the caller opportunity to add optional components
     before it's assigned to BrowserController. After that point, ControllerComponentsInjectable
     is set in stone for the whole storyboard dependency tree.
     */
    func makeComponents(onFinished: @escaping (ControllerComponents) -> ControllerComponents?, onError: @escaping (BootstrapError) -> Void)
    {
        preloadControllerClasses()

        let storyboard = UIStoryboard(name: "Browser", bundle: Bundle.main)

        guard let browserController = storyboard.instantiateInitialViewController() as? BrowserContainerViewController else {
            // This is synchronous, hence it could throw instead of callback. But it would
            // complicate the caller code, because catch block and error block have to
            // do the same thing. Let's make the API consistent.
            onError(.browserControllerInstantiation)
            return
        }

        let assembly = BrowserAssembly()

        DispatchQueue.main.async {
            var components: ControllerComponents
            do {
                components = try assembly.assemble()
                #if DEVBUILD_FEATURES
                    if BootstrapController.failOnNextBootstrap {
                        BootstrapController.failOnNextBootstrap = false
                        throw BootstrapError.devbuildTesting
                    }
                #endif
            } catch let error as BootstrapError {
                onError(error)
                return
            } catch {
                // assemble() throws only BootstrapErrors but Swift cannot express that
                onError(.unknown)
                return
            }

            components.browserController = browserController
            // components must be ready before changing root controller
            if let updatedComponents = onFinished(components) {
                components = updatedComponents
            }
            browserController.viewModel = BrowserContainerViewModel(components: components)
            self.scheduleShowBrowser(controller: browserController)
        }
    }

    private func scheduleShowBrowser(controller: UIViewController) {
        if !willShowWelcome {
            // welcome screens are not running, call handler right away
            changeRootController?(controller)
        } else {
            browserReadyClosure = {
                self.changeRootController?(controller)
            }
        }
    }
}

// WelcomeProgressDelegate

extension BootstrapController {
    func next() {
        if let welcomeNext = storyboard?.instantiateViewController(withIdentifier: "Welcome2") as? WelcomeController {
            welcomeNext.progressDelegate = self
            changeRootController?(welcomeNext)
        }
    }

    func finished() {
        browserReadyClosure?()
        browserReadyClosure = nil // let the browser reference go
    }
}

///
/// Subclasses of Swift generic classes need to preloaded in order to be created by storyboard.
/// Otherwise Objc runtime is having issues to load them correctly.
///
func preloadControllerClasses() {
    _ = NSStringFromClass(BookmarksViewController.self)
    _ = NSStringFromClass(BrowserViewController.self)
    _ = NSStringFromClass(BrowserContainerViewController.self)
    _ = NSStringFromClass(DashboardViewController.self)
    _ = NSStringFromClass(EditBookmarkViewController.self)
    _ = NSStringFromClass(HistoryViewController.self)
    _ = NSStringFromClass(TabsViewController.self)

    // Settings

    _ = NSStringFromClass(AdblockingSettingsViewController.self)
    _ = NSStringFromClass(ClearDataViewController.self)
    _ = NSStringFromClass(CrashReportsViewController.self)
    _ = NSStringFromClass(DevSettingsViewController.self)
    _ = NSStringFromClass(ExceptionsViewController.self)
    _ = NSStringFromClass(TopSettingsViewController.self)
    _ = NSStringFromClass(SearchEnginesViewController.self)
    _ = NSStringFromClass(SubscriptionsViewController.self)
}
