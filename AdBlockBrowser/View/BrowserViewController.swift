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

import RxCocoa
import RxSwift
import UIKit

private let addressBarAnimationDuration = 0.4
let webViewCenterXConstraintIdentifier = "centerXConstraint"
let webViewCenterYConstraintIdentifier = "centerYConstraint"

// swiftlint:disable:next type_body_length
final class BrowserViewController: ViewController<BrowserViewModel>,
    UIWebViewDelegate,
    UITextFieldDelegate,
    UIGestureRecognizerDelegate,
    UINavigationControllerDelegate,
    BrowserControlDelegate,
    ActiveContentViewDelegate,
    DownloadsUIFeedbackDelegate {
    var scrollViewController = ScrollViewController()

    // MARK: - Outlets

    @IBOutlet weak var menuControlButton: UIButton?
    @IBOutlet weak var bookmarkButton: UIButton?

    @IBOutlet weak var tapGestureRecognizer: UITapGestureRecognizer?
    @IBOutlet weak var viewForWebView: WebViewContainer?
    @IBOutlet weak var topConstraint: NSLayoutConstraint?
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint?
    @IBOutlet weak var webViewTopConstraint: NSLayoutConstraint?

    @IBOutlet weak var progressBar: UIProgressView?
    @IBOutlet weak var topAddressBar: UIView?
    @IBOutlet weak var autocompleteContainer: UIView?
    @IBOutlet weak var viewForWebViewGestureRecognizer: UITapGestureRecognizer?

    @IBOutlet weak var menuBottomConstraint: NSLayoutConstraint?
    @IBOutlet weak var popupBottomConstraint: NSLayoutConstraint?
    @IBOutlet weak var tabsHeightConstraint: NSLayoutConstraint?
    @IBOutlet weak var menuView: UIView?
    @IBOutlet weak var tabsView: UIView?
    @IBOutlet weak var menuTriangle: TriangleView?
    @IBOutlet weak var menuTriangleTopConstraint: TwoStatesConstraint?
    @IBOutlet weak var statusBar: UIView?
    @IBOutlet weak var statusBarX: UIView?
    @IBOutlet weak var topRuler: UIView?
    @IBOutlet weak var bottomRuler: UIView?

    @IBOutlet weak var containerView: UIView?
    @IBOutlet weak var tabsContainerView: UIView?

    // MARK: - Address bar

    @IBOutlet weak var addressLabelLeftConstraint: NSLayoutConstraint?
    @IBOutlet weak var addressLabelRightConstraint: TwoStatesConstraint?
    @IBOutlet weak var addressBar: UIView?
    @IBOutlet weak var addressField: AutocompleteTextField?
    @IBOutlet weak var addressLabel: UILabel?
    @IBOutlet weak var addressBarConstraint: NSLayoutConstraint?
    @IBOutlet weak var addressLabelConstraint: NSLayoutConstraint?
    @IBOutlet weak var addressBarLeadingEdgesConstraint: NSLayoutConstraint?
    @IBOutlet weak var reloadButton: UIButton?
    @IBOutlet weak var cancelButton: UIButton?
    @IBOutlet weak var addressBarTapGestureRecognizer: UITapGestureRecognizer?

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func observe(viewModel: BrowserViewModel) {
        let isGhostModeEnabled = viewModel.isGhostModeEnabled.asObservable()
        let isAddressBarEdited = viewModel.isAddressBarEdited.asObservable()
        let searchPhrase = viewModel.searchPhrase.asObservable().distinctUntilChanged(==)

        viewModel.activeTab.asDriver()
            .drive(onNext: { [weak self] tab in
                self?.update(activeTab: tab)
            })
            .addDisposableTo(disposeBag)

        viewModel.url.asDriver()
            .drive(onNext: { [weak self] current in
                self?.update(url: current)
                self?.bookmarkButton?.isHidden = current == nil
                self?.reloadButton?.isHidden = current == nil
            })
            .addDisposableTo(disposeBag)

        viewModel.isMenuViewShown.asDriver()
            .drive(onNext: { [weak self] isShown in
                self?.menuControlButton?.tintColor = isShown ? .abbBlue : .abbSlateGray

                UIView.animate(withDuration: animationDuration) {
                    self?.menuBottomConstraint?.priority = isShown
                        ? UILayoutPriority.defaultHigh
                        : UILayoutPriority.defaultLow
                    self?.menuTriangleTopConstraint?.setState(!isShown)
                    self?.view.layoutIfNeeded()
                }

                self?.tapGestureRecognizer?.isEnabled = isShown
            })
            .addDisposableTo(disposeBag)

        viewModel.isBookmarked.asDriver()
            .drive(onNext: { [weak self] isBookmarked in
                let image = isBookmarked ? #imageLiteral(resourceName: "FaviconActive") : #imageLiteral(resourceName: "FaviconInactive")
                self?.bookmarkButton?.setImage(image, for: .normal)
            })
            .addDisposableTo(disposeBag)

        viewModel.isShareDialogPresented.asDriver()
            .scan((false, false), accumulator: { ($1, $0.0) })
            .drive(onNext: { [weak self] value in
                let (current, previous) = value
                guard current && !previous, let webView = self?.webView else {
                    return
                }
                self?.presentActivityViewController(webView.url as NSURL?,
                                                    title: webView.documentTitle,
                                                    anchorView: self?.menuControlButton,
                                                    webView: webView) { _ in
                                                        self?.viewModel?.isShareDialogPresented.value = false
                }
            })
            .addDisposableTo(disposeBag)

        viewModel.progress.asDriver()
            .drive(onNext: { [weak self] progress in
                self?.update(progress: progress)
            })
            .addDisposableTo(disposeBag)

        viewModel.isTabsViewShown.asDriver()
            .distinctUntilChanged()
            .drive(onNext: { [weak self] isShown in
                UIView.animate(withDuration: animationDuration) {
                    self?.popupBottomConstraint?.priority = UILayoutPriority(rawValue: UILayoutPriority.RawValue(isShown ? 750 : 250))
                    self?.view.layoutIfNeeded()
                }

                if !isShown {
                    self?.webView?.updatePreview()
                }
            })
            .addDisposableTo(disposeBag)

        viewModel.signalSubject
            .subscribe(onNext: { [weak self] signal in
                switch signal {
                case .goBack:
                    self?.goBack()
                case .goForward:
                    self?.goForward()
                case .presentBookmarks:
                    if self?.presentedViewController == nil {
                        self?.performSegue(withIdentifier: "ShowBookmarksSegue", sender: nil)
                    }
                case .presentEditBookmark(let bookmark):
                    if self?.presentedViewController == nil {
                        self?.performSegue(withIdentifier: "EditBookmarkSegue", sender: bookmark)
                    }
                case .dismissModal:
                    if self?.presentedViewController != nil {
                        self?.viewModel?.bookmarksViewWillBeDismissed.onNext(())
                        self?.dismiss(animated: true, completion: nil)
                    }
                }
            })
            .addDisposableTo(disposeBag)

        searchPhrase
            .subscribe(onNext: { [weak self] searchPhrase in
                self?.viewForWebViewGestureRecognizer?.isEnabled = searchPhrase != nil
            })
            .addDisposableTo(disposeBag)

        viewModel.toolbarProgress.asObservable()
            .subscribe(onNext: { [weak self] progress in
                self?.topConstraint?.constant = -44 * progress
                self?.bottomConstraint?.constant = -44 * progress
            })
            .addDisposableTo(disposeBag)

        isGhostModeEnabled
            .subscribe(onNext: { [weak self] isEnabled in
                UIView.animate(withDuration: animationDuration) {
                    self?.topAddressBar?.backgroundColor = isEnabled ? .abbGhostMode : .white
                    self?.statusBar?.backgroundColor = isEnabled ? .abbGhostMode  : .white
                    self?.statusBarX?.backgroundColor = isEnabled ? .abbGhostMode  : .white
                    self?.containerView?.backgroundColor = isEnabled ? .abbGhostMode : .abbLightGray
                    self?.addressBar?.backgroundColor = isEnabled ? .abbCharcoalGray : .abbLightGray
                    self?.tabsView?.backgroundColor = isEnabled ? .abbGhostMode : .abbLightGray
                    self?.topRuler?.backgroundColor = isEnabled ? .abbGhostMode : #colorLiteral(red: 0.8235294118, green: 0.8274509804, blue: 0.8352941176, alpha: 1)
                    self?.bottomRuler?.backgroundColor = isEnabled ? .abbCharcoalGray : #colorLiteral(red: 0.8235294118, green: 0.8274509804, blue: 0.8352941176, alpha: 1)
                }
            })
            .addDisposableTo(disposeBag)

        isAddressBarEdited
            .filter { $0 }
            .map { _ in String?.none }
            .bind(to: viewModel.searchPhrase)
            .addDisposableTo(disposeBag)

        let isDashboardShown = Observable
            .combineLatest(viewModel.url.asObservable(), isAddressBarEdited) {
                return $0 == nil || $1
            }
            .asObservable()

        isDashboardShown
            .subscribe(onNext: { [weak containerView] isShown in
                UIView.animate(withDuration: animationDuration) {
                    containerView?.alpha = isShown ? 1.0 : 0.0
                }
            })
            .addDisposableTo(disposeBag)

        Observable
            .combineLatest(isGhostModeEnabled, isAddressBarEdited, viewModel.tabsCount) {
                return (isGhostModeEnabled: $0, isAddressBarEdited: $1, tabsCount: $2)
            }
            .subscribe(onNext: { [weak self] state in
                self?.updateGhostModeBanner(with: state)
            })
            .addDisposableTo(disposeBag)

        let url = viewModel.url.asObservable()
        let addressTrustState = viewModel.addressTrustState
            .asObservable()
            .distinctUntilChanged(==)

        Observable.combineLatest(isAddressBarEdited, url, searchPhrase, addressTrustState) { ($0, $1, $2, $3) }
            .subscribe(onNext: { [weak self] state in
                if let query = state.2 {
                    self?.set(addressBarText: .query(query), addressTrustState: state.3)
                } else {
                    self?.set(addressBarText: AddressBarText(url: state.1), addressTrustState: state.3)
                }

                self?.scrollViewController.scrollsToTop = !state.0
            })
            .addDisposableTo(disposeBag)

        scrollViewController.delegate = self
        addressField?.historyManager = viewModel.historyManager
        navigationController?.delegate = self

        addressBarTapGestureRecognizer?.rx.event
            .filter { $0.state == .ended || $0.state == .began }
            .map { _ in false }
            .bind(to: viewModel.isTabsViewShown)
            .addDisposableTo(disposeBag)

        tapGestureRecognizer?.rx.event
            .filter { [weak self] recognizer in
                if recognizer.state != .ended && recognizer.state != .began {
                    return false
                }

                guard let menuView = self?.menuView, let menuButton = self?.menuControlButton else {
                    return false
                }

                return !menuView.bounds.contains(recognizer.location(in: menuView))
                    && !menuButton.bounds.contains(recognizer.location(in: menuButton))
            }
            .map { _ in false }
            .bind(to: viewModel.isMenuViewShown)
            .addDisposableTo(disposeBag)
    }

    private var ghostModeBanner: UIView?

    private func updateGhostModeBanner(with state: (isGhostModeEnabled: Bool, isAddressBarEdited: Bool, tabsCount: Int)) {
        if state.isGhostModeEnabled {
            let ghostModeBanner: UIView
            if let banner = self.ghostModeBanner {
                ghostModeBanner = banner
            } else {
                guard let banner = GhostModeBanner.create(), let view = containerView else {
                    return
                }

                banner.alpha = 0
                banner.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(banner)
                view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[banner]-0-|",
                                                                   options: NSLayoutFormatOptions(),
                                                                   metrics: nil,
                                                                   views: ["banner": banner]))
                view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[banner]-0-|",
                                                                   options: NSLayoutFormatOptions(),
                                                                   metrics: nil,
                                                                   views: ["banner": banner]))

                self.ghostModeBanner = banner
                ghostModeBanner = banner
            }

            UIView.animate(withDuration: animationDuration) {
                ghostModeBanner.alpha = !state.isAddressBarEdited && state.tabsCount == 0 ? 1.0 : 0.0
            }

        } else {
            if let ghostModeBanner = ghostModeBanner {
                self.ghostModeBanner = nil

                UIView.animate(withDuration: animationDuration, animations: {
                    ghostModeBanner.alpha = 0.0
                }, completion: { _ in
                    ghostModeBanner.removeFromSuperview()
                })
            }
        }
    }

    // MARK: - Context menus
    fileprivate let browserContextActionSheet = BrowserContextActionSheet(dataSource: nil)
    fileprivate var webViewGesturesHandler: WebViewGesturesHandler?

    // MARK: - Autocomplete
    fileprivate var autocompleteController: AutocompleteViewController?

    // MARK: - Properties
    fileprivate var downloadsManager: WebDownloadsManager?

    fileprivate weak var presentedTab: ChromeTab? {
        didSet {
            let activeWebView = viewModel?.activeTab.value?.webView
            if presentedTab == nil && activeWebView != webView {
                didSelectWebView(activeWebView)
            }
        }
    }

    // MARK: - Content

    required init?(coder aDecoder: NSCoder) {
        webView = nil

        super.init(coder: aDecoder)

        browserContextActionSheet?.blockCopyLink = { url in
            if let urlString = url?.absoluteString.removingPercentEncoding {
                let pasteBoard = UIPasteboard.general
                pasteBoard.setValue(urlString, forPasteboardType: "public.utf8-plain-text")
            }
        }

        browserContextActionSheet?.blockOpenHere = { [weak self] url in
            self?.load(url)
        }
        browserContextActionSheet?.blockNewTab = { [weak self] url, webView in
            self?.showNewTab(with: url, fromSource: webView)
        }
        browserContextActionSheet?.blockOpenInBackground = { [weak self] url, source in
            self?.createNewTabInBackground(url, fromSource: source)
        }

        downloadsManager = WebDownloadsManager(uiDelegate: self)
        browserContextActionSheet?.downloadsMgr = downloadsManager
    }

    override func viewDidLoad() {
        navigationController?.navigationBar.barTintColor = .white
        navigationController?.navigationBar.backgroundColor = .white

        if let container = autocompleteContainer {
            view.bringSubview(toFront: container)
        }

        let cancel = NSLocalizedString("Cancel", comment: "Browser address bar cancel")
        cancelButton?.setTitle(cancel, for: UIControlState())

        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        addressBar?.layer.masksToBounds = true
        addressBar?.layer.cornerRadius = 2

        // Removes border on top (bottom)
        menuView?.clipsToBounds = true
        tabsView?.clipsToBounds = true

        // Button was using reload icon for highlighting even if it was selected
        // Different icon was set for selected state of button.
        let image = #imageLiteral(resourceName: "url_x")
        reloadButton?.setImage(image, for: .selected)
        reloadButton?.setImage(image, for: [.selected, .highlighted])

        // WebViewGesturesHandler must be instantiated before didSelectWebView
        // so that the new current webview can be assigned to it
        webViewGesturesHandler = WebViewGesturesHandler(viewToRecognize: viewForWebView)
        weak var wSelf = self
        webViewGesturesHandler?.handlerBlock = { touchPoint in
            if let sSelf = wSelf, let currentWebView = sSelf.webView {
                let urls = CurrentContextURLs()
                sSelf.webViewGesturesHandler?.getURLs(urls, fromCurrentPosition: touchPoint)
                if sSelf.browserContextActionSheet?.create(forCurrentWebView: currentWebView, actionsFor: urls) ?? false {
                    sSelf.browserContextActionSheet?.show(in: sSelf.view)
                }
            }
        }
        webViewGesturesHandler?.currentWebView = webView

        viewForWebView?.historyChangeEventHandler = { [weak self] goForward in
            if goForward {
                self?.goForward()
            } else {
                self?.goBack()
            }
        }

        KeyboardAccessory.attachTo(addressField, parentFrame: self.view.frame)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            (self?.addressField?.inputAccessoryView as? KeyboardAccessory)?.setNeedsUpdateConstraints()

            if let webView = self?.webView {
                self?.initializeWebView(webView, forceRelayout: true)
            }

            if let scrollView = self?.webView?.scrollView {
                if scrollView.minimumZoomScale > 1.0 || scrollView.zoomScale > 1.0 {
                    scrollView.setZoomScale(1.0, animated: true)

                    var offset = scrollView.contentOffset
                    offset.x = 0
                    scrollView.setContentOffset(offset, animated: true)
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch segue.destination {
        case let autocompleteController as AutocompleteViewController:
            self.autocompleteController = autocompleteController
            autocompleteController.onAutocompleteItemSelected = { [weak self] item in
                self?.autocompleteController?.hidden = true
                if let addressField = self?.addressField {
                    switch item {
                    case .search(let result):
                        addressField.text = result
                    case .findInPage(let phrase):
                        self?.viewModel?.searchPhrase.value = phrase
                    }
                    _ = self?.textFieldShouldReturn(addressField)
                }
            }
        case let bookmarksViewController as BookmarksViewController:
            if let viewModel = viewModel {
                viewModel.isBookmarksViewShown.value = true
                bookmarksViewController.viewModel = BookmarksViewModel(components: viewModel.components,
                                                                       isGhostModeEnabled: viewModel.isGhostModeEnabled,
                                                                       browserSignalSubject: viewModel.signalSubject)
            }
        case let dashboardViewController as DashboardViewController:
            if let viewModel = viewModel {
                dashboardViewController.viewModel = DashboardViewModel(components: viewModel.components,
                                                                       isGhostModeEnabled: viewModel.isGhostModeEnabled,
                                                                       browserSignalSubject: viewModel.signalSubject)
            }
        case let editBookmarkViewController as EditBookmarkViewController:
            if let viewModel = viewModel, let bookmark = sender as? BookmarkExtras {
                viewModel.isBookmarksViewShown.value = true
                editBookmarkViewController.viewModel = EditBookmarkViewModel(components: viewModel.components,
                                                                             bookmark: bookmark,
                                                                             isGhostModeEnabled: viewModel.isGhostModeEnabled,
                                                                             viewWillBeDismissed: viewModel.bookmarksViewWillBeDismissed)
            }
        case let menuViewController as MenuViewController:
            if let viewModel = viewModel {
                menuViewController.viewModel = MenuViewModel(browserViewModel: viewModel)
            }
        case let tabsViewController as TabsViewController:
            if let viewModel = viewModel {
                tabsViewController.viewModel = TabsViewModel(components: viewModel.components,
                                                             currentTabsModel: viewModel.currentTabsModel,
                                                             isGhostModeEnabled: viewModel.isGhostModeEnabled,
                                                             isShown: viewModel.isTabsViewShown)
            }
        default:
            break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        viewModel?.isBrowserNavigationEnabled.value = true
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        viewModel?.isBrowserNavigationEnabled.value = false
        super.viewWillDisappear(animated)
    }

    // MARK: - KVO

    func update(activeTab: ChromeTab?) {
        assert(isViewLoaded)
        viewModel?.autocompleteDataSource.setDefaultSessionManager(activeTab?.sessionManager)
        if presentedTab == nil {
            didSelectWebView(activeTab?.webView)
        }
    }

    func update(url current: URL?) {
        assert(isViewLoaded)

        if let nextURL = current {
            var addBookmarkEnabled = false
            if viewModel?.fetchBookmarks(for: nextURL) != nil {
                addBookmarkEnabled = true
            }

            progressBar?.isHidden = !addBookmarkEnabled
            viewForWebView?.isHidden = !addBookmarkEnabled
        } else {
            progressBar?.isHidden = true
            viewForWebView?.isHidden = true
        }
    }

    func update(progress: Double) {
        assert(isViewLoaded)

        guard let progressBar = self.progressBar else {
            return
        }

        let number = Float(progress)

        let currentOutOfRange = progressOutOfRange(Double(progressBar.progress))

        // Diff is used to day delay completion animation (it gives chance to complete progress)
        let diff = Swift.max(0, number - progressBar.progress)

        // Progress is set instantly if current value is lower than previous
        progressBar.setProgress(number, animated: progressBar.progress < number)

        let outOfRange = number <= 0 || number >= 1

        let editing = addressField?.isEditing ?? false

        // Hides/shows progress bar
        if outOfRange != currentOutOfRange && !editing {
            UIView.animate(withDuration: 0.2, delay: TimeInterval(diff), options: .beginFromCurrentState, animations: { () -> Void in
                progressBar.alpha = outOfRange ? 0.0 : 1.0
                return
            }, completion: { finished in
                if finished {
                    self.reloadButton?.isSelected = progressBar.alpha > 0.5
                }
            })
        }
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        if viewController is BrowserViewController {
            viewModel?.didBecomeRootView()
        }
    }

    // MARK: - UIWebViewDelegate

    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        if let url = request.url {
            if url == request.mainDocumentURL {
                if url != viewModel?.currentURL.value {
                    openToolbars()
                }
            }
        }

        return true
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if viewModel?.searchPhrase.value == nil {
            var url: URL? = nil
            addressField?.commitAutocompleteSuggestion()
            if let text = addressField?.text {
                viewModel?.chrome.focusedWindow?.historyManager?.omniboxHistoryUpdatePhrase(text)
                let phrase = text.asCorrectedNakedIpURL()
                url = phrase?.urlValue()
                if url == nil {
                    let engine = UserDefaults.standard.selectedSearchEngine()
                    let urlString = engine.keywordSearchURLStringWithQuery(phrase!)
                    url = URL(string: urlString)
                }
            }
            load(url)
        } else {
            onCancelActivated(nil)
        }
        /**
         addressBar (UITextField) must be resigned before updating its content. Above cancelling
         (directly or through loadURL) ensures it. If UITextField is updated and then immediately
         resigned, it produces one more DidChangeNotification in the stack of resignFirstResponder,
         making other parts of the browser think that the user continues typing.
         */
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if !isAddressBarEdited {
            enterEditingMode()
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if Utils.isObjectReferenceNil(string) {
            return false
        }
        return addressField?.shouldChangeCharactersInRange(range, replacementString: string) ?? true
    }

    fileprivate func enterEditingMode() {
        viewModel?.isAddressBarEdited.value = true
        view.layoutIfNeeded()

        UIView.animate(withDuration: addressBarAnimationDuration, delay: 0.0, options: [], animations: { () in
            self.addressBarConstraint?.priority = UILayoutPriority(rawValue: 250)
            self.addressLabelConstraint?.priority = UILayoutPriority(rawValue: 250)
            self.addressLabelLeftConstraint?.priority = UILayoutPriority(rawValue: 10)
            self.addressLabelRightConstraint?.priority = UILayoutPriority(rawValue: 10)

            self.menuControlButton?.alpha = 0
            self.bookmarkButton?.alpha = 0
            self.cancelButton?.alpha = 1
            self.addressField?.alpha = 1
            self.addressLabel?.alpha = 0
            self.reloadButton?.alpha = 0
            self.progressBar?.alpha = 0

            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    fileprivate func leaveEditingMode() {
        viewModel?.isAddressBarEdited.value = false
        view.layoutIfNeeded()

        UIView.animate(withDuration: addressBarAnimationDuration, delay: 0.0, options: [], animations: { () in
            self.addressBarConstraint?.priority = UILayoutPriority(rawValue: 750)
            self.addressLabelConstraint?.priority = UILayoutPriority(rawValue: 750)
            self.addressLabelLeftConstraint?.priority = UILayoutPriority(rawValue: 900)
            self.addressLabelRightConstraint?.priority = UILayoutPriority(rawValue: 900)

            self.menuControlButton?.alpha = 1
            self.bookmarkButton?.alpha = 1
            self.cancelButton?.alpha = 0
            self.addressField?.alpha = 0
            self.addressLabel?.alpha = 1
            self.reloadButton?.alpha = 1

            if let progressBar = self.progressBar {
                progressBar.alpha = self.progressOutOfRange(Double(progressBar.progress)) ? 0.0 : 1.0
            }

            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func onEditingChanged(_ sender: UITextField) {
        autocompleteController?.searchQueryChangedTo(sender.text ?? "")
    }

    // MARK: - Action

    @IBAction func changeBookmarkedStatus() {
        viewModel?.changeBookmarkedStatus()
    }

    @IBAction func toggleMenu(_ sender: Any?) {
        viewModel?.toggleMenu()
    }

    @IBAction func onBottomAreaTouched(_ sender: UIControl) {
        openToolbars()
    }

    @IBAction func onReloadTouch(_ sender: UIButton) {
        if reloadButton?.isSelected ?? false {
            webView?.stopLoading()

            UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: { () in
                self.progressBar?.alpha = 0.0
                return
            }, completion: { finished in
                if finished {
                    self.reloadButton?.isSelected = false
                    self.progressBar?.progress = 0
                }
            })
        } else {
            webView?.reload()
            viewModel?.progress.value = 0.0
        }
    }

    @IBAction func onCancelActivated(_ sender: AnyObject?) {
        guard isAddressBarEdited else {
            return
        }

        addressField?.resignFirstResponder()
        autocompleteController?.hidden = true
        leaveEditingMode()
    }

    @IBAction func onAdressBarTouch(_ sender: UIButton) {
        if isAddressBarEdited {
            return
        }
        addressField?.becomeFirstResponder()
        addressField?.setCursorToBeginning()
    }

    @IBAction func onViewForWebViewTabRecognized(_ sender: UITapGestureRecognizer) {
        viewModel?.searchPhrase.value = nil
    }

    // MARK: - UIGestureTabRecognizer

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapGestureRecognizer {
            return true
        } else {
            return false
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapGestureRecognizer {
            return false
        } else {
            return true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapGestureRecognizer {
            return false
        } else {
            return true
        }
    }

    // MARK: - BrowserControlDelegate

    func didSelectTab(_ tab: ChromeTab?) {
        // change the current webview only if it was changed
        let aWebView = tab?.webView
        setWebView(aWebView)
        if let aWebView = aWebView {
            prepareWebView(aWebView)
            initializeWebView(aWebView, forceRelayout: true)
        }
    }

    func didSelectWebView(_ aWebView: SAContentWebView?) {
        // change the current webview only if it was changed
        let aWebView = aWebView
        setWebView(aWebView)
        if let aWebView = aWebView {
            prepareWebView(aWebView)
            initializeWebView(aWebView, forceRelayout: true)
        }
    }

    func load(_ url: URL?) {
        onCancelActivated(nil)

        if webView == nil, let window = viewModel?.chrome.focusedWindow {
            // It will install new tab
            createNewTab(url as NSURL?, inWindow: window)?.active = true
        }

        webView?.loadURL(url as NSURL?)
    }

    // swiftlint:disable:next function_body_length
    func showNewTab(_ tab: ChromeTab) {
        presentedTab = tab

        tab.active = true
        tab.window.focused = true

        let newWebView = tab.webView
        let oldWebView = webView

        webView = newWebView
        mountWebView(webView)
        prepareWebView(newWebView)
        initializeWebView(newWebView, forceRelayout: true)

        openToolbars()

        // Skip animation if url is empty, dashboard is displayed
        guard let tabURL = tab.URL, !tabURL.shouldBeHidden() else {
            presentedTab = nil
            unmountWebView(oldWebView)
            return
        }

        // Animation constants
        let animationSpeed = TimeInterval(0.4)
        let minimizedWebViewScale = CGFloat(0.75)

        // There some kind wierd problem with combination of scale and translate animation.
        // Therefore translate animation is implemented by modifying constraints.
        // I found similar issue on stackoverflow (not solved in 29/4/2015)
        // http://stackoverflow.com/questions/27931421/cgaffinetransform-scale-and-translation-jump-before-animation
        var oldTopConstraint: NSLayoutConstraint?
        var newTopConstraint: NSLayoutConstraint?

        // Find top constraint of new and old webView
        if let constraints = viewForWebView?.constraints {
            for constraint in constraints {
                if constraint.identifier == webViewCenterYConstraintIdentifier
                    && constraint.firstItem === newWebView {
                    newTopConstraint = constraint
                }
                if constraint.identifier == webViewCenterYConstraintIdentifier
                    && constraint.firstItem === oldWebView {
                    oldTopConstraint = constraint
                }
            }
        }

        newTopConstraint?.constant = viewForWebView?.frame.size.height ?? 0
        newWebView.transform = CGAffineTransform(scaleX: minimizedWebViewScale, y: minimizedWebViewScale)

        // Scale current view
        let animation1 = {() -> Void in
            oldWebView?.transform = CGAffineTransform(scaleX: minimizedWebViewScale, y: minimizedWebViewScale)
            return
        }

        // Move current and future view
        let animation2 = {() -> Void in
            oldTopConstraint?.constant = -(self.viewForWebView?.frame.size.height ?? 0)
            newTopConstraint?.constant = 0
            self.view.layoutIfNeeded()
            return
        }

        // Set future view to normal mode
        let animation3 = {() -> Void in
            newWebView.transform = CGAffineTransform.identity
            return
        }

        UIView.animate(withDuration: animationSpeed, animations: animation1, completion: { _ in
            UIView.animate(withDuration: animationSpeed, animations: animation2, completion: { _ in
                UIView.animate(withDuration: animationSpeed, animations: animation3, completion: { _ in
                    oldTopConstraint?.constant = 0
                    oldWebView?.transform = CGAffineTransform.identity
                    self.view.layoutIfNeeded()
                    self.unmountWebView(oldWebView)
                    self.presentedTab = nil
                    return
                })
            })
        })
    }

    func showNewTabWithURL(_ url: URL?, inWindow window: ChromeWindow) {
        if let tab = createNewTab(url as NSURL?, inWindow: window) {
            showNewTab(tab)
        }
    }

    fileprivate func showNewTabWithURL(_ url: URL?, fromTab tab: ChromeTab, fromFrame frame: KittFrame? = nil) {
        if let tab = createNewTab(url as NSURL?, inWindow: tab.window, fromSource: tab, fromFrame: frame) {
            showNewTab(tab)
        }
    }

    func showNewTab(with url: URL?, fromSource source: UIWebView?) {
        showNewTab(with: url, fromSource: source, from: nil)
    }

    func showNewTab(with url: URL?, fromSource source: UIWebView?, from frame: KittFrame?) {
        if let sourceTab = (source as? SAContentWebView)?.chromeTab {
            showNewTabWithURL(url, fromTab: sourceTab, fromFrame: frame)
        } else {
            showNewTabWithURL(url, inWindow: viewModel!.chrome.focusedWindow!)
        }
    }

    // MARK: - NetworkActivityDelegate

    func onNetworkActivityState(_ active: Bool) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = active
    }

    func onNetworkLoadingProgress(_ progress: Double) {
    }

    // MARK: - Control

    var isAddressBarEdited: Bool {
        return viewModel?.isAddressBarEdited.value ?? false
    }

    var isPopupShown: Bool {
        return viewModel?.isTabsViewShown.value ?? false
    }

    // MARK: - Properties

    // Set and initializes webView
    var webView: SAContentWebView? {
        didSet {
            oldValue?.scrollView.delegate = nil

            oldValue?.activeBrowserDelegate = nil

            viewForWebView?.webView = webView

            webView?.activeBrowserDelegate = self

            webViewGesturesHandler?.currentWebView = webView

            // Initial setting of progress bar
            if let progress = webView?.networkLoadingProgress {

                if !(self.addressField?.isEditing ?? false) {
                    // Cancel attached animations
                    UIView.animate(withDuration: 0.0) { () in
                        self.progressBar?.alpha = self.progressOutOfRange(progress) ?  0.0 : 1.0
                    }
                }
            }

            webView?.scrollView.delegate = scrollViewController

            UIApplication.shared.isNetworkActivityIndicatorVisible = webView?.networkActive ?? false

            viewModel?.autocompleteDataSource.setDefaultSessionManager(webView?.chromeTab?.sessionManager)
        }
    }

    // ScrollViewControllerDelegate

    func updateSizes(_ progress: CGFloat) -> CGFloat {
        setProgress(progress)

        guard let webView = webView, let webViewTopConstraint = webViewTopConstraint else {
            return 0
        }

        let offset = webViewTopConstraint.constant
        updateWebViewSizes(webView)
        return webViewTopConstraint.constant - offset
    }

    func shouldScrollToTop(_ delegate: ScrollViewController) -> Bool {
        if delegate.currentProgress > 0 {
            openToolbars()
            return false
        } else {
            return true
        }
    }

    // MARK: - DownloadsUIFeedbackDelegate

    func downloadSucceeded(_ link: SaveableWebLink) {
    }

    func downloadFailed(_ link: SaveableWebLink?, error: WebDownloadError) {
        let filename = link?.url.lastPathComponent ?? ""
        let message = "\(filename)\n\(error.description)"
        let alert = UIAlertController(
            title: LocalizationResources.downloadFailureAlertTitle(),
            message: message,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LocalizationResources.alertOKText(), style: .default, handler: nil))
        UIHandler.presentModal(alert, inController: self)
    }

    // MARK: - Private

    fileprivate func createNewTabInBackground(_ url: URL?, fromSource source: UIWebView?) {
        let sourceTab = (source as? SAContentWebView)?.chromeTab

        if let window = viewModel?.chrome.focusedWindow, let tab = createNewTab(url as NSURL?, inWindow: window, fromSource: sourceTab) {

            let aWebView = tab.webView
            openToolbars()
            //scheduleTabsAnimation(true)

            aWebView.isHidden = true
            aWebView.frame = viewForWebView?.bounds ?? CGRect.zero
            scrollViewController.initializeScrollViewInsets(aWebView.scrollView)
            // Someone has to be owner of WebView, otherwise it's preview is not updated
            view.addSubview(aWebView)
            view.sendSubview(toBack: aWebView)

            SAContentWebView.prepare(aWebView,
                                     contextMenuDataSource: viewModel?.contextMenuDataSource,
                                     webNavigationEventsDelegate: viewModel?.webNavigationEventsDelegate,
                                     contentScriptLoaderDelegate: viewModel?.contentScriptLoaderDelegate)
        }
        // must go after the new tab is fully initialized = having hibernation flag set to false
        sourceTab?.window.makeActiveTabNewest()
    }

    fileprivate func createNewTab(
        _ url: NSURL?,
        inWindow window: ChromeWindow,
        fromSource source: ChromeTab? = nil,
        fromFrame frame: KittFrame? = nil) -> ChromeTab? {
        var tabURL = url

        if let url = url, url.host?.isEmpty ?? true {
            if let urlString = url.absoluteString, let sourceURL = source?.URL {
                tabURL = NSURL(string: urlString, relativeTo: sourceURL as URL)
            } else {
                tabURL = nil
            }
        }

        // I tested that, this method can be called with nil param
        var index = NSNotFound
        if let source = source {
            index = window.tabs.index(of: source)
        }

        if index == NSNotFound {
            index = window.tabs.count
        } else {
            index += 1
        }

        let tab = window.add(tabWithURL: tabURL as URL?, atIndex: index)
        tab?.openerTab = source
        tab?.openerFrame = frame
        return tab
    }

    fileprivate func setWebView(_ aWebView: SAContentWebView?) {
        unmountWebView(webView)
        webView = aWebView
        mountWebView(webView)
    }

    fileprivate func unmountWebView(_ aWebView: SAContentWebView?) {
        aWebView?.removeFromSuperview()
    }

    fileprivate func mountWebView(_ aWebView: SAContentWebView?) {
        if let aWebView = aWebView {
            aWebView.translatesAutoresizingMaskIntoConstraints = false
            viewForWebView?.addSubview(aWebView)

            // Placeholder for type inference
            let emptyString: String? = nil

            // There are four layout constrint
            let params = [
                // width equality with superview
                (firstAttribute: NSLayoutAttribute.width, secondAttribute: NSLayoutAttribute.width, identifier: emptyString),
                // height equality with superview
                (firstAttribute: NSLayoutAttribute.height, secondAttribute: NSLayoutAttribute.height, identifier: emptyString),
                // horizontal center
                (firstAttribute: NSLayoutAttribute.centerX,
                 secondAttribute: NSLayoutAttribute.centerX,
                 identifier: webViewCenterXConstraintIdentifier),
                // vertical center
                (firstAttribute: NSLayoutAttribute.centerY,
                 secondAttribute: NSLayoutAttribute.centerY,
                 identifier: webViewCenterYConstraintIdentifier)
            ]

            for param in params {
                let constraint = NSLayoutConstraint(item: aWebView,
                                                    attribute: param.firstAttribute,
                                                    relatedBy: .equal,
                                                    toItem: viewForWebView!,
                                                    attribute: param.secondAttribute,
                                                    multiplier: 1,
                                                    constant: 0)

                constraint.identifier = param.identifier

                viewForWebView?.addConstraint(constraint)
            }

            aWebView.backgroundColor = viewForWebView?.backgroundColor

            // This code is fixing strange black bar on the bottom of webView.
            // http://stackoverflow.com/questions/11388534/black-bar-appearing-in-uiwebview-when-device-orientation-changes
            // This issue is caused probably caused by setting content insets and offset,
            // but I didn't managed to completely vaporize that black bar by any insets setting.
            aWebView.isOpaque = false
            aWebView.isHidden = false
        }
    }

    fileprivate func prepareWebView(_ aWebView: SAContentWebView) {
        SAContentWebView.prepare(aWebView,
                                 contextMenuDataSource: viewModel?.contextMenuDataSource,
                                 webNavigationEventsDelegate: viewModel?.webNavigationEventsDelegate,
                                 contentScriptLoaderDelegate: viewModel?.contentScriptLoaderDelegate)

        // reassign to the context menu
        viewModel?.contextMenuDataSource?.setEditing(aWebView)
        // did change tabs, must reload history nav buttons
    }

    fileprivate func setProgress(_ progress: CGFloat) {
        if isAddressBarEdited || isPopupShown {
            return
        }

        viewModel?.toolbarProgress.value = progress
    }

    fileprivate func openToolbars() {
        let webViewOffset = webViewTopConstraint?.constant ?? 0
        var offset = webView?.scrollView.contentOffset ?? CGPoint.zero
        offset.y -= webViewOffset

        UIView.animate(withDuration: 0.2) { () in
            self.scrollViewController.currentProgress = 0
            self.setProgress(0)
            self.webViewTopConstraint?.constant = 0
            self.webView?.scrollView.contentOffset = offset
            self.view.layoutIfNeeded()
        }
    }

    fileprivate func initializeWebView(_ webView: UIWebView, forceRelayout force: Bool = false) {
        webView.scrollView.delegate = scrollViewController
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        webView.scrollView.scrollsToTop = true
        webView.scrollView.backgroundColor = .clear

        scrollViewController.initializeScrollViewInsets(webView.scrollView)
        updateWebViewSizes(webView)

        if force {
            // [HACK] This code force webview to relayout.
            // Methods setNeedsDisplay and setNeedsLayout does not work.
            var point = webView.scrollView.contentOffset
            // 1px is completely ignored, 30px is enought
            point.y -= 40
            webView.scrollView.setContentOffset(point, animated: false)
            point.y += 40
            webView.scrollView.setContentOffset(point, animated: false)
        }
    }

    fileprivate func updateWebViewSizes(_ aWebView: UIWebView) {
        let scrollView = aWebView.scrollView

        let topBarOffset = topConstraint?.constant ?? 0
        let bottomBarOffset = bottomConstraint?.constant ?? 0

        var frame = scrollView.frame

        frame.size.height = aWebView.frame.size.height - topBarOffset - bottomBarOffset

        if scrollView.frame.size.height != frame.size.height {
            scrollView.frame = frame
        }

        if topBarOffset != (webViewTopConstraint?.constant ?? 0) {
            webViewTopConstraint?.constant = topBarOffset
        }
    }

    private enum AddressBarText {
        case empty
        case url(URL)
        case query(String)

        init (url: URL?) {
            if let url = url, !url.absoluteString.isEmpty, !(url as NSURL).shouldBeHidden() {
                self = .url(url)
            } else {
                self = .empty
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func set(addressBarText text: AddressBarText, addressTrustState: AddressTrustState) {
        let isGhostModeEnabled = viewModel?.isGhostModeEnabled.value ?? false
        let hasUrl: Bool
        if case .url(_) = text {
            hasUrl = true
        } else {
            hasUrl = false
        }

        let textColor = isGhostModeEnabled ? #colorLiteral(red: 0.5450980392, green: 0.5294117647, blue: 0.5725490196, alpha: 1) : .abbCoolGray

        let placeholder = addressFieldPlaceholder(for: isGhostModeEnabled)
        addressField?.attributedPlaceholder = placeholder
        addressField?.textColor = isGhostModeEnabled ? .abbLightGray : .abbSlateGray
        addressField?.clearButtonMode = !hasUrl ? .never : .always
        addressLabel?.adjustsFontSizeToFitWidth = !hasUrl

        addressLabelRightConstraint?.setState(hasUrl)

        switch text {
        case .query(let query):
            addressLabel?.textColor = textColor
            addressLabel?.text = query
            addressField?.text = query
            addressBarLeadingEdgesConstraint?.constant = 0
        case .empty:
            addressLabel?.textColor = textColor
            addressLabel?.text = placeholder.string
            addressField?.text = nil
            addressBarLeadingEdgesConstraint?.constant = 0
        case .url(let url):
            addressField?.text = url.absoluteString

            let (urlColor, lockImage, altText) = { () -> (UIColor, UIImage?, String?) in
                switch addressTrustState {
                case .extended(let holderName):
                    return (#colorLiteral(red: 0.2117647059, green: 0.6666666667, blue: 0.2745098039, alpha: 1), #imageLiteral(resourceName: "ssl_extended"), holderName)
                case .trusted:
                    return (.abbSlateGray, #imageLiteral(resourceName: "ssl_normal"), nil)
                case .broken:
                    return (#colorLiteral(red: 0.8549019608, green: 0, blue: 0.1058823529, alpha: 1), #imageLiteral(resourceName: "ssl_broken"), nil)
                case .none:
                    return (.abbSlateGray, nil, nil)
                }
            }()

            let text = altText ?? url.displayableHostname ?? ""

            let labelTextOffset: CGFloat
            if let lockImage = lockImage {
                let attachment = NSTextAttachment()
                attachment.image = lockImage

                let attributes = [ NSAttributedStringKey.foregroundColor: urlColor ]

                let mutableString = NSMutableAttributedString()
                mutableString.append(NSAttributedString(attachment: attachment))
                mutableString.append(NSAttributedString(string: "   \(text)", attributes: attributes))
                addressLabel?.attributedText = mutableString
                labelTextOffset = compute(offsetOf: text, in: mutableString, with: addressLabel?.frame.size ?? .zero)
            } else {
                addressLabel?.textColor = urlColor
                addressLabel?.text = text
                labelTextOffset = 0
            }

            let fieldTextOffset: CGFloat
            if let addressField = addressField, let attributedText = addressField.attributedText {
                fieldTextOffset = compute(offsetOf: text, in: attributedText, with: addressField.bounds.size)
            } else {
                fieldTextOffset = 0
            }

            addressBarLeadingEdgesConstraint?.constant = fieldTextOffset - labelTextOffset
        }

        view.layoutIfNeeded()
    }

    private func compute(offsetOf string: String, in attributedString: NSAttributedString, with size: CGSize) -> CGFloat {
        let range = (attributedString.string as NSString).range(of: string)
        if range.location == NSNotFound {
            return 0
        }
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: size)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        var glyphRange = NSRange(location: 0, length: 0)
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let result = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return result.origin.x
    }

    private func progressOutOfRange(_ progress: Double) -> Bool {
        return progress <= 0 || progress >= 1
    }

    private func goBack() {
        if let webView = webView, webView.canGoBack {
            if webView.scrollView.isDecelerating {
                webView.scrollView.setContentOffset(webView.scrollView.contentOffset, animated: true)
            }
            webView.goBack()
        }
    }

    private func goForward() {
        if let webView = webView, webView.canGoForward {
            if webView.scrollView.isDecelerating {
                webView.scrollView.setContentOffset(webView.scrollView.contentOffset, animated: true)
            }
            webView.goForward()
        }
    }
}

private func addressFieldPlaceholder(`for` isGhostModeEnabled: Bool) -> NSAttributedString {
    let placeholder = localize("browser_address_bar_placeholder", comment: "Browser address bar")
    return NSAttributedString(string: placeholder, attributes: [NSAttributedStringKey.foregroundColor: isGhostModeEnabled ? #colorLiteral(red: 0.4784313725, green: 0.4745098039, blue: 0.4705882353, alpha: 1) : #colorLiteral(red: 0.737254902, green: 0.7450980392, blue: 0.7607843137, alpha: 1)])
    // swiftlint:disable:next file_length
}
