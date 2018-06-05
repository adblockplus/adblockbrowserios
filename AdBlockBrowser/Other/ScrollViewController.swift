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

class ScrollViewController: NSObject, UIScrollViewDelegate {
    weak var delegate: BrowserViewController?
    var currentProgress = CGFloat(0)
    var scrollsToTop = true

    // MARK: - UIScrollViewDelegate

    fileprivate var _userDragged = false
    fileprivate var _dragging = false
    fileprivate var _scrollingToTop = false
    fileprivate var _draggingOffsetCorrection: CGFloat = 0
    fileprivate var _draggingOffset: CGPoint = CGPoint.zero
    fileprivate var _draggingTargetMode: CGFloat = 0
    let topBarHeight: CGFloat = 44
    let bottomBarHeight: CGFloat = 44

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (_dragging && _userDragged) || _scrollingToTop {
            let offset = scrollView.contentOffset.y
            var diff = -(_draggingOffset.y - _draggingOffsetCorrection) + offset
            // Hidden progress
            let progress = Swift.max(0.0, Swift.min(1.0, diff / topBarHeight))

            diff = delegate?.updateSizes(progress) ?? 0

            currentProgress = progress

            var offsetPoint = scrollView.contentOffset
            offsetPoint.y += diff

            // Only enabled in closed state
            if progress >= 0.5 {
                // We disable content bounding
                offsetPoint.y = Swift.max(offsetPoint.y, -scrollView.contentInset.top)
            }

            if diff != 0 && !_scrollingToTop {
                _userDragged = false
                scrollView.contentOffset = offsetPoint
                _userDragged = true
            }

            _draggingOffset.y += diff
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if !_dragging {
            // Viewport is incorrect on iPhone 4S after startup. I did not managed to
            // find out what was causing that but scrollview insets were set to strange values.
            // This call is fixing insets if theirs values are incorrect.
            initializeScrollViewInsets(scrollView)

            // Very simple solution to allow show toolbars in any cases.
            if currentProgress < 0.5 {
                // Protection from Javascript scrollers. If scoller is detected then hiding of bars is disabled.
                if scrollView.contentSize.height <= scrollView.frame.size.height + scrollView.contentInset.top + scrollView.contentInset.bottom {
                    return
                }
            }

            // YES only if scroll started from
            _dragging = true
            // starting content offset
            _draggingOffset = scrollView.contentOffset
            // used when user is trying to leave fullscreen
            _draggingOffsetCorrection = 0

            // [Hack] This code fixes bug when this function returns invalid content offset.
            // This happens when user is quickly and repeatedly swiping down on very top of the page.
            _draggingOffset.y = Swift.max(_draggingOffset.y, -scrollView.contentInset.top)

            // [HACK] Same fix as above except it handles bottom of the content.
            _draggingOffset.y = Swift.min(_draggingOffset.y,
                                          scrollView.contentSize.height - scrollView.frame.size.height + scrollView.contentInset.bottom)

            // We used this flag to distinguish between user and program triggered events (it was causing stack overflows).
            _userDragged = true

            // This handles offsets of different modes
            _draggingOffsetCorrection = currentProgress * topBarHeight
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset pointer: UnsafeMutablePointer<CGPoint>) {
        if !_dragging {
            return
        }

        let mutablePointer = pointer
        var targetContentOffset = mutablePointer.pointee
        var diff = -(_draggingOffset.y - _draggingOffsetCorrection) + targetContentOffset.y
        let height = topBarHeight

        if diff >= 0 && diff <= height {
            if diff > height / 2 {
                diff = height
            } else {
                diff = 0
            }

            targetContentOffset.y = diff + (_draggingOffset.y - _draggingOffsetCorrection)
        }

        // Usually, very quick scroll does not trigger all events. This will help set bar to right style.
        if diff <= 0 {
            _draggingTargetMode = 0
            //_draggingTargetMode = SANavigationBarModeClosed;
        }
        if diff >= height {
            _draggingTargetMode = 1.0//-topBarHeight
            //_draggingTargetMode = SANavigationBarModeFullscreen;
        }
        mutablePointer.initialize(to: targetContentOffset)
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if _dragging {
            _dragging = false

            let diff = delegate?.updateSizes(_draggingTargetMode) ?? 0

            currentProgress = _draggingTargetMode

            var offsetPoint = scrollView.contentOffset
            offsetPoint.y += diff
            scrollView.contentOffset = offsetPoint
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if _dragging && !decelerate {
            _dragging = false

            let diff = delegate?.updateSizes(_draggingTargetMode) ?? 0

            currentProgress = _draggingTargetMode

            var offsetPoint = scrollView.contentOffset
            offsetPoint.y += diff
            scrollView.contentOffset = offsetPoint
        }
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        _scrollingToTop = false
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if (delegate?.shouldScrollToTop(self) ?? false) && scrollsToTop {
            _draggingOffset = scrollView.contentOffset
            _draggingOffsetCorrection = currentProgress * topBarHeight
            _scrollingToTop = true
            return true
        }
        return false
    }

    // MARK: - API

    func initializeScrollViewInsets(_ scrollView: UIScrollView) {
        var defaultInsets = UIEdgeInsets.zero
        defaultInsets.top = topBarHeight
        defaultInsets.bottom = bottomBarHeight + topBarHeight

        scrollView.contentInset = defaultInsets
        scrollView.scrollIndicatorInsets = defaultInsets
    }
}
