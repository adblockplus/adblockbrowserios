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

import UIKit

enum SearchEngine: NSNumber {
    case duckDuckGo = 0
    case google = 1
    case baidu = 2
}

protocol SearchEngineProtocol: class {
    var name: String { get }
    var provider: SuggestionProviderType { get }

    func keywordSearchURLStringWithQuery(_ phrase: String) -> String
}

private final class DuckDuckGoSearchEngine: SearchEngineProtocol {
    let name = NSLocalizedString("DuckDuckGo",
                                 comment: "Search Engine Selection")

    let provider = SuggestionProviderDuckDuckGo

    func keywordSearchURLStringWithQuery(_ phrase: String) -> String {
        let query = phrase.stringByEncodingToURLSafeFormat() ?? ""
        return String(format: "https://duckduckgo.com/?t=abpbrowser&q=%@", query)
    }
}

private final class GoogleSearchEngine: SearchEngineProtocol {
    let name = NSLocalizedString("Google",
                                 comment: "Search Engine Selection")

    let provider = SuggestionProviderGoogle

    func keywordSearchURLStringWithQuery(_ phrase: String) -> String {
        return Settings.keywordSearchURLString(withQuery: phrase)
    }
}

private final class BaiduSearchEngine: SearchEngineProtocol {
    let name = NSLocalizedString("Baidu",
                                 comment: "Search Engine Selection")

    let provider = SuggestionProviderBaidu

    func keywordSearchURLStringWithQuery(_ phrase: String) -> String {
        let query = phrase.stringByEncodingToURLSafeFormat() ?? ""
        return String(format: "http://www.baidu.com/s?wd=%@", query)
    }
}

let duckDuckGoSearchEngine: SearchEngineProtocol = DuckDuckGoSearchEngine()

let googleSearchEngine: SearchEngineProtocol = GoogleSearchEngine()

let baiduSearchEngine: SearchEngineProtocol = BaiduSearchEngine()

func searchEngine(from index: Int) -> SearchEngineProtocol? {
    switch index {
    case 0:
        return duckDuckGoSearchEngine
    case 1:
        return googleSearchEngine
    case 2:
        return baiduSearchEngine
    default:
        return nil
    }
}

func searchEngineFromProvider(_ value: UInt32) -> SearchEngineProtocol? {
    return [
        SuggestionProviderDuckDuckGo.rawValue: duckDuckGoSearchEngine,
        SuggestionProviderGoogle.rawValue: googleSearchEngine,
        SuggestionProviderBaidu.rawValue: baiduSearchEngine
        ][value]
}

extension UserDefaults {
    func selectedSearchEngine() -> SearchEngineProtocol {
        let defaults = UserDefaults.standard
        if let engineNumber = defaults.object(forKey: defaultsKeyAutocompleteSearchEngine) as? NSNumber,
            let engine = searchEngineFromProvider(engineNumber.uint32Value) {
            return engine
        } else {
            let currentLocale = Locale.current
            if let countryCode = (currentLocale as NSLocale).object(forKey: NSLocale.Key.countryCode) as? String {
                if countryCode.lowercased() == "cn" {
                    return baiduSearchEngine
                }
            }
            return duckDuckGoSearchEngine
        }
    }
}

final class SearchEnginesViewController: SettingsTableViewController<SearchEnginesViewModel> {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Search Engine",
                                                 comment: "Search Engine Selection")
    }

    // UITableViewDataSource

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if let engine = searchEngine(from: indexPath.row) {
            cell.textLabel?.text = engine.name
            let selectedEngine = UserDefaults.standard.selectedSearchEngine()
            cell.accessoryType = selectedEngine === engine ? .checkmark : .none
        }

        return cell
    }

    // UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let engine = searchEngine(from: indexPath.row) {
            let defaults = UserDefaults.standard
            defaults.set(NSNumber(value: engine.provider.rawValue),
                         forKey: defaultsKeyAutocompleteSearchEngine)
            defaults.synchronize()
        }
        tableView.reloadData()
    }
}
