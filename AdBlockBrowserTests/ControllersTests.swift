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

@testable import AdblockBrowser
import RxSwift
import UIKit
import XCTest

struct ExtensionControlMock: ExtensionControlComponents {
    let extensionFacade: ABPExtensionFacadeProtocol

    init(_ facade: ABPExtensionFacadeProtocol) {
        extensionFacade = facade
    }
}

class ABPExtensionFacadeMock: NSObject, ABPExtensionFacadeProtocol {
    @objc dynamic var extensionEnabled: Bool = false

    var sites = [URL: Bool]()
    var accessedSites = [URL: Bool]()

    func getAvailableSubscriptions(_ retvalHandler: @escaping ([AvailableSubscription]?, Error?) -> Void) {}

    func getListedSubscriptions(_ retvalHandler: @escaping ([String: ListedSubscription]?, Error?) -> Void) {}

    func subscription(_ subscription: ABPSubscriptionBase, enabled: Bool) {}

    func addSubscription(_ subscription: ABPSubscriptionBase) {}

    func removeSubscription(_ subscription: ABPSubscriptionBase) {}

    func isAcceptableAdsEnabled(_ retvalHandler: @escaping (Bool, Error?) -> Void) {}

    func setAcceptableAdsEnabled(_ enabled: Bool) {}

    func isSiteWhitelisted(_ url: String, retvalHandler: @escaping (Bool, Error?) -> Void) {
        for urls in sites where url == urls.0.absoluteString {
                accessedSites[urls.0] = true
                retvalHandler(urls.1, nil)
                return
        }

        retvalHandler(false, nil)
    }

    func whitelistSite(_ url: String, whitelisted: Bool, completion: ((Error?) -> Void)?) {}

    func whitelistDomain(_ domainName: String, whitelisted: Bool, completion: ((Error?) -> Void)?) {}

    func removeWhitelistingFilter(_ hostname: String) {}

    func getWhitelistedSites(_ retvalHandler: @escaping ([String]?, Error?) -> Void) {
        retvalHandler(["t.idnes.cz", "root.cz"], nil)
    }

    func getExtensionVersion(_ retvalHandler: @escaping (Result<String>) -> Void) {
        retvalHandler(.success("1.2.3"))
    }
}

class ControllersTests: XCTestCase {
    var components: ControllerComponents!
    var storyboard: UIStoryboard!

    override func setUp() {
        super.setUp()
        let assembly = BrowserAssembly()
        components = try? assembly.assemble()
        storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
    }

    func testBookmarksController() {
        let isGhostModeEnabled = Variable(false)
        let browserSignalSubject = PublishSubject<BrowserControlSignals>()
        let viewModel = BookmarksViewModel(components: components,
                                           isGhostModeEnabled: isGhostModeEnabled,
                                           browserSignalSubject: browserSignalSubject)
        let controller = loadController(with: viewModel) as BookmarksViewController
        controller.view.updateConstraintsIfNeeded()
        controller.view.layoutIfNeeded()

        _ = controller.tableView!.dequeueReusableCell(withIdentifier: BookmarksViewController.cellIdentifier)!
    }

    func testDashboardViewController() {
        let isGhostModeEnabled = Variable(false)
        let browserSignalSubject = PublishSubject<BrowserControlSignals>()
        let viewModel = DashboardViewModel(components: components,
                                           isGhostModeEnabled: isGhostModeEnabled,
                                           browserSignalSubject: browserSignalSubject)
        let controller = loadController(with: viewModel) as DashboardViewController
        controller.view.updateConstraintsIfNeeded()
        controller.view.layoutIfNeeded()
    }

    func testTabsViewController() {
        let tabs = TabsModel(window: components.chrome.mainWindow)
        let currentTabsModel = Variable(tabs)
        let isGhostModeEnabled = Variable(false)
        let isShown = Variable(false)
        let viewModel = TabsViewModel(components: components,
                                      currentTabsModel: currentTabsModel,
                                      isGhostModeEnabled: isGhostModeEnabled,
                                      isShown: isShown)
        let controller = loadController(with: viewModel) as TabsViewController
        controller.view.updateConstraintsIfNeeded()
        controller.view.layoutIfNeeded()

        let cells: [TabsViewController.CellIdentifiers] = [.addNewTabCell, .tabViewCell, .tipCell]
        for cell in cells {
            _ = controller.tableView.dequeueReusableCell(withIdentifier: cell)!
        }
    }

    func loadController<Controller: UIViewController>(_ name: String) -> Controller? {
        let controller = storyboard.instantiateViewController(withIdentifier: name) as? Controller
        XCTAssert(controller != nil, "Controller has not been found")
        _ = controller?.view
        return controller
    }

    func loadController<Controller: UIViewController>(with viewModel: Controller.ViewModelEx) -> Controller
        where Controller: ViewModelControllerEx {
            let name = String(describing: Controller.self)
            // swiftlint:disable:next force_cast
            let controller = storyboard.instantiateViewController(withIdentifier: name) as! Controller
            controller.initialize(with: viewModel, source: nil)
            if #available(iOS 9.0, *) {
                controller.loadViewIfNeeded()
            } else {
                // Fallback on earlier versions
            }
            _ = controller.view
            return controller
    }
}
