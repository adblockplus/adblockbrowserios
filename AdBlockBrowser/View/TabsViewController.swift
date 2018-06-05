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

final class TabsViewController: TableViewController<TabsViewModel> {
    enum CellIdentifiers: String, CellIdentifier {
        case addNewTabCell
        case tabViewCell
        case tipCell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.scrollsToTop = false
        automaticallyAdjustsScrollViewInsets = false
    }

    weak var toast: UndoToast?

    // MARK: - MVVM

    let disposeBag = DisposeBag()

    override func observe(viewModel: ViewModelEx) {
        viewModel.tabsEvents
            .asDriver(onErrorJustReturn: .reload)
            .drive(onNext: { [weak self] event in
                switch event {
                case .reload:
                    self?.tableView.reloadData()
                case .update(let inserted, let removed):
                    self?.tableView.beginUpdates()
                    self?.tableView.insertSections(inserted, with: .automatic)
                    self?.tableView.deleteSections(removed, with: .automatic)
                    self?.tableView.endUpdates()
                }
            })
            .addDisposableTo(disposeBag)

        viewModel.isUndoToastShown
            .asDriver()
            .drive(onNext: { [weak self] isShown in
                self?.update(isUndoToastShown: isShown)
            })
            .addDisposableTo(disposeBag)

        viewModel.isShown
            .asDriver()
            .drive(onNext: { [weak self] isShown in
                if isShown, let indexPath = self?.tableView?.indexPathForSelectedRow {
                    self?.tableView?.deselectRow(at: indexPath, animated: false)
                }
            })
            .addDisposableTo(disposeBag)
    }

    func update(isUndoToastShown: Bool) {
        let duration = TimeInterval(0.5)

        if isUndoToastShown && toast == nil, let view = self.tableView.superview {
            let toast = UndoToast()
            toast.alpha = 0
            toast.translatesAutoresizingMaskIntoConstraints = false
            toast.button.addTarget(self, action: #selector(onUndoLabelTouched), for: .touchUpInside)
            self.toast = toast

            view.addSubview(toast)
            view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[view]-0-|",
                                                               options: NSLayoutFormatOptions(),
                                                               metrics: nil,
                                                               views: ["view": toast]))
            view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[view]-15-|",
                                                               options: NSLayoutFormatOptions(),
                                                               metrics: nil,
                                                               views: ["view": toast]))
            view.layoutIfNeeded()

            UIView.animate(withDuration: duration) {
                toast.alpha = 1.0
            }

        } else if isUndoToastShown, let toast = toast {

            UIView.animate(withDuration: duration) {
                toast.alpha = 1.0
            }
        } else if !isUndoToastShown, let toast = toast {

            UIView.animate(withDuration: duration) {
                toast.alpha = 0.0
            }
        }
    }

    @objc
    func onUndoLabelTouched(_ sender: Any) {
        viewModel?.showHiddenTabs()
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.entriesCount() ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        switch viewModel?.entry(at: indexPath) {
        case .some(.addNewTab):
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifiers.addNewTabCell,
                                                 for: indexPath)
            (cell as? AddNewTabCell)?.isGhostModeStyleUsed = viewModel?.isGhostModeEnabled.value ?? false
        case .some(.tip):
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifiers.tipCell,
                                                 for: indexPath)
        case let entry:
            cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifiers.tabViewCell,
                                                 for: indexPath)
            if case .some(.tab(let chromeTab)) = entry, let tabCell = cell as? TabViewCell {
                tabCell.tab = chromeTab
                tabCell.isGhostModeStyleUsed = viewModel?.isGhostModeEnabled.value ?? false
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if case .some(.tab(_)) = viewModel?.entry(at: indexPath) {
            return true
        } else {
            return false
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, case .some(.tab(let tab)) = viewModel?.entry(at: indexPath) {
            viewModel?.hide(tab: tab)
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 8
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerFooterView = view as? UITableViewHeaderFooterView {
            headerFooterView.backgroundView?.backgroundColor = .clear
            headerFooterView.contentView.backgroundColor = .clear
        } else {
            view.backgroundColor = .clear
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let headerFooterView = view as? UITableViewHeaderFooterView {
            headerFooterView.backgroundView?.backgroundColor = .clear
            headerFooterView.contentView.backgroundColor = .clear
        } else {
            view.backgroundColor = .clear
        }
    }

    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return NSLocalizedString("Close", comment: "Tabs view")
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if case .some(.tab(_)) = viewModel?.entry(at: indexPath) {
            return .delete
        } else {
            return .none
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel?.entry(at: indexPath) {
        case .some(.addNewTab):
            viewModel?.showNewTab()
        case .some(.tab(let chromeTab)):
            viewModel?.select(tab: chromeTab)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TabViewCell {
            cell.tab = nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TabViewCell, case .some(.tab(let tab)) = viewModel?.entry(at: indexPath) {
            cell.tab = tab
        }
    }
}
