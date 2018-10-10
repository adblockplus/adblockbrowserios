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

func bundleLocalizedString(_ key: String, comment: String) -> String {
    return NSLocalizedString(key, bundle: Settings.coreBundle(), comment: comment)
}

final class EditBookmarkViewController: ViewController<EditBookmarkViewModel>, UITextFieldDelegate {
    @IBOutlet weak var statusBar: UIView?
    @IBOutlet weak var navigationBar: UINavigationBar?
    @IBOutlet weak var firstSectionView: UIView?
    @IBOutlet weak var secondSectionView: UIView?
    @IBOutlet var rulers: [UIView] = []

    @IBOutlet weak var titleTextField: UITextField?
    @IBOutlet weak var urlTextField: UITextField?
    @IBOutlet weak var imageView: UIImageView?
    @IBOutlet weak var imageWidthConstraint: NSLayoutConstraint?
    @IBOutlet weak var showInDashboardLabel: UILabel?
    @IBOutlet weak var showInDashboardSwitch: UISwitch?
    @IBOutlet weak var deleteBookmarkButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        let cancelTitle = localize("Cancel", comment: "Edit bookmark view - Cancel button")
        let doneTitle = localize("Done", comment: "Edit bookmark view - Done button")

        let item = navigationBar?.topItem
        item?.leftBarButtonItem = UIBarButtonItem(title: cancelTitle,
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(dismissBookmarkChanges))
        item?.rightBarButtonItem = UIBarButtonItem(title: doneTitle,
                                                   style: .plain,
                                                   target: self,
                                                   action: #selector(commitBookmarkChanges))
        item?.title = bundleLocalizedString("Edit Bookmark", comment: "Bookmark view controller")

        titleTextField?.placeholder = NSLocalizedString("Enter title",
                                                        comment: "Bookmark editing placeholder")
        urlTextField?.placeholder = NSLocalizedString("Enter link",
                                                      comment: "Bookmark editing placeholder")
        showInDashboardLabel?.text = NSLocalizedString("Show in Dashboard",
                                                       comment: "Bookmark editing switch")
        deleteBookmarkButton?.setTitle(NSLocalizedString("Delete Bookmark",
                                                         comment: "Bookmark deleting button"), for: UIControl.State())
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        viewModel?.viewWillBeDismissed.onNext(())
        super.dismiss(animated: flag, completion: completion)
    }

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    override func observe(viewModel: ViewModelEx) {
        viewModel.isGhostModeEnabled.asDriver()
            .drive(onNext: { [weak self] isGhostModeEnabled in
                self?.updateStyle(to: isGhostModeEnabled)
            })
            .addDisposableTo(disposeBag)

        titleTextField?.text = viewModel.bookmark.title
        urlTextField?.text = viewModel.bookmark.url
        if let data = viewModel.bookmark.icon?.iconData {
            imageView?.image = UIImage(data: data)
        } else {
            imageView?.image = nil
        }

        showInDashboardSwitch?.isOn = viewModel.bookmark.abp_showInDashboard

        if imageView?.image == nil {
            imageWidthConstraint?.constant = 0
        }
    }

    func updateStyle(to isGhostModeEnabled: Bool) {
        statusBar?.backgroundColor = isGhostModeEnabled ? .abbGhostMode : .white
        navigationBar?.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: isGhostModeEnabled ? UIColor.white : UIColor.abbSlateGray
        ]
        navigationBar?.barTintColor = isGhostModeEnabled ? .abbGhostMode : .white

        // show/hide bottom seperator
        navigationBar?.clipsToBounds = isGhostModeEnabled

        firstSectionView?.backgroundColor = isGhostModeEnabled ? .abbGhostMode : .white
        secondSectionView?.backgroundColor = isGhostModeEnabled ? .abbGhostMode : .white

        for ruler in rulers {
            ruler.backgroundColor = isGhostModeEnabled ? .abbCharcoalGray : .abbRulerGray
        }

        view.backgroundColor = isGhostModeEnabled ? .abbCharcoalGray : .abbLightGray

        titleTextField?.textColor = isGhostModeEnabled ? .abbSilver : .abbGhostMode
        showInDashboardLabel?.textColor = isGhostModeEnabled ? .abbSilver : .abbGhostMode
    }

    // MARK: - Actions

    @IBAction func onChange(_ sender: UITextField?) {
        // Button is disabled if the link is not valid
        if sender == urlTextField {
            navigationBar?.topItem?.rightBarButtonItem?.isEnabled = urlTextField?.text?.urlValue() != nil
        }
    }

    @IBAction func onDeleteBookmarkButtomTouched(_ sender: UIButton) {
        let title = NSLocalizedString("Delete Bookmark",
                                      comment: "Delete Bookmark alert title")
        let message = NSLocalizedString("Are you sure you want to delete this bookmark?",
                                        comment: "Delete Bookmark alert message")
        let clearButton = NSLocalizedString("Delete",
                                            comment: "Delete Bookmark alert delete button title")
        let cancelButton = NSLocalizedString("Cancel",
                                             comment: "Delete Bookmark alert cancel button title")

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: clearButton, style: .destructive) { [weak self] _ in
            self?.viewModel?.deleteBookmark()
            self?.dismiss(animated: true, completion: nil)
        })

        // Type of the second button cannot be cancel, otherwise it is on the first position
        alert.addAction(UIAlertAction(title: cancelButton, style: .default, handler: nil))

        UIHandler.presentModal(alert, inController: self)
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    // MARK: - Private

    @objc
    private func dismissBookmarkChanges(_ sender: Any?) {
        dismiss(animated: true, completion: nil)
    }

    @objc
    private func commitBookmarkChanges(_ sender: Any?) {
        viewModel?.updateBookmark(with: titleTextField?.text,
                                  url: urlTextField?.text,
                                  showInDashboard: showInDashboardSwitch?.isOn ?? false)
        dismiss(animated: true, completion: nil)
    }
}
