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
import UIKit

final class HistoryViewController: ViewController<HistoryViewModel>,
    UITableViewDataSource,
    UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.register(TableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")

        navigationItem.title =
            NSLocalizedString("Recent History", comment: "Browser history list")
        navigationItem.rightBarButtonItem?.title =
            NSLocalizedString("Delete", comment: "Browser history list")
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.setToolbarHidden(false, animated: animated)
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
        navigationController?.setToolbarHidden(true, animated: animated)
        super.viewWillDisappear(animated)
    }

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    override func observe(viewModel: HistoryViewModel) {
        viewModel.changes
            .subscribe(onNext: { [weak tableView] changes in
                tableView?.beginUpdates()
                tableView?.deleteSections(changes.deletedSections, with: .automatic)
                tableView?.insertSections(changes.insertedSections, with: .automatic)
                tableView?.deleteRows(at: changes.deletedItems, with: .automatic)
                tableView?.insertRows(at: changes.insertedItems, with: .automatic)
                tableView?.reloadRows(at: changes.updatedItems, with: .automatic)
                tableView?.endUpdates()
            })
            .addDisposableTo(disposeBag)
    }

    var fetchedResultsController: NSFetchedResultsController<HistoryUrl>? {
        return viewModel?.adapter?.fetchedResultsController
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // This section logic was implemented in delegate method,
        // but it was causing lot of crashes in the production,
        // so that delegate is responsible only for visual appearence,
        // and dataSource is only responsible for section name.
        // All formatting is done in delegate method, because
        // UITableView is converting header to uppercase.
        return fetchedResultsController?.sections?[section].name
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController?.sections?[section].numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        if let cell = cell as? HistoryCell, let item = fetchedResultsController?.object(at: indexPath) {
            cell.set(historyUrl: item)
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 23
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func tableView (_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? TableViewHeaderFooterView
        header?.insets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        header?.textLabel?.numberOfLines = 1
        return header
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // If view is not instance of UITableViewHeaderFooterView (not sure if it is possible),
        // then section header will display valid name, but not formatted.
        guard let header = view as? UITableViewHeaderFooterView else {
            return
        }

        // Date is extracted from header text and not from any object in section.
        // Previous solution was causing lot of crashes, when there were too many items in the section,
        // and first object was not loaded (lazy load).
        let date: Date
        if let text = header.textLabel?.text, let time = TimeInterval(text) {
            date = Date(timeIntervalSince1970: time)
        } else {
            date = Date()
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        dateFormatter.doesRelativeDateFormatting = false
        let dateString = dateFormatter.string(from: date).uppercased()

        let attributes = [
            NSAttributedStringKey.foregroundColor: UIColor.abbSlateGray,
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 13)
        ]

        header.textLabel?.attributedText = NSAttributedString(string: dateString, attributes: attributes)
        header.contentView.backgroundColor = .abbLightGray
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.contentView.backgroundColor = .abbLightGray
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let historyUrl = fetchedResultsController?.object(at: indexPath) {
            navigationController?.popViewController(animated: true)
            // Postpone url loading by one run-loop cycle
            // This will make pop animation more smoother
            DispatchQueue.main.async { [viewModel] () in
                viewModel?.load(historyUrl: historyUrl)
            }
        }
    }

    // MARK: - Actions

    @IBAction func onDeleteButtonTouched(_ sender: UIButton?) {
        let title = NSLocalizedString("Clear History?",
                                      comment: "Clear history alert title")
        let message = NSLocalizedString("Are you sure you want to clear history? You cannot undo this action.",
                                        comment: "Clear history alert message")
        let clearButton = NSLocalizedString("Clear",
                                            comment: "Clear history alert clear button title")
        let cancelButton = NSLocalizedString("Cancel",
                                             comment: "Clear history alert cancel button title")

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let historyManager = self.viewModel?.historyManager {
            alert.addAction(UIAlertAction(title: clearButton, style: .destructive) { _ in
                historyManager.deleteBrowsingHistoryOlderThan(0)
                historyManager.deleteSuggestionsOlderThan(0)
            })
        }
        // Type of the second button cannot be cancel, otherwise it is on the first position
        alert.addAction(UIAlertAction(title: cancelButton, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
