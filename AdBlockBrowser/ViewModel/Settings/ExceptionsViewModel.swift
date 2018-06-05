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

final class ExceptionsViewModel: ViewModelProtocol {
    enum WhitelistedSitesChanges {
        case reload
        case removeItemAt(Int)
    }

    let components: ControllerComponents
    let extensionFacade: ABPExtensionFacadeProtocol
    let isAcceptableAdsEnabled: Variable<Bool>
    let whitelistedSitesChanges: Observable<WhitelistedSitesChanges>

    private var subject = PublishSubject<WhitelistedSitesChanges>()
    private(set) var whitelistedSites = [(site: String, isWhitelisted: Bool)]?.none

    init(components: ControllerComponents, isAcceptableAdsEnabled: Variable<Bool>) {
        self.components = components
        self.extensionFacade = components.extensionFacade
        self.isAcceptableAdsEnabled = isAcceptableAdsEnabled
        self.whitelistedSitesChanges = self.subject.startWith(.reload)

        extensionFacade.getWhitelistedSites { [weak self] sites, _ in
            if let sites = sites {
                self?.merge(whitelistedSites: sites)
            } else {
                self?.merge(whitelistedSites: [])
            }
        }
    }

    func site(_ site: String, isWhitelisted: Bool) {
        extensionFacade.whitelistDomain(site, whitelisted: isWhitelisted, completion: nil)
    }

    func removeSite(at index: Int) {
        guard let item = whitelistedSites?[index] else {
            return
        }

        if item.isWhitelisted {
            extensionFacade.whitelistDomain(item.site, whitelisted: false, completion: nil)
        }

        whitelistedSites?.remove(at: index)
        subject.onNext(.removeItemAt(index))
        writeWhitelistedSitesToFile()
    }

    // MARK: - Private

    private func merge(whitelistedSites sites: [String]) {
        let storedSites: [String]

        do {
            if let storage = whitelistedSitesStorageUrl() {
                let data = try Data(contentsOf: storage)
                let list = try PropertyListSerialization.propertyList(from: data,
                                                                      options: PropertyListSerialization.ReadOptions(),
                                                                      format: nil)

                storedSites = list as? [String] ?? []
            } else {
                storedSites = []
            }
        } catch _ {
            storedSites = []
        }

        let sortedSites = sites.sorted(by: <)
        let sortedStoredSites = storedSites.sorted(by: <)

        let result = mergeSequences(sortedSites, sortedStoredSites) { item, result in (item, result != .right) }

        whitelistedSites = result
        subject.onNext(.reload)
        writeWhitelistedSitesToFile()
    }

    private func whitelistedSitesStorageUrl() -> URL? {
        if let document = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            return document.appendingPathComponent("whitelisted.plist", isDirectory: false)
        } else {
            return nil
        }
    }

    private func writeWhitelistedSitesToFile() {
        do {
            if let storage = whitelistedSitesStorageUrl() {
                let allSites = (whitelistedSites ?? []).map { $0.0 }
                let data = try? PropertyListSerialization.data(fromPropertyList: allSites, format: .binary, options: 0)
                try data?.write(to: storage, options: Data.WritingOptions())
            }
        } catch _ {
        }
    }
}

enum MergeSequenceComparisonResult {
    case left
    case right
    case both
}

func mergeSequences<Sequence1, Sequence2, Element, U>(_ sequence1: Sequence1,
                                                      _ sequence2: Sequence2,
                                                      combine: (Element, MergeSequenceComparisonResult) -> U) -> [U]
    where Sequence1: Sequence, Sequence2: Sequence,
    Sequence1.Iterator.Element == Element,
    Sequence2.Iterator.Element == Element,
    Element: Comparable {
    var result = [U]()

    var iterator1 = sequence1.makeIterator()
    var iterator2 = sequence2.makeIterator()

    var item1 = iterator1.next()
    var item2 = iterator2.next()

    while let uwItem1 = item1, let uwItem2 = item2 {
        if uwItem1 < uwItem2 {
            result.append(combine(uwItem1, .left))
            item1 = iterator1.next()
        } else if uwItem1 > uwItem2 {
            result.append(combine(uwItem2, .right))
            item2 = iterator2.next()
        } else {
            result.append(combine(uwItem1, .both))
            item1 = iterator1.next()
            item2 = iterator2.next()
        }
    }

    while let uwItem1 = item1 {
        result.append(combine(uwItem1, .left))
        item1 = iterator2.next()
    }

    while let uwItem2 = item2 {
        result.append(combine(uwItem2, .right))
        item2 = iterator2.next()
    }

    return result
}
