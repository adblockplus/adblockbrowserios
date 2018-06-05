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

import CoreData
import RxSwift
import UIKit

final class BookmarksViewController: ViewController<BookmarksViewModel>,
    UITableViewDataSource,
    UITableViewDelegate {
    static let cellIdentifier = "cell"

    private var noBookmarksAvailableLabel: UILabel?

    private let editButton = UIBarButtonItem()
    private let doneButton = UIBarButtonItem()

    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var navigationBar: UINavigationBar?

    override func viewDidLoad() {
        super.viewDidLoad()

        editButton.title = NSLocalizedString("Edit", comment: "Bookmarks listing")
        doneButton.title = NSLocalizedString("Done", comment: "Bookmarks listing")
        navigationBar?.topItem?.title = NSLocalizedString("Bookmarked Pages", comment: "Bookmarks listing")
    }

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    // swiftlint:disable:next function_body_length
    override func observe(viewModel: ViewModelEx) {
        viewModel.isGhostModeEnabled.asDriver()
            .drive(onNext: { [weak self] isGhostModeEnabled in
                self?.view.backgroundColor = isGhostModeEnabled ? .abbGhostMode: .white
                self?.navigationBar?.titleTextAttributes = [
                    NSAttributedStringKey.foregroundColor: isGhostModeEnabled ? UIColor.white : UIColor.abbSlateGray
                ]
                self?.navigationBar?.barTintColor = isGhostModeEnabled ? .abbGhostMode : .white
                // show/hide bottom seperator
                self?.navigationBar?.clipsToBounds = isGhostModeEnabled
                self?.tableView?.separatorColor = isGhostModeEnabled ? .abbCharcoalGray : .abbLightGray
            })
            .addDisposableTo(disposeBag)

        viewModel.isEditing.asDriver()
            .drive(onNext: { [weak self] isEditing in
                self?.tableView?.setEditing(isEditing, animated: true)

                if let bar = self?.navigationBar {
                    UIView.transition(with: bar, duration: animationDuration, options: .transitionCrossDissolve, animations: {
                        bar.items?.first?.rightBarButtonItem = isEditing ? self?.doneButton : self?.editButton
                    })
                }
            })
            .addDisposableTo(disposeBag)

        editButton.rx.tap.asObservable()
            .subscribe(onNext: { [weak self] () in
                self?.viewModel?.enterEditMode()
            })
            .addDisposableTo(disposeBag)

        doneButton.rx.tap.asObservable()
            .subscribe(onNext: { [weak self] () in
                self?.viewModel?.leaveEditMode()
            })
            .addDisposableTo(disposeBag)

        tableView?.reloadData()

        viewModel.modelChanges
            .filter { $0.count > 0 }
            .subscribe(onNext: { [weak tableView] changes in
                tableView?.beginUpdates()
                for change in changes {
                    switch change {
                    case .deleteItems(let indexPaths):
                        tableView?.deleteRows(at: indexPaths, with: .automatic)
                    case .insertItems(let indexPaths):
                        tableView?.insertRows(at: indexPaths, with: .automatic)
                    case .reloadItems(let indexPaths):
                        tableView?.reloadRows(at: indexPaths, with: .automatic)
                    case .moveItem:
                        // Move event is not emitted
                        assert(false)
                    }
                }
                tableView?.endUpdates()
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = viewModel?.bookmarksCount() ?? 0

        if count == 0 && noBookmarksAvailableLabel == nil {
            let label = UILabel()
            label.text = NSLocalizedString("No Bookmarks Available", comment: "Bookmarks listing")
            label.font = .systemFont(ofSize: 16)
            label.textColor = .abbCoolGray
            label.textAlignment = .center
            label.sizeToFit()
            noBookmarksAvailableLabel = label
            mount(label: label, inView: view)
        }

        noBookmarksAvailableLabel?.isHidden = count != 0
        tableView.isHidden = count == 0
        editButton.isEnabled = count != 0

        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: type(of: self).cellIdentifier, for: indexPath)

        if let bookmarkCell = cell as? BookmarkCell, let bookmark = viewModel?.bookmark(for: indexPath) {
            bookmarkCell.set(bookmark: bookmark)
            bookmarkCell.isGhostModeStyleUsed = viewModel?.isGhostModeEnabled.value ?? false
        }

        return cell
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Disable swipe to delete
        return viewModel?.isEditing.value ?? false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, let bookmark = viewModel?.bookmark(for: indexPath) {
            viewModel?.delete(bookmark: bookmark)
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        viewModel?.didMoveBookmark(at: sourceIndexPath, to: destinationIndexPath)
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // This value fixes 36px offset of tableView's content
        return .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let bookmark = viewModel?.bookmark(for: indexPath) {
            if viewModel?.isEditing.value ?? false {
                edit(bookmark: bookmark)
            } else {
                viewModel?.load(bookmark: bookmark)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Private

    func edit(bookmark: BookmarkExtras) {
        if let viewModel = viewModel {
            let viewModel = EditBookmarkViewModel(components: viewModel.components,
                                                  bookmark: bookmark,
                                                  isGhostModeEnabled: viewModel.isGhostModeEnabled,
                                                  viewWillBeDismissed: PublishSubject<Void>())
            performSegue(withIdentifier: "EditBookmarkSegue", sender: viewModel)
        }
    }
}

private func mount(label: UILabel, inView view: UIView?) {
    if let view = view {
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        view.addConstraint(NSLayoutConstraint(item: label,
                                              attribute: .centerY,
                                              relatedBy: .equal,
                                              toItem: view,
                                              attribute: .centerY,
                                              multiplier: 1.0,
                                              constant: 0.0))

        // horizontal margins
        view.addConstraint(NSLayoutConstraint(
            item: label, attribute: .leading,
            relatedBy: .equal,
            toItem: view, attribute: .leading,
            multiplier: 1.0, constant: 30.0))
        view.addConstraint(NSLayoutConstraint(
            item: view, attribute: .trailing,
            relatedBy: .equal,
            toItem: label, attribute: .trailing,
            multiplier: 1.0, constant: 30.0))
        view.setNeedsDisplay()
    } else {
        label.removeFromSuperview()
    }
}
