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

import Foundation

// Notifying about URL opening needs to be done in 3 phases
// 1. URL to be opened is known right away (BrowserHistoryObserver)
// 2. the loading may not even finish to a state when document.title is queryable
// 3. it may finish or it may fail with error
public protocol BrowserHistoryDelegate: NSObjectProtocol {
    func onTabId(_ tabId: UInt, didStartLoading url: URL?)

    func onTabId(_ tabId: UInt, cancelledLoading url: URL?)

    func onTabId(_ tabId: UInt, didReplaceCurrentWith url: URL?)

    func onTabIdDidGoBack(_ tabId: UInt)

    func onTabIdDidGoForward(_ tabId: UInt)
}

/**
 An observer of content UIWebView's URL navigation.
 It used to be the primary source for (can)GoBack/Forward, hence it keeps
 per-tab browsing history in CoreData. Now that UIWebView's embedded history
 is used exclusively, this part of stored data is redundant. But i'm keeping
 it, including tracking the current position reflected from UIWebView because
 it still may come in handy - e.g. displaying a list of prev/next pages when
 long tapping on prev/next arrows (Chrome/iOS does it).
 */
public final class BrowserHistoryManager: NSObject {
    fileprivate let coreData: BrowserStateCoreData

    public let globalHistoryController: NSFetchedResultsController<HistoryUrl>

    public init(coreData: BrowserStateCoreData) {
        self.coreData = coreData

        // set up a model controller for browser history view
        let visibilityPred = NSPredicate(format: "%K == \(false)", "hidden")
        let phraseAll: NSFetchRequest<HistoryUrl> = coreData.fetchRequest(with: visibilityPred)
        phraseAll.fetchLimit = 50
        phraseAll.sortDescriptors = [NSSortDescriptor(key: "url", ascending: false)]
        phraseAll.relationshipKeyPathsForPrefetching = ["icon"]
        self.globalHistoryController = coreData.fetchController(for: phraseAll, withCacheName: "")

        super.init()
    }

    func currentHistory(for url: URL,
                        andDate date: Date,
                        withIconPrefetch iconPrefetch: Bool) -> (history: HistoryUrl?, icon: UrlIcon?, title: String?) {
        guard let urlExists = createFetchRequest(for: url) else {
            return (nil, nil, nil)
        }

        if iconPrefetch {
            urlExists.relationshipKeyPathsForPrefetching = ["icon"]
        }

        guard let results = coreData.resultsOfFetchWithErrorAlert(urlExists) else {
            return (nil, nil, nil)
        }

        var foundTitle: String?
        var foundIcon: UrlIcon?

        for history in results {
            if let icon = history.icon {
                foundIcon = icon
            }

            if let title = history.title {
                foundTitle = title
            }

            if type(of: self).visitedDayOf(history) == type(of: self).numberOfDays(date) {
                return (history, history.icon, history.title)
            }
        }

        return (nil, foundIcon, foundTitle)
    }

    // MARK: - Public

    @nonobjc public static let calendar = { () -> Calendar in
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        return calendar
    }()

    public static func numberOfDays(_ date: Date) -> Int {
        return (calendar as NSCalendar).components(.day, from: Date(timeIntervalSince1970: 0), to: date, options: NSCalendar.Options()).day!
    }

    public static func visitedDayOf(_ historyUrl: HistoryUrl) -> Int {
        if let lastVisited = historyUrl.lastVisited {
            return numberOfDays(lastVisited)
        } else {
            return 0
        }
    }

    public func createdOrUpdatedHistory(for url: URL, withIconPrefetch iconPrefetch: Bool) -> HistoryUrl? {
        assert(Thread.isMainThread)

        let date = type(of: self).normalize(date: Date())

        let result = currentHistory(for: url, andDate: date, withIconPrefetch: iconPrefetch)

        let history: HistoryUrl?
        if let uwHistory = result.history {
            history = uwHistory
            // Do not udpate visitCounter here, it is called too often
        } else {
            history = coreData.createObject()
            history?.url = url.absoluteString
            history?.visitCounter = 0
            history?.hidden = ProtocolHandlerChromeExt.isBundleResource(url)
            history?.icon = result.icon
            history?.title = result.title
        }
        history?.lastVisited = date
        return history
    }

    @objc
    public func createOrUpdateHistory(for url: URL, andTitle title: String?, updateVisitCounter: Bool = false) {
        let historyEntry = createdOrUpdatedHistory(for: url, withIconPrefetch: false)
        historyEntry?.title = title
        if updateVisitCounter {
            historyEntry?.visitCounter += 1
        }
        coreData.saveContextWithErrorAlert()
    }

    @objc // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func attach(_ iconData: Data, fromIconURL iconUrl: NSURL, withSize size: Int16, toURLs urls: [URL]) -> UrlIcon? {
        assert(Thread.isMainThread)

        let iconUrlPredicate = NSPredicate(format: "%K == %@ && %K == %d", "iconUrl", iconUrl.absoluteString!, "size", size)
        guard let icons: [UrlIcon] = coreData.fetch(iconUrlPredicate) else {
            // Something very bad has happend
            assert(false)
            return nil
        }

        let historyRequest = createFetchRequestForHistoryEntries(with: urls)
        guard let result1 = coreData.resultsOfFetchWithErrorAlert(historyRequest as? NSFetchRequest<NSFetchRequestResult>) else {
            assert(false)
            return nil
        }

        guard let historyEntries = result1 as? [HistoryUrl] else {
            // Nothing to do
            assert(false)
            return nil
        }

        let bookmarksRequest = createFetchRequestForBookmarks(with: urls)
        guard let result2 = coreData.resultsOfFetchWithErrorAlert(bookmarksRequest as? NSFetchRequest<NSFetchRequestResult>) else {
            assert(false)
            return nil
        }

        guard let bookmarks = result2 as? [Bookmark] else {
            // Nothing to do
            assert(false)
            return nil
        }

        guard historyEntries.count != 0 || bookmarks.count != 0 else {
            // It might happen
            return nil
        }

        let icon: UrlIcon
        if let uwIcon = icons.first {
            icon = uwIcon
            assert(icon.iconUrl == iconUrl.absoluteString && (icon.size?.int16Value ?? 0) == size)
        } else {
            guard let uwIcon: UrlIcon = coreData.createObject() else {
                // Nothing to do
                return nil
            }
            icon = uwIcon
        }

        icon.iconData = iconData
        icon.iconUrl = iconUrl.absoluteString
        icon.size = NSNumber(value: size)
        icon.lastUpdated = Date()

        var iconsToRemove = [UrlIcon]()

        for historyEntry in historyEntries where historyEntry.icon != icon {
                let oldIcon = historyEntry.icon
                historyEntry.icon = icon
                // Icon is empty and should be removed
                if let oldIcon = oldIcon, oldIcon.standalone {
                    iconsToRemove.append(oldIcon)
                }
        }

        for bookmark in bookmarks where bookmark.icon != icon {
                let oldIcon = bookmark.icon
                bookmark.icon = icon
                // Icon is empty and should be removed
                if let oldIcon = oldIcon, oldIcon.standalone {
                    iconsToRemove.append(oldIcon)
                }
        }

        for icon in icons where icon.standalone {
            iconsToRemove.append(icon)
        }

        coreData.deleteManagedObjects(iconsToRemove, saveContext: true)
        return icon
    }

    public func faviconFor(urls: [URL]) -> UrlIcon? {
        assert(Thread.isMainThread)

        let urls = urls.filter { !$0.shouldBeHidden() }

        guard urls.count > 0 else {
            return nil
        }

        let historyRequest = createFetchRequestForHistoryEntries(with: urls)
        let result1 = coreData.resultsOfFetchWithErrorAlert(historyRequest)

        guard let historyEntries = result1 else {
            // Nothing to do
            assert(false)
            return nil
        }

        let bookmarksRequest = createFetchRequestForBookmarks(with: urls)
        let result2 = coreData.resultsOfFetchWithErrorAlert(bookmarksRequest)

        guard let bookmarks = result2 else {
            // Nothing to do
            assert(false)
            return nil
        }

        var outputIcon: UrlIcon? = nil
        var outputSize = Int16.max

        for icon in historyEntries.compactMap({ $0.icon }) + bookmarks.compactMap({ $0.icon }) {
            if let iconSize = icon.size?.int16Value, outputSize > iconSize {
                outputIcon = icon
                outputSize = iconSize
            }
        }

        return outputIcon
    }

    public func onDeletedTabId(_ tabId: UInt) {
        let tabPredicate = predicate(for: tabId)
        let listToDelete: NSFetchRequest<TabHistoryItem> = coreData.fetchRequest(with: tabPredicate)
        coreData.deleteObjectsResulting(fromFetch: listToDelete)
    }

    // MARK: - fileprivate

    fileprivate func predicate(for tabId: UInt) -> NSPredicate {
        return NSPredicate(format: "%K == \(tabId)", "tabId")
    }

    fileprivate func createFetchRequest(for url: URL) -> NSFetchRequest<HistoryUrl>? {
        let urlPredicate = NSPredicate(format: "%K == %@", "url", url.absoluteString)
        let urlExists: NSFetchRequest<HistoryUrl> = coreData.fetchRequest(with: urlPredicate)
        urlExists.sortDescriptors = [NSSortDescriptor(key: "lastVisited", ascending: false)]
        return urlExists
    }

    fileprivate func createFetchRequestForHistoryEntries(with urls: [URL]) -> NSFetchRequest<HistoryUrl> {
        let urlPredicate = NSPredicate(format: "%K IN %@", "url", urls.flatMap { $0.absoluteString })
        let urlExists: NSFetchRequest<HistoryUrl> = coreData.fetchRequest(with: urlPredicate)
        urlExists.sortDescriptors = [NSSortDescriptor(key: "lastVisited", ascending: false)]
        return urlExists
    }

    fileprivate func createFetchRequestForBookmarks(with urls: [URL]) -> NSFetchRequest<Bookmark> {
        let urlPredicate = NSPredicate(format: "%K IN %@", "url", urls.flatMap { $0.absoluteString })
        let urlExists: NSFetchRequest<Bookmark> = coreData.fetchRequest(with: urlPredicate)
        return urlExists
    }

    // We want date to be timezone invariant
    static func normalize(date: Date) -> Date {
        let components = (Calendar.current as NSCalendar).components([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        return calendar.date(from: components) ?? date
    }
}

extension UrlIcon {
    public var standalone: Bool {
        return (url?.count ?? 0) == 0 && (bookmark?.count ?? 0) == 0
    }
}

// MARK: - BrowserHistoryDelegate

extension BrowserHistoryManager: BrowserHistoryDelegate {
    @objc
    public func onTabId(_ tabId: UInt, didStartLoading url: URL?) {
        guard let url = url else {
            Log.error("BrowserHistory didStartLoadingURL nil")
            return
        }

        let historyEntry = createdOrUpdatedHistory(for: url, withIconPrefetch: false)
        historyEntry?.visitCounter += 1

        var maxOrder = Int16(0)
        var indexOfCurrent: Int?
        var indexOfURLMatch: Int?

        let tabHistoryItems = orderedHistoryItemsOnTab(tabId, withURLPrefetch: true)

        if let tabHistoryItems = tabHistoryItems, tabHistoryItems.count > 0 {
            for (index, item) in tabHistoryItems.enumerated() {
                maxOrder = max(maxOrder, item.order)

                if item.isCurrent {
                    indexOfCurrent = index
                }

                if let currentHistoryEntry = item.url, currentHistoryEntry.isEqual(historyEntry) {
                    indexOfURLMatch = index
                }
            }
        }

        if indexOfURLMatch != indexOfCurrent || indexOfURLMatch == nil {
            /*
             The URL to switch to is not the current one (equality would mean navigating existing history
             without change because current flag was already moved by goBack/Forward)
             or there is no previous history at all:
             -> must create a new TabHistoryItem
             */
            if let indexOfCurrent = indexOfCurrent {
                // clear the current flag
                tabHistoryItems?[indexOfCurrent].isCurrent = false
            }

            if let newItem: TabHistoryItem = coreData.createObject() {
                newItem.tabId = Int16(tabId)
                newItem.url = historyEntry
                newItem.isCurrent = true
                newItem.order = maxOrder + 1 // order starts with 1
            }
        }
        coreData.saveContextWithErrorAlert()
    }

    @objc
    public func onTabId(_ tabId: UInt, cancelledLoading url: URL?) {
        // This is happening on every redirection since ProtocolHandler redirection code was changed
        // (i.e. aligned to Apple's reference implementation), so Debug level is deserved
        Log.debug("History cancelled tab \(tabId) URL \(url?.absoluteString ?? "unknown")")

        guard let url = url else {
            return
        }

        let date = type(of: self).normalize(date: Date())

        let result = currentHistory(for: url, andDate: date, withIconPrefetch: false)

        // remember for potential delete after per-tab history
        guard let history = result.history else {
            // If global history doesn't know about this URL at this time, nothing to do
            return
        }

        // Remove from per-tab history first to maintain integrity with HistoryURL
        // It still may be a temporary failure.
        let tabHistoryItems = orderedHistoryItemsOnTab(tabId, withURLPrefetch: true)

        if let tabHistoryItems = tabHistoryItems, tabHistoryItems.count > 0 {
            for (index, item) in tabHistoryItems.enumerated() {
                if let currentHistory = item.url, currentHistory.isEqual(history) {

                    if item.isCurrent {
                        if index + 1 < tabHistoryItems.count {
                            tabHistoryItems[index + 1].isCurrent = true
                        } else if index - 1 >= 0 {
                            tabHistoryItems[index - 1].isCurrent = true
                        }
                    }

                    coreData.deleteManagedObjects([item])
                    break
                }
            }
        }

        if history.visitCounter == 1 {
            // this was the first visit, can be removed from HistoryURL too
            // because there was no previous success
            coreData.deleteManagedObjects([history])
        }
    }

    public func onTabId(_ tabId: UInt, didReplaceCurrentWith url: URL?) {
        guard let url = url else {
            Log.error("BrowserHistory didReplaceCurrentWithURL nil")
            return
        }

        let historyEntry = createdOrUpdatedHistory(for: url, withIconPrefetch: false)

        if let tabHistoryItems = orderedHistoryItemsOnTab(tabId, withURLPrefetch: true) {
            for item in tabHistoryItems where item.isCurrent {
                    if item.url != historyEntry {
                        item.url = historyEntry
                    }
                    break
            }
        }

        coreData.saveContextWithErrorAlert()
    }

    @objc
    public func onTabId(_ tabId: UInt, didFinishLoadingURL url: URL?, withTitle title: String?) {
        let predicate = NSPredicate(format: "%K == %@", "url", url?.absoluteString ?? "")
        if let historyEntries: [HistoryUrl] = coreData.fetch(predicate), historyEntries.count > 0 {
            for historyEntry in historyEntries where historyEntry.title != title {
                historyEntry.title = title
            }
            coreData.saveContextWithErrorAlert()
        } else {
            /**
             For internal requests going through special protocol handlers, didStartLoadingURL is not
             called because those handlers do not detect the originating webview - didn't need to know
             it so far. Getting it extended comprehensibly turned out to be a major effort. This will have
             to be fixed once somebody will object that chrome-extension pages do not appear in browser
             history (which it does in Chrome).
             */
            let isInternalProtocol = ProtocolHandlerJSBridge.isBridgeRequest(url) || ProtocolHandlerChromeExt.isBundleResource(url)
            if !isInternalProtocol {
                Log.error("BrowserHistory didFinishLoading expected to have URL \(url?.absoluteString ?? "")")
            }
        }
    }

    public func onTabIdDidGoBack(_ tabId: UInt) {
        guard let items = orderedHistoryItemsOnTab(tabId, withURLPrefetch: false),
            let indexCurrent = indexOfCurrentInHistory(items), indexCurrent > 0 else {
                return
        }
        items[indexCurrent].isCurrent = false
        items[indexCurrent - 1].isCurrent = true
        coreData.saveContextWithErrorAlert()
    }

    public func onTabIdDidGoForward(_ tabId: UInt) {
        guard let items = orderedHistoryItemsOnTab(tabId, withURLPrefetch: false),
            let indexCurrent = indexOfCurrentInHistory(items), indexCurrent + 1 < items.count else {
                return
        }
        items[indexCurrent].isCurrent = false
        items[indexCurrent + 1].isCurrent = true
        coreData.saveContextWithErrorAlert()
    }

    fileprivate func orderedHistoryItemsOnTab(_ tabId: UInt, withURLPrefetch doPrefetch: Bool) -> [TabHistoryItem]? {
        let tabPredicate = predicate(for: tabId)
        let request: NSFetchRequest<TabHistoryItem> = coreData.fetchRequest(with: tabPredicate)
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        if doPrefetch {
            request.relationshipKeyPathsForPrefetching = ["url"]
        }
        return coreData.resultsOfFetchWithErrorAlert(request)
    }

    fileprivate func indexOfCurrentInHistory(_ tabHistoryItems: [TabHistoryItem]) -> Int? {
        return tabHistoryItems.index { $0.isCurrent }
    }
}

extension BrowserHistoryManager {
    // MARK: - Delete user's actions

    public func deleteSuggestionsOlderThan(_ interval: TimeInterval) {
        let intervalEnd = Date().timeIntervalSince1970 - interval
        let dateEnd = Date(timeIntervalSince1970: intervalEnd)
        let predicate = NSPredicate(format: "%K < %@", omniboxAttributeStamp, dateEnd as CVarArg)
        let listToDelete: NSFetchRequest<OmniboxQuery> = coreData.fetchRequest(with: predicate)
        coreData.deleteObjectsResulting(fromFetch: listToDelete)
    }

    /// A preparation for future settings feature "delete browsing history"
    /// For now hardcoded call from displaying history tab. I.e. whenever history tab
    /// is displayed, the history is cleaned.
    /// - Parameter interval seconds back from now to delete from history
    public func deleteBrowsingHistoryOlderThan(_ interval: TimeInterval) {
        let now = type(of: self).normalize(date: Date())
        let intervalEnd = now.timeIntervalSince1970 - interval
        let dateEnd = Date(timeIntervalSince1970: intervalEnd)
        let predicate = NSPredicate(format: "%K < %@", "lastVisited", dateEnd as CVarArg)
        let listToDelete: NSFetchRequest<HistoryUrl> = coreData.fetchRequest(with: predicate)
        coreData.deleteObjectsResulting(fromFetch: listToDelete)
    }
}

extension BrowserHistoryManager {
    // MARK: - Omnibox suggestions API

    /// Omnibox history API
    /// Query results for given phrase
    public func omniboxHistoryFindPhrase(containing text: String, limit: Int) -> [OmniboxQuery]? {
        let predicate = NSPredicate(format: "%K contains[dc] %@", omniboxAttributePhrase, text)
        return omniboxHistoryFindPhrase(predicate, limit: limit)
    }

    public func omniboxHistoryFindPhrase(withPrefix prefix: String, limit: Int) -> [OmniboxQuery]? {
        let predicate = NSPredicate(format: "%K like[dc] %@", omniboxAttributePhrase, prefix + "*")
        return omniboxHistoryFindPhrase(predicate, limit: limit)
    }

    fileprivate func omniboxHistoryFindPhrase(_ predicate: NSPredicate, limit: Int) -> [OmniboxQuery]? {
        let phraseMatches: NSFetchRequest<OmniboxQuery> = coreData.fetchRequest(with: predicate)
        phraseMatches.fetchLimit = limit
        phraseMatches.sortDescriptors = [NSSortDescriptor(key: omniboxAttributeRank, ascending: false)]
        return coreData.resultsOfFetchWithErrorAlert(phraseMatches)
    }

    /// Phrase was selected, update statistics
    public func omniboxHistoryUpdatePhrase(_ phrase: String) {
        let predicate = NSPredicate(format: "%K == %@", omniboxAttributePhrase, phrase)
        let phraseExists: NSFetchRequest<OmniboxQuery>  = coreData.fetchRequest(with: predicate)
        let results = coreData.resultsOfFetchWithErrorAlert(phraseExists)
        let entry: OmniboxQuery?
        if let uwEntry = results?.first {
            // update
            uwEntry.rank += 1
            entry = uwEntry
        } else {
            // create
            entry = coreData.createObject()
            entry?.phrase = phrase
            entry?.rank = 0
        }
        entry?.timestamp = Date()
        coreData.saveContextWithErrorAlert()
    }
}

private let omniboxAttributePhrase = "phrase"
private let omniboxAttributeRank = "rank"
private let omniboxAttributeStamp = "timestamp"

extension BrowserHistoryManager {
    // MARK: - Suggestions

    public func historySuggestions(for query: String) -> [(host: String, counter: Int64)] {
        let schemes = ["http", "https"]

        var predicate: NSPredicate?

        for scheme in schemes {
            if query.hasPrefix(scheme + ":") {
                predicate = NSPredicate(format: "%K LIKE %@", "url", query + "*")
                break
            }
        }

        let finalPredicate: NSPredicate

        if let predicate = predicate {
            finalPredicate = predicate
        } else {
            let predicates = schemes.map { scheme in
                return NSPredicate(format: "%K LIKE %@", "url", "\(scheme)://\(query)*")
            }
            finalPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }

        let visitCounterExpression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "visitCounter")])

        let visitCounterDescription = NSExpressionDescription()
        visitCounterDescription.name = "counter"
        visitCounterDescription.expression = visitCounterExpression
        visitCounterDescription.expressionResultType = .integer64AttributeType

        let request = NSFetchRequest<NSFetchRequestResult> (entityName: NSStringFromClass(HistoryUrl.self))
        request.predicate = finalPredicate
        request.resultType = .dictionaryResultType
        request.propertiesToGroupBy = ["url"]
        request.propertiesToFetch = [visitCounterDescription, "url"]

        let results = coreData.resultsOfFetchWithErrorAlert(request) ?? []

        return results.compactMap {
            let dictionary = $0 as? [AnyHashable: Any]

            guard let url = dictionary?["url"] as? String, let host = URL(string: url)?.host else {
                return nil
            }

            guard let counter = (dictionary?["counter"] as? NSNumber)?.int64Value else {
                return nil
            }

            return (host, counter)
        }
    }
    // swiftlint:disable:next file_length
}
