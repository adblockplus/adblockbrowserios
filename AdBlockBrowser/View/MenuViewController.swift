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

final class MenuViewController: TableViewController<MenuViewModel> {
    @IBOutlet weak var whitelistSwitch: SwitchView?
    @IBOutlet weak var requestDesktopSiteSwitch: SwitchView?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.scrollsToTop = false
        let emptyView = UIView(frame: CGRect(x: 0, y: 0, width: tableView?.frame.width ?? 0, height: .leastNonzeroMagnitude))
        emptyView.backgroundColor = .clear
        tableView?.tableHeaderView = emptyView
        tableView?.tableFooterView = emptyView
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch segue.destination {
        case let historyViewController as HistoryViewController:
            if let viewModel = viewModel {
                historyViewController.viewModel = HistoryViewModel(viewModel: viewModel)
            }
        default:
            break
        }
    }

    // MARK: - MVVM

    let disposeBag = DisposeBag()

    override func observe(viewModel: ViewModelEx) {
        viewModel.isWhitelistable.asDriver()
            .drive(onNext: { [weak self] _ in
                self?.reload()
            })
            .addDisposableTo(disposeBag)

        viewModel.isPageWhitelisted.asDriver()
            .drive(onNext: { [weak self] whitelisted in
                self?.whitelistSwitch?.setOn(!whitelisted, animated: true)
                self?.reload()
            })
            .addDisposableTo(disposeBag)

        viewModel.isBookmarked.asDriver()
            .drive(onNext: { [weak self] _ in
                self?.reload()
            })
            .addDisposableTo(disposeBag)

        viewModel.isHistoryViewShown.asObservable()
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] isShown in
                if isShown {
                    self?.performSegue(withIdentifier: "ShowHistorySegue", sender: nil)
                } else if self?.navigationController?.topViewController is HistoryViewController {
                    self?.navigationController?.popViewController(animated: true)
                }
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: -

    func reload() {
        DispatchQueue.main.async(execute: { () -> Void in
            // Entire tableview has to be reloaded (only one cell could have changed),
            // otherwise it will be causing various glitches on iOS7.
            self.tableView.reloadData()
            self.tableView.superview?.invalidateIntrinsicContentSize()
        })
    }

    // MARK: - UITableDataSource

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let rawCell = super.tableView(tableView, cellForRowAt: indexPath)

        if #available(iOS 9, *) {
            // Fixes:
            // https://stackoverflow.com/questions/27551291/uitableview-backgroundcolor-always-white-on-ipad
            rawCell.backgroundColor = rawCell.backgroundColor
        }

        guard let cell = rawCell as? MenuCell else {
            return rawCell
        }

        guard let item = MenuItem(rawValue: indexPath.row) else {
            return cell
        }

        let isEnabled = viewModel?.shouldBeEnabled(item) ?? true

        let text: String?
        let image: UIImage?

        switch item {
        case .adblockingEnabled:
            whitelistSwitch?.isEnabled = isEnabled
            text = NSLocalizedString("Block Ads on this Site", comment: "Pull up menu option")
            image = nil
        case .requestDesktopSite:
            requestDesktopSiteSwitch?.isEnabled = isEnabled
            requestDesktopSiteSwitch?.isOn = viewModel?.isRequestDesktopSiteActive() ?? false
            text = NSLocalizedString("Request Desktop Site", comment: "Request desktop site")
            image = nil
        case .openNewTab:
            text = NSLocalizedString("Open New Tab", comment: "Pull up menu option")
            image = #imageLiteral(resourceName: "newTabIcon")
        case .addBookmark:
            let isBookmarked = viewModel?.isBookmarked.value ?? false
            if isBookmarked && isEnabled {
                text = NSLocalizedString("Remove Bookmark", comment: "Pull up menu option")
                image = #imageLiteral(resourceName: "bookmarkIconActive")
            } else {
                text = NSLocalizedString("Add Bookmark", comment: "Pull up menu option")
                if isEnabled {
                    image = #imageLiteral(resourceName: "bookmarkIconInactive")
                } else {
                    image = #imageLiteral(resourceName: "bookmarkIconInactiveDisabled")
                }
            }
        case .share:
            text = NSLocalizedString("Share", comment: "Pull up menu option")
            image = isEnabled ? #imageLiteral(resourceName: "shareIcon") : #imageLiteral(resourceName: "shareIconDisabled")
        case .history:
            text = NSLocalizedString("History", comment: "Pull up menu option")
            image = #imageLiteral(resourceName: "historyIcon")
        case .settings:
            text = NSLocalizedString("Settings", comment: "Pull up menu option")
            image = #imageLiteral(resourceName: "settingsIcon")
        }

        cell.isUserInteractionEnabled = isEnabled
        cell.customTextLabel?.text = text
        cell.customTextLabel?.textColor = isEnabled ? #colorLiteral(red: 0.7764705882, green: 0.7843137255, blue: 0.7921568627, alpha: 1) : #colorLiteral(red: 0.368627451, green: 0.3725490196, blue: 0.3803921569, alpha: 1)
        cell.customImageView?.image = image
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let item = MenuItem(rawValue: indexPath.row) {
            viewModel?.handle(menuItem: item)
            tableView.deselectRow(at: indexPath, animated: true)
            if item == .adblockingEnabled {
                whitelistSwitch?.isOn = !(whitelistSwitch?.isOn ?? true)
            }
            if item == .requestDesktopSite{
                requestDesktopSiteSwitch?.isOn = viewModel?.isRequestDesktopSiteActive() ?? false
            }
        }
    }
}

class MenuContainerView: UIView {
    override var intrinsicContentSize: CGSize {
        if let view: UITableView = subviews.firstOfType() {
            return view.sizeThatFits(CGSize(width: frame.size.width, height: CGFloat.infinity))
        } else {
            return super.intrinsicContentSize
        }
    }
}
