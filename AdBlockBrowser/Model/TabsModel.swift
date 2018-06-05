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
import RxSwift

enum TabsModelChangeEvent {
    case reload
    case update(IndexSet, IndexSet)
}

final class TabsModel: NSObject, Collection {
    private let subject: PublishSubject<TabsModelChangeEvent>
    private var array = [ChromeTab]()
    private let hiddenTabsVariable = Variable(Set<ChromeTab>()) // Removed only from TableView
    let events: Observable<TabsModelChangeEvent>
    let window: ChromeWindow

    private(set) var hiddenTabs: Set<ChromeTab> {
        get {
            return hiddenTabsVariable.value
        }
        set {
            if hiddenTabsVariable.value != newValue {
                hiddenTabsVariable.value = newValue
            }
        }
    }

    var hiddenTabsObservable: Observable<Set<ChromeTab>> {
        return hiddenTabsVariable.asObservable()
    }

    init(window: ChromeWindow) {
        self.subject = PublishSubject()
        self.events = self.subject.startWith(.reload)
        self.window = window
        super.init()
        var chromeWindow: ChromeWindow?
        setObservedProperty(&chromeWindow, window, self, ["tabs"])
    }

    deinit {
        var chromeWindow: ChromeWindow? = window
        setObservedProperty(&chromeWindow, nil, self, ["tabs"])
    }

    // swiftlint:disable:next block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        assert(Thread.isMainThread)

        if keyPath == #keyPath(ChromeWindow.tabs) {

            guard let windowTabs = window.tabs as? [ChromeTab] else {
                return
            }

            let kind: NSKeyValueChange
            if let kindNumber = change?[.kindKey] as? UInt, let kindNumberKey = NSKeyValueChange(rawValue: kindNumber) {
                kind = kindNumberKey
            } else {
                kind = .setting
            }

            switch kind {
            case .insertion, .removal:
                synchronize(with: windowTabs, hiddenTabs: hiddenTabs)
            default:
                let (tabs, newHiddenTabs) = windowTabs.separate { !hiddenTabs.contains($0) }
                array = tabs
                subject.onNext(.reload)
                hiddenTabs = Set(newHiddenTabs)
            }

        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func update(hiddenTabs: Set<ChromeTab>) {
        guard let windowTabs = (window.tabs as? [ChromeTab]) else {
            return
        }

        synchronize(with: windowTabs, hiddenTabs: hiddenTabs)
    }

    // MARK: Collection

    typealias Index = Array<ChromeTab>.Index
    typealias Indices = Array<ChromeTab>.Indices
    typealias Iterator = Array<ChromeTab>.Iterator

    var indices: Indices {
        return array.indices
    }

    var startIndex: Index {
        return array.startIndex
    }

    var endIndex: Index {
        return array.endIndex
    }

    func index(after index: Index) -> Index {
        return array.index(after: index)
    }

    subscript(index: Index) -> ChromeTab {
        return array[index]
    }

    subscript(bounds: Range<Int>) -> ArraySlice<ChromeTab> {
        return array[bounds]
    }

    func makeIterator() -> Iterator {
        return array.makeIterator()
    }

    // MARK: - private

    private func synchronize(with tabs: [ChromeTab], hiddenTabs: Set<ChromeTab>) {
        let oldTabs = self.array
        let (newTabs, newHiddenTabs) = tabs.separate { !hiddenTabs.contains($0) }

        let oldTabsSet = Set<ChromeTab>(oldTabs)
        let newTabsSet = Set<ChromeTab>(newTabs)

        let removedIndices = IndexSet(oldTabs
            .enumerated()
            .filter { !newTabsSet.contains($0.element) }
            .map { $0.offset }
        )
        let insertedIndices = IndexSet(newTabs
            .enumerated()
            .filter { !oldTabsSet.contains($0.element) }
            .map { $0.offset }
        )

        array = newTabs

        if insertedIndices.count > 0 || removedIndices.count > 0 {
            subject.onNext(.update(insertedIndices, removedIndices))
        }

        self.hiddenTabs = Set(newHiddenTabs)
    }
}
