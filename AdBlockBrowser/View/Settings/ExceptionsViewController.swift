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

import AttributedMarkdown
import Foundation
import RxSwift

final class ExceptionsViewController: SettingsTableViewController<ExceptionsViewModel>, SwitchCellDelegate {
    enum Sections: Int {
        case acceptableAds = 0
        case whitelistedSites = 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = localize("Exceptions", comment: "Exceptions settings - title")
    }

    // MARK: - MVVM

    private let disposeBag = DisposeBag()

    override func observe(viewModel: ViewModelEx) {
        super.observe(viewModel: viewModel)

        viewModel.isAcceptableAdsEnabled.asDriver()
            .drive(onNext: { [weak self] _ in
                self?.tableView?.reloadSections(IndexSet(integer: Sections.acceptableAds.rawValue), with: .automatic)
            })
            .addDisposableTo(disposeBag)

        viewModel.whitelistedSitesChanges
            .subscribe(onNext: { [weak self] change in
                switch change {
                case .reload:
                    self?.tableView?.reloadSections(IndexSet(integer: Sections.whitelistedSites.rawValue),
                                                    with: .automatic)
                case .removeItemAt(let index):
                    self?.tableView?.deleteRows(at: [IndexPath(row: index, section: Sections.whitelistedSites.rawValue)],
                                                with: .automatic)
                }
            })
            .addDisposableTo(disposeBag)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if Sections(rawValue: section) == .some(.acceptableAds) {
            return 2
        } else {
            return viewModel?.whitelistedSites?.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if Sections(rawValue: indexPath.section) == .some(.acceptableAds) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.selectionStyle = .default
            let isAcceptableAdsEnabled = viewModel?.isAcceptableAdsEnabled.value ?? false
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = localize("Show nonintrusive ads",
                                                comment: "Exceptions settings - acceptable ads option")
                cell.accessoryType = isAcceptableAdsEnabled ? .checkmark : .none
            case 1:
                cell.textLabel?.text = localize("Hide all ads",
                                                comment: "Exceptions settings - acceptable ads option")
                cell.accessoryType = isAcceptableAdsEnabled ? .none : .checkmark
            default:
                break
            }
            return cell
        } else {
            let entry = viewModel?.whitelistedSites?[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "whitelistedSiteCell", for: indexPath)
            cell.selectionStyle = .none
            cell.textLabel?.text = entry?.site
            if let cell = cell as? SwitchCell {
                cell.isOn = entry?.isWhitelisted ?? false
                cell.delegate = self
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as? SettingsHeader else {
            return nil
        }

        let text: String
        let detailText: String

        switch Sections(rawValue: section) {
        case .some(.acceptableAds):
            text = localize("exceptions_settings_acceptable_ads_title",
                            comment: "Exceptions settings - section title")
            detailText = localize("exceptions_settings_acceptable_ads_description",
                                  comment: "Exceptions settings - section description")
        case .some(.whitelistedSites):
            text = localize("exceptions_settings_whitelisted_websites_title",
                            comment: "Exceptions settings - section title")
            detailText = localize("exceptions_settings_whitelisted_websites_description",
                                  comment: "Exceptions settings - section description")
        default:
            return header
        }

        let innerAttributes = [
            NSAttributedString.Key.link: URL(string: "https://acceptableads.com/users")! as Any,
            NSAttributedString.Key.foregroundColor: #colorLiteral(red: 0, green: 0.462745098, blue: 1, alpha: 1)
        ]

        let attributes = [NSNumber(value: EMPH.rawValue): innerAttributes]

        let attrString = attributedStringFromMarkdown(detailText, attributes: attributes)

        if let attrString = attrString, let font = header.detailTextLabel?.font {
            let attributedText = NSMutableAttributedString(attributedString: attrString)
            let range = NSRange(location: 0, length: attributedText.length)
            attributedText.addAttribute(NSAttributedString.Key.font, value: font, range: range)
            header.attributedDetailText = attributedText
        } else {
            header.detailText = detailText
        }
        header.text = text

        if (header.gestureRecognizers?.count ?? 0) == 0 {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGestureRecognizerTap(_:)))
            header.addGestureRecognizer(recognizer)
        }

        return header
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Sections(rawValue: indexPath.section), section == .acceptableAds else {
            return
        }

        let isAcceptableAdsEnabled: Bool
        switch indexPath.row {
        case 0:
            isAcceptableAdsEnabled = true
        case 1:
            isAcceptableAdsEnabled = false
        default:
            return
        }

        viewModel?.isAcceptableAdsEnabled.value = isAcceptableAdsEnabled
        viewModel?.extensionFacade.setAcceptableAdsEnabled(isAcceptableAdsEnabled)
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if Sections(rawValue: indexPath.section) == .some(.whitelistedSites) {
            return .delete
        } else {
            return .none
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, Sections(rawValue: indexPath.section) == .some(.whitelistedSites) {
            viewModel?.removeSite(at: indexPath.row)
        }
    }

    // MARK: - SwitchCellDelegate

    func switchValueDidChange(_ sender: SwitchCell) {
        guard let indexPath = tableView.indexPath(for: sender),
            let entry = viewModel?.whitelistedSites?[indexPath.row] else {
                return
        }

        viewModel?.site(entry.site, isWhitelisted: !entry.isWhitelisted)
    }

    // MARK: - Action

    @objc
    func handleGestureRecognizerTap(_ sender: UITapGestureRecognizer) {
        if sender.state != .ended {
            return
        }

        guard let header = sender.view as? SettingsHeader, let textLabel = header.detailTextLabel else {
            return
        }

        let point = sender.location(in: header)
        let location = header.convert(point, to: textLabel)

        guard let url = extractUrl(at: location, from: textLabel) else {
            return
        }

        viewModel?.components.browserController?.showNewTab(with: url, fromSource: nil)
        dismiss(animated: true, completion: nil)
    }
}

func extractUrl(at location: CGPoint, from label: UILabel) -> URL? {
    guard let attributedText = label.attributedText else {
        return nil
    }

    let layoutManager = NSLayoutManager()
    let textStorage = NSTextStorage(attributedString: attributedText)
    textStorage.addLayoutManager(layoutManager)

    let textContainer = NSTextContainer(size: label.frame.size)
    textContainer.lineFragmentPadding = 0
    textContainer.maximumNumberOfLines = label.numberOfLines
    textContainer.lineBreakMode = label.lineBreakMode
    layoutManager.addTextContainer(textContainer)
    layoutManager.textStorage = textStorage

    let characterIndex = layoutManager.characterIndex(for: location,
                                                      in: textContainer,
                                                      fractionOfDistanceBetweenInsertionPoints: nil)

    var range = NSRange()
    let attributes = attributedText.attributes(at: characterIndex, effectiveRange: &range)

    return attributes[NSAttributedString.Key.link] as? URL
}
