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

import RxSwift

// swiftlint:disable:next type_body_length
final class BrowserContainerViewController: ViewController<BrowserContainerViewModel>,
    BrowserControlDelegate,
    FindInPageControlDelegate {
    @IBOutlet weak var rootView: UIView?
    @IBOutlet weak var backButton: UIButton?
    @IBOutlet weak var forwardButton: UIButton?
    @IBOutlet weak var tabsButton: UIButton?
    @IBOutlet weak var ghostTabsButton: UIButton?
    @IBOutlet weak var favoriteButton: UIButton?
    @IBOutlet weak var memoryInfoLabel: UILabel?
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint?
    @IBOutlet weak var bottomBar: UIControl?
    @IBOutlet weak var homeBarX: UIView!

    weak var findInPageControl: FindInPageControl?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: nil)
        switch segue.destination {
        case let navigationController as UINavigationController:
            if let controller = navigationController.topViewController as? BrowserViewController {
                if let viewModel = viewModel {
                    controller.viewModel = BrowserViewModel(browserContainerViewModel: viewModel)
                }
            }
        default:
            break
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let frame = bottomBar?.frame {
            findInPageControl?.frame = frame
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if viewModel?.isGhostModeEnabled.value ?? false {
            return .lightContent
        } else {
            return .`default`
        }
    }

    #if DEVBUILD_FEATURES
        var memoryValues: MemoryValues? {
            didSet {
                guard let label = memoryInfoLabel else {
                    return
                }
                if let values = memoryValues {
                    label.isHidden = false
                    let meg = Int64(1024 * 1024)
                    let resident = values.resident / meg
                    let allowed = values.allowed / meg
                    let physical = values.physical / meg

                    // printf-style formatting was here, but iOS8 has a weird problem with Swift Int64 type
                    // (format:"%lu %lu", some1Int64Value, some2Int64Value) will return zero at second position.
                    // It probably has something to do with Swift Int64 being incompatible with CVarArg type.
                    // It works in iOS9 though.
                    label.text = String(format: "Memory pressure: \(resident)/\(allowed)MB max \(physical)")
                } else {
                    // received nil, hide the label
                    label.isHidden = true
                    return
                }
            }
        }
    #endif

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func observe(viewModel: BrowserContainerViewModel)
    {
        let isAnyPopupShown = viewModel.isAnyPopupShown
        let isGhostModeEnabled = viewModel.isGhostModeEnabled.asObservable()
        let isTabsViewShown = viewModel.isTabsViewShown.asObservable()
        let isBookmarksViewShown = viewModel.isBookmarksViewShown.asObservable()

        if let bottomBar = bottomBar {
            bottomBar.rx.controlEvent(.touchUpInside)
                .map { return .bottomBar }
                .bind(to: viewModel.events)
                .addDisposableTo(disposeBag)
        }

        if let backButton = backButton {
            let obs1 = viewModel.canGoBack.asObservable()
            let obs2 = viewModel.isBrowserNavigationEnabled.asObservable()
            let isEnabled = Observable.combineLatest(obs1, obs2, isAnyPopupShown) { $0 && $1 && !$2 }
                .distinctUntilChanged()

            isEnabled.bind(to: backButton.rx.isEnabled).addDisposableTo(disposeBag)

            backButton.rx.controlEvent(.touchUpInside)
                .map { .goBack }
                .bind(to: viewModel.signalSubject)
                .addDisposableTo(disposeBag)

            Observable.combineLatest(isEnabled, isGhostModeEnabled, Observable.just(false)) { return ($0, $1, $2) }
                .subscribe(onNext: createImageSetter(for: backButton,
                                                     #imageLiteral(resourceName: "ArrowLeft"),
                                                     #imageLiteral(resourceName: "ArrowLeftDisabled"),
                                                     #imageLiteral(resourceName: "ArrowLeftGhost"),
                                                     #imageLiteral(resourceName: "ArrowLeftDisabledGhost")))
                .addDisposableTo(disposeBag)
        }

        if let forwardButton = forwardButton {
            let obs1 = viewModel.canGoForward.asObservable()
            let obs2 = viewModel.isBrowserNavigationEnabled.asObservable()
            let isEnabled = Observable.combineLatest(obs1, obs2, isAnyPopupShown) { $0 && $1 && !$2}
                .distinctUntilChanged()

            isEnabled.bind(to: forwardButton.rx.isEnabled).addDisposableTo(disposeBag)

            forwardButton.rx.controlEvent(.touchUpInside)
                .map { .goForward }
                .bind(to: viewModel.signalSubject)
                .addDisposableTo(disposeBag)

            Observable.combineLatest(isEnabled, isGhostModeEnabled, Observable.just(false)) { return ($0, $1, $2) }
                .subscribe(onNext: createImageSetter(for: forwardButton,
                                                     #imageLiteral(resourceName: "ArrowRight"),
                                                     #imageLiteral(resourceName: "ArrowRightDisabled"),
                                                     #imageLiteral(resourceName: "ArrowRightGhost"),
                                                     #imageLiteral(resourceName: "ArrowRightDisabledGhost")))
                .addDisposableTo(disposeBag)
        }

        if let tabsButton = tabsButton {
            viewModel.tabsCount.asObservable()
                .map { count in "\(count)" }
                .bind(to: tabsButton.rx.title())
                .addDisposableTo(disposeBag)

            tabsButton.rx.controlEvent(.touchUpInside)
                .map { return .tabsButton }
                .bind(to: viewModel.events)
                .addDisposableTo(disposeBag)

            viewModel.isTabsButttonEnabled
                .bind(to: tabsButton.rx.isEnabled)
                .addDisposableTo(disposeBag)

            Observable
                .combineLatest(viewModel.isTabsButttonVisuallyEnabled, isGhostModeEnabled, isTabsViewShown) {
                    return ($0, $1, $2) as ButtonState
                }
                .subscribe(onNext: { state in
                    let image = selectImage(for: state,
                                            #imageLiteral(resourceName: "TabsIcon"),
                                            #imageLiteral(resourceName: "TabsIconDisabled"),
                                            #imageLiteral(resourceName: "TabsIconGhost"),
                                            #imageLiteral(resourceName: "TabsIconDisabledGhost"),
                                            #imageLiteral(resourceName: "TabsIconActive"))

                    let color: UIColor
                    if !state.isEnabled {
                        color = state.isGhostModeEnabled ? .abbSlateGray : .abbSilver
                    } else if state.isActive {
                        color = .white
                    } else {
                        color = state.isGhostModeEnabled ? .abbLightGray : .abbSlateGray
                    }

                    UIView.transition(with: tabsButton, duration: animationDuration, options: .transitionCrossDissolve, animations: {
                        tabsButton.setImage(image, for: .normal)
                        tabsButton.setTitleColor(color, for: .normal)
                    })
                })
                .addDisposableTo(disposeBag)
        }

        if let ghostTabsButton = ghostTabsButton {
            let isEnabled = isAnyPopupShown.map { !$0 } .distinctUntilChanged()

            isEnabled.bind(to: ghostTabsButton.rx.isEnabled).addDisposableTo(disposeBag)

            ghostTabsButton.rx.controlEvent(.touchUpInside)
                .withLatestFrom(isGhostModeEnabled)
                .subscribe(onNext: { [weak self] isGhostModeEnabled in
                    if isGhostModeEnabled {
                        if self?.viewModel?.shouldDisplayLeaveGhostModeNotification() ?? false {
                            self?.showGhostModeLeaveNotification()
                        } else {
                            self?.viewModel?.switchToNormalNode()
                        }
                    } else {
                        self?.viewModel?.switchToGhostMode()
                    }
                })
                .addDisposableTo(disposeBag)

            Observable.combineLatest(isEnabled, isGhostModeEnabled) { return ($0, $1, $1) }
                .subscribe(onNext: createImageSetter(for: ghostTabsButton,
                                                     #imageLiteral(resourceName: "GhostIcon"),
                                                     #imageLiteral(resourceName: "GhostIconDisabled"),
                                                     #imageLiteral(resourceName: "GhostIcon"),
                                                     #imageLiteral(resourceName: "GhostIconDisabledGhost"),
                                                     #imageLiteral(resourceName: "GhostIconActive")))
                .addDisposableTo(disposeBag)
        }

        if let favoriteButton = favoriteButton {
            favoriteButton.rx.controlEvent(.touchUpInside)
                .map { return .favoriteButton }
                .bind(to: viewModel.events)
                .addDisposableTo(disposeBag)

            viewModel.isFavoriteButtonEnabled
                .bind(to: favoriteButton.rx.isEnabled)
                .addDisposableTo(disposeBag)

            Observable
                .combineLatest(viewModel.isFavoriteButtonVisuallyEnabled, isGhostModeEnabled, isBookmarksViewShown) {
                    return ($0, $1, $2)
                }
                .subscribe(onNext: createImageSetter(for: favoriteButton,
                                                     #imageLiteral(resourceName: "FavoritesIcon"),
                                                     #imageLiteral(resourceName: "FavoritesIconDisabled"),
                                                     #imageLiteral(resourceName: "FavoritesIconGhost"),
                                                     #imageLiteral(resourceName: "FavoritesIconDisabledGhost"),
                                                     #imageLiteral(resourceName: "FavoritesIconActive")))
                .addDisposableTo(disposeBag)
        }

        viewModel.isGhostModeEnabled.asObservable()
            .subscribe(onNext: { [weak self] isEnabled in
                UIView.animate(withDuration: animationDuration) {
                    self?.setNeedsStatusBarAppearanceUpdate()
                    self?.bottomBar?.backgroundColor = isEnabled ? .abbGhostMode : .white
                    self?.rootView?.backgroundColor = isEnabled ? .abbGhostMode : .white
                    self?.homeBarX?.backgroundColor = isEnabled ? .abbGhostMode : .white
                }
            })
            .addDisposableTo(disposeBag)

        viewModel.searchPhrase.asObservable()
            .subscribe(onNext: { [weak self] searchPhrase in
                if searchPhrase != nil {
                    let findInPageControl: FindInPageControl
                    if let control = self?.findInPageControl {
                        findInPageControl = control
                    } else if let control = FindInPageControl.create() {
                        control.delegate = self
                        self?.view.addSubview(control)
                        self?.findInPageControl = control
                        findInPageControl = control
                    } else {
                        return
                    }
                    findInPageControl.phrase = searchPhrase
                } else {
                    self?.findInPageControl?.clearMatches()
                }
            })
            .addDisposableTo(disposeBag)

        viewModel.toolbarProgress.asObservable()
            .subscribe(onNext: { [weak self] progress in
                self?.bottomConstraint?.constant = -44 * progress
            })
            .addDisposableTo(disposeBag)

        #if DEVBUILD_FEATURES
            if let watchdog = viewModel.components.debugReporting?.watchdog {
                watchdog.rx.observe(MemoryValues.self, #keyPath(MemoryWatchdog.lastRecordedValues))
                    .subscribe(onNext: { [weak self] values in
                        self?.memoryValues = values
                    })
                    .addDisposableTo(disposeBag)
            }
        #endif
    }

    // MARK: - BrowserControlDelegate

    func load(_ url: URL!) {
        browserViewController?.load(url)
    }

    func showNewTab(with url: URL!, fromSource source: UIWebView!) {
        browserViewController?.showNewTab(with: url, fromSource: source)
    }

    func showNewTab(with url: URL!, fromSource source: UIWebView!, from frame: KittCore.KittFrame!) {
        browserViewController?.showNewTab(with: url, fromSource: source, from: frame)
    }

    var browserViewController: BrowserViewController? {
        for child in childViewControllers {
            if let childViewController = (child as? UINavigationController)?.viewControllers.first as? BrowserViewController {
                return childViewController
            }
        }
        assert(false)
        return nil
    }

    // MARK: - FindInPageControlDelegate

    func willFinishFindInPageMode(_ control: FindInPageControl) {
        viewModel?.searchPhrase.value = nil
    }

    // MARK: - Private

    private func showGhostModeLeaveNotification() {
        let title = localize("leave_notification_headline", comment: "Leave notification")
        let message = localize("leave_notification_subline", comment: "Leave notification")
        let accept = localize("leave_notification_button_1", comment: "Leave notification")
        let cancel = localize("leave_notification_button_2", comment: "Leave notification")

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: accept, style: .`default`, handler: { [weak self] _ in
            self?.viewModel?.switchToNormalNode()
        }))
        alertController.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        alertController.modalTransitionStyle = .crossDissolve
        present(alertController, animated: true, completion: nil)
    }
}

private typealias ButtonState = (isEnabled: Bool, isGhostModeEnabled: Bool, isActive: Bool)

private func selectImage(for state: ButtonState,
                         _ image: UIImage,
                         _ disabledImage: UIImage,
                         _ ghostImage: UIImage,
                         _ ghostDisabledImage: UIImage,
                         _ activeImage: UIImage? = nil) -> UIImage {
    if !state.isEnabled {
        return state.isGhostModeEnabled ? ghostDisabledImage : disabledImage
    } else if state.isActive, let activeImage = activeImage {
        return activeImage
    } else {
        return state.isGhostModeEnabled ? ghostImage : image
    }
}

private func createImageSetter(for button: UIButton,
                               _ image: UIImage,
                               _ disabledImage: UIImage,
                               _ ghostImage: UIImage,
                               _ ghostDisabledImage: UIImage,
                               _ activeImage: UIImage? = nil) -> ((ButtonState) -> Void) {
    return { state in
        let result = selectImage(for: state, image, disabledImage, ghostImage, ghostDisabledImage, activeImage)

        UIView.transition(with: button, duration: animationDuration, options: .transitionCrossDissolve, animations: {
            button.setImage(result, for: .normal)
        })
    }
}
