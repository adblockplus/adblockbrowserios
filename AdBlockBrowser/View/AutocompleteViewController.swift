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
import UIKit

/// Three states of this value:
/// Not set - Google suggestions disabled, prompt shown
/// false - Google suggestions disabled, prompt hidden
/// true - Google suggestions enabled, prompt hidden
let defaultsKeyAutocomplete = "AutocompleteEnabled"
let defaultsKeyAutocompleteSearchEngine = "AutocompleteSearchEngine"

private let yesButtonTag = 100050
private let noButtonTag = yesButtonTag + 1
private let headlineLabelTag = yesButtonTag + 2
private let questionLabelTag = yesButtonTag + 3
private let noteLabelTag = yesButtonTag + 4

private let promptHeight = CGFloat(122)

enum AutocompleteResult {
    case findInPage(String)
    case search(String)
}

// swiftlint:disable:next type_body_length
final class AutocompleteViewController: TableViewController<AutocompleteViewModel> {
    let autocompleteTimeout = TimeInterval(0.2)

    // Called when autocomplete suggestion is selected
    var onAutocompleteItemSelected: ((AutocompleteResult) -> Void)?

    // Sections are pre-created with empty list of suggestions and only suggestion lists are
    // pulled in. This way a stable ordering of sections is ensured.
    fileprivate var suggestionSections = [Section]()
    fileprivate var queryChangeTimeout = Timer()

    fileprivate let separator = UIView()
    fileprivate var lastQuery: String?

    fileprivate struct AutocompleteSection {
        var type: SuggestionProviderType
        var label: String
        var rowIcon: UIImage?
        var suggestions: [OmniboxSuggestion]?
    }

    fileprivate enum Section {
        // Section with prompt
        case prompt
        // Find in page section
        case findInPage(UInt, String)
        // Section with autocomplete
        case autocomplete(AutocompleteSection)
    }

    fileprivate let sectionFactory: [AutocompleteSection] = [
        AutocompleteSection(
            type: SuggestionProviderHistory,
            label: NSLocalizedString("Search History", comment: "Autocomplete suggestions"),
            rowIcon: nil,
            suggestions: nil
        ),
        AutocompleteSection(
            type: SuggestionProviderGoogle,
            label: NSLocalizedString("Google search", comment: "Autocomplete suggestions"),
            rowIcon: UIImage(named: "search_24"),
            suggestions: nil
        ),
        AutocompleteSection(
            type: SuggestionProviderDuckDuckGo,
            label: NSLocalizedString("DuckDuckGo search", comment: "Autocomplete suggestions"),
            rowIcon: UIImage(named: "search_24"),
            suggestions: nil
        ),
        AutocompleteSection(
            type: SuggestionProviderBaidu,
            label: NSLocalizedString("Baidu search", comment: "Autocomplete suggestions"),
            rowIcon: UIImage(named: "search_24"),
            suggestions: nil
        )
    ]

    // MARK: - ControllerComponentsInjectable

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(userDefaultsDidChange(_:)),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var hidden: Bool {
        get {
            return tableView.isHidden
        }
        set {
            // Behavour of safari is preferred, it does not removes all items right after user types something
            if tableView.isHidden == newValue {
                return
            }

            if newValue {
                lastQuery = nil
                queryChangeTimeout.invalidate()
            }

            tableView.isHidden = newValue
            tableView.superview?.isHidden = newValue
            if !newValue {
                // When hiding, clear the data too so that it does not blink when unhiding again
                suggestionSections.removeAll(keepingCapacity: true)
                // Commit changes ^^^
                tableView.reloadData()
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        tryInjectToController(segue.destination)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = UINib(nibName: "GoogleSearchPrompt", bundle: Bundle.main)
        tableView?.register(nib, forCellReuseIdentifier: "GoogleSearchPrompt")
        tableView?.isHidden = true
        tableView?.scrollsToTop = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Separator is just only design feature, it seperated address bar from suggestions
        if separator.superview == nil {
            separator.backgroundColor = UIColor(white: CGFloat(161) / CGFloat(255), alpha: 1.0)
            separator.translatesAutoresizingMaskIntoConstraints = false
            tableView?.superview?.addSubview(separator)
            tableView?.superview?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[separator]-0-|",
                                                                                options: NSLayoutConstraint.FormatOptions(),
                                                                                metrics: nil,
                                                                                views: ["separator": separator]))
            tableView?.superview?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[separator(0.5)]",
                                                                                options: NSLayoutConstraint.FormatOptions(),
                                                                                metrics: nil,
                                                                                views: ["separator": separator]))
        }
    }

    // swiftlint:disable:next function_body_length
    func searchQueryChangedTo(_ query: String) {
        queryChangeTimeout.invalidate()
        if UInt(query.count) < (viewModel?.autocompleteDataSource.minimumCharactersToTrigger())! {
            lastQuery = nil
            hidden = true
        } else {
            lastQuery = query
            hidden = false // show autocomplete

            let innerBlock = { [weak self] (results: [AnyHashable: Any]?) -> Void in
                guard let results = results else {
                    return
                }
                // clear current array of sections
                self?.suggestionSections.removeAll(keepingCapacity: true)

                if UserDefaults.standard.object(forKey: defaultsKeyAutocomplete) == nil {
                    self?.suggestionSections.append(.prompt)
                }

                if let findInPage = (results[NSNumber(value: SuggestionProviderFindInPage.rawValue)] as? [OmniboxSuggestion])?.first {
                    let count = UInt(findInPage.phrase) ?? 0
                    self?.suggestionSections.append(.findInPage(count, query))
                }

                for (key, obj) in results {
                    if let suggestions = obj as? [OmniboxSuggestion], suggestions.count > 0,
                        let number = (key as? NSNumber)?.uint32Value,
                        let index = self?.sectionFactory.index(where: { $0.type.rawValue == number }),
                        let mold = self?.sectionFactory[index] {
                        var moldCopy = mold
                        // take the right section definition from factory and attach the
                        // latest autocompleted rows
                        moldCopy.suggestions = suggestions
                        // add the definition back to sections
                        self?.suggestionSections.append(.autocomplete(moldCopy))
                    }
                }
                self?.tableView.reloadData()
            }

            // wait for autocompleteTimeout before querying the data source
            if #available(iOS 10.0, *) {
                queryChangeTimeout
                    = Timer.scheduledTimer(withTimeInterval: autocompleteTimeout,
                                           repeats: false,
                                           block: { _ in
                                            self.viewModel?.autocompleteDataSource.items(for: query,
                                                                                         result: innerBlock)
                                            return
                    })
            } else {
                queryChangeTimeout
                    = Timer.scheduledTimer(withTimeInterval: autocompleteTimeout,
                                           block: { [weak self] () in
                                            self?.viewModel?.autocompleteDataSource.items(for: query,
                                                                                          result: innerBlock)
                                            return
                        },
                                           // swiftlint:disable:next force_cast
                        repeats: false) as! Timer
            }
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return suggestionSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch suggestionSections[section] {
        case .prompt:
            return 1
        case .findInPage:
            return 1
        case let .autocomplete(section):
            return section.suggestions?.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch suggestionSections[section] {
        case .prompt:
            return nil
        case .findInPage(let count, _):
            let header = NSLocalizedString("Find in page (%@ matches)", comment: "Find in page - Autocomplete controller")
            return String(format: header, count.description)
        case .autocomplete(let section):
            return section.label
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        switch suggestionSections[indexPath.section] {
        case .prompt:
            cell = tableView.dequeueReusableCell(withIdentifier: "GoogleSearchPrompt", for: indexPath)
            for tag in [yesButtonTag, noButtonTag] {
                if let button = cell.contentView.viewWithTag(tag) as? UIButton {
                    button.layer.masksToBounds = true
                    button.layer.cornerRadius = 2
                    button.addTarget(self, action: #selector(AutocompleteViewController.onYesNoButtonTouch(_:)), for: .touchUpInside)
                }
            }

            let headlineText = NSLocalizedString("URL Search Suggestions", comment: "Headline of search approval confirmation")
            let questionText = NSLocalizedString("Do you want to see web search results here?", comment: "Question of search approval confirmation")
            let noteText = NSLocalizedString("Configurable under *Settings > URL Search Suggestions*",
                                             comment: "Note of search approval confirmation")

            let attributes = [
                NSNumber(value: EMPH.rawValue): [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 12)]
            ]

            let noteAttributedText = attributedStringFromMarkdown(noteText, attributes: attributes)

            (cell.contentView.viewWithTag(headlineLabelTag) as? UILabel)?.text = headlineText
            (cell.contentView.viewWithTag(questionLabelTag) as? UILabel)?.text = questionText
            (cell.contentView.viewWithTag(noteLabelTag) as? UILabel)?.attributedText = noteAttributedText
            (cell.contentView.viewWithTag(yesButtonTag) as? UIButton)?.setTitle(NSLocalizedString("Yes", comment: "Allow Google search"),
                                                                                for: UIControl.State())
            (cell.contentView.viewWithTag(noButtonTag) as? UIButton)?.setTitle(NSLocalizedString("No", comment: "Deny Google search"),
                                                                               for: UIControl.State())
        case .findInPage:
            cell = tableView.dequeueReusableCell(withIdentifier: "AutocompleteCell", for: indexPath)
            cell.imageView?.image = nil
            let header = NSLocalizedString("Find \"%@\" in page", comment: "Find in page - Autocomplete controller")
            cell.textLabel?.text = String(format: header, lastQuery ?? "")
        case let .autocomplete(section):
            cell = tableView.dequeueReusableCell(withIdentifier: "AutocompleteCell", for: indexPath)
            cell.imageView?.image = section.rowIcon
            if let suggestion = section.suggestions?[indexPath.row] {
                cell.textLabel?.text = suggestion.phrase
            }
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch suggestionSections[indexPath.section] {
        case .prompt:
            break
        case .findInPage(_, let query):
            onAutocompleteItemSelected?(.findInPage(query))
        case .autocomplete(let section):
            if let section = section.suggestions?[indexPath.row].phrase {
                onAutocompleteItemSelected?(.search(section))
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch suggestionSections[indexPath.section] {
        case .prompt:
            return promptHeight
        default:
            return tableView.rowHeight
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Prompt is not selectable
        switch suggestionSections[indexPath.section] {
        case .prompt:
            return false
        default:
            return true
        }
    }

    // MARK: - Actions

    @objc
    func onYesNoButtonTouch(_ button: UIButton) {
        UserDefaults.standard.set(button.tag == yesButtonTag, forKey: defaultsKeyAutocomplete)
        UserDefaults.standard.synchronize()

        // Removes item with nice fade-out animation
        switch suggestionSections.first {
        case .some(.prompt):
            suggestionSections.remove(at: 0)
            tableView.deleteSections(IndexSet(integer: 0), with: .fade)
        default:
            break
        }
    }

    @objc
    func userDefaultsDidChange(_ notification: Notification) {
        if notification.object as? UserDefaults === UserDefaults.standard {
            viewModel?.updateProviders()
            let enabled = UserDefaults.standard.bool(forKey: defaultsKeyAutocomplete)
            if enabled && !hidden, let query = lastQuery {
                searchQueryChangedTo(query)
            }
        }
    }
}
