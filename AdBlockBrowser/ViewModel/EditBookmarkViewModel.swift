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

final class EditBookmarkViewModel: ViewModelProtocol {
    let components: ControllerComponents
    let bookmark: BookmarkExtras
    let isGhostModeEnabled: Variable<Bool>
    let viewWillBeDismissed: PublishSubject<Void>

    init(components: ControllerComponents,
         bookmark: BookmarkExtras,
         isGhostModeEnabled: Variable<Bool>,
         viewWillBeDismissed: PublishSubject<Void>) {
        self.components = components
        self.bookmark = bookmark
        self.isGhostModeEnabled = isGhostModeEnabled
        self.viewWillBeDismissed = viewWillBeDismissed
    }

    // MARK: -

    func deleteBookmark() {
        components.browserStateData.deleteManagedObjects([bookmark])
    }

    func updateBookmark(with title: String?,
                        url: String?,
                        showInDashboard: Bool) {
        // Remove unwanted whitespace characters
        let title = title?
            .replacingOccurrences(of: "\\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if bookmark.title != title {
            bookmark.title = title
        }

        if bookmark.url != url {
            bookmark.url = url

            let icon = bookmark.icon

            // Clear icon
            bookmark.icon = nil

            // Remove icon, which is no longer referenced
            if let icon = icon, icon.standalone {
                bookmark.managedObjectContext?.delete(icon)
            }
        }

        if showInDashboard && !bookmark.abp_showInDashboard {
            bookmark.abp_dashboardOrder = hintDashboardOrder()
        }

        bookmark.abp_showInDashboard = showInDashboard
        components.browserStateData.saveContextWithErrorAlert()
    }
}
