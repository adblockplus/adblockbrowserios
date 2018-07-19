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

#import "FulltextSearchObserver.h"
#import "SAContentWebView.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

NSString *const kFulltextSearchPhraseNotification = @"FulltextSearchPhraseNotification";
NSString *const kFulltextSearchPreviousNotification = @"FulltextSearchPreviousNotification";
NSString *const kFulltextSearchNextNotification = @"FulltextSearchNextNotification";
NSString *const kFulltextSearchResultNotification = @"FulltextSearchResultNotification";
NSString *const kFulltextSearchClearNotification = @"FulltextSearchClearNotification";
NSString *const kFulltextSearchDismissNotification = @"FulltextSearchDismissNotification";

@implementation FulltextSearchObserver {
    id<NativeActionCommandDelegate> _delegate;
    ChromeTab *_currentTab;
    NSUInteger _currentIndex;
    NSUInteger _totalMatches;
    CGFloat _keyboardHeight;
    ChromeWindow *_window;
    CGPoint _lastKnownViewport;
}

- (id)initWithCommandDelegate:(id<NativeActionCommandDelegate>)delegate andChromeWindow:(id)window
{
    if (self = [super init]) {
        _delegate = delegate;
        _window = window;
        _searchToolBarBottomHeight = 0.0;
        _matchFocusScrollViewInsets = UIEdgeInsetsMake(0, 0, 0, 0);
        [_window addObserver:self
                  forKeyPath:@"activeTab"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:nil];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(onSearchPhrase:)
                       name:kFulltextSearchPhraseNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(onSelectPrevious:)
                       name:kFulltextSearchPreviousNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(onSelectNext:)
                       name:kFulltextSearchNextNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(onSearchClear:)
                       name:kFulltextSearchClearNotification
                     object:nil];
        // Needed to know the keyboard height, hence the size of visible webview part
        // (where search results are presented)
        [center addObserver:self
                   selector:@selector(onNotificationKeyboardDidShow:)
                       name:UIKeyboardDidShowNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(onNotificationKeyboardDidHide:)
                       name:UIKeyboardDidHideNotification
                     object:nil];
    }
    return self;
}

- (void)setSearchToolBarBottomHeight:(CGFloat)searchToolBarBottomHeight
{
    _searchToolBarBottomHeight = searchToolBarBottomHeight;
    // recalculate the offset of the current selection
    if (_totalMatches > 0) {
        [self selectMatchWithIndex:_currentIndex doneBlock:nil];
    }
}

- (void)setMatchFocusScrollViewInsets:(UIEdgeInsets)matchFocusScrollViewInsets
{
    _matchFocusScrollViewInsets = matchFocusScrollViewInsets;
    // recalculate the offset of the current selection
    if (_totalMatches > 0) {
        [self selectMatchWithIndex:_currentIndex doneBlock:nil];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_window removeObserver:self forKeyPath:@"activeTab" context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"activeTab"]) {
        _currentTab = change[NSKeyValueChangeNewKey];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)onSearchPhrase:(NSNotification *)notification
{
    // Receives search phrase from autocomplete view
    NSDictionary *userInfo = notification.userInfo;
    // Sends the phrase to JS
    // result is array of coordinate tuples (array of x,y)
    [_delegate.eventDispatcher markMatches:_currentTab.identifier
                                    phrase:userInfo[@"phrase"]
                                completion:^(NSError *error, FulltextSearchResults *result) {
                                    // give main thread a chance to update uiwebview DOM changes
                                    self->_currentIndex = 0;
                                    self->_totalMatches = 0;
                                    if (error) {
                                        LogError(@"Fulltext search JS execution failed");
                                    } else if (!(result.locations.count > 0)) {
                                        LogInfo(@"No match");
                                    } else {
                                        if (self->_currentTab.webView) {
                                            CGPoint zoom = [self viewportZoomFromJSViewport:result.viewport inWebView:self->_currentTab.webView];
                                            // make the first focus with zero insets. When it is nonzero, the initial match selection
                                            // may skip some matches at the very beginning of the page (above the focus)
                                            CGRect focusFrame = [self focusFrameInWebView:self->_currentTab.webView withInsets:UIEdgeInsetsZero];
                                            NSArray *locations = result.locations;
                                            self->_totalMatches = [locations count];
                                            // find the closest point
                                            __block CGFloat smallestDistance = CGFLOAT_MAX;
                                            // Iterate tuples to find the one closest to current scrolling offset
                                            [locations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                                // location is already reported by JS with scroll offset
                                                // i.e. 0,0 is window beginning, not document rendering beginning
                                                CGPoint coord = CGPointMake([obj[0] floatValue] * zoom.x, [obj[1] floatValue] * zoom.y);
                                                CGPoint delta = [self requiredScrollDeltaForJSCoord:coord toFocusFrame:focusFrame];
                                                // Compute in float not double.
                                                // Higher precision is needless and potentially greater speed is appreciated
                                                CGFloat distance = sqrtf(delta.x * delta.x + delta.y * delta.y);
                                                if (distance < smallestDistance) {
                                                    smallestDistance = distance;
                                                    self->_currentIndex = idx;
                                                }
                                            }];
                                            [self selectMatchWithIndex:self->_currentIndex
                                                             doneBlock:^(BOOL success) {
                                                                 if (!success) {
                                                                     // keep iterating until valid match is found
                                                                     [self onSelectNext:nil];
                                                                 }
                                                             }];
                                        }
                                    }
                                    [self notifyCurrentIndex];
                                }];
}

- (void)onSelectPrevious:(NSNotification *)notification
{
    if (_totalMatches < 2) {
        return;
    }
    // underflow -> wrap to last match
    NSUInteger prev = (_currentIndex ? _currentIndex : _totalMatches) - 1;
    [self selectMatchWithIndex:prev
                     doneBlock:^(BOOL success) {
                         if (!success) {
                             self->_currentIndex = prev;
                             // keep iterating until valid match is found
                             [self onSelectPrevious:notification];
                         }
                     }];
}

- (void)onSelectNext:(NSNotification *)notification
{
    if (_totalMatches < 2) {
        return;
    }
    // overflow -> wrap to first match
    NSUInteger next = (_currentIndex + 1) % _totalMatches;
    [self selectMatchWithIndex:next
                     doneBlock:^(BOOL success) {
                         if (!success) {
                             self->_currentIndex = next;
                             // keep iterating until valid match is found
                             [self onSelectNext:notification];
                         }
                     }];
}

- (void)onSearchClear:(NSNotification *)notification
{
    _totalMatches = 0;
    [_delegate.eventDispatcher unmarkMatches:_currentTab.identifier];
}

#pragma mark - Private

- (void)selectMatchWithIndex:(NSUInteger)newIndex doneBlock:(void (^)(BOOL))doneBlock
{
    NSDictionary *properties = @{ @"index" : @(newIndex) };
    [_delegate.eventDispatcher makeCurrent:_currentTab.identifier
                                properties:properties
                                completion:^(NSError *error, FulltextSearchResults *result) {
                                    BOOL success = false;
                                    if (error || !result) {
                                        LogInfo(@"Cannot select match %lu, skipping", newIndex + 1); // displayed indexes are from 1 not 0
                                    } else {
                                        self->_currentIndex = newIndex; // reassign only on success
                                        CGPoint zoom = [self viewportZoomFromJSViewport:result.viewport inWebView:self->_currentTab.webView];
                                        CGRect focusFrame = [self focusFrameInWebView:self->_currentTab.webView withInsets:self->_matchFocusScrollViewInsets];
                                        NSArray *locations = result.locations; // array of coords (arrays of 2)
                                        if ([locations count] == 0) {
                                            LogError(@"Fulltext search match did not return any coordinate");
                                        } else {
                                            NSArray<NSNumber *> *location = locations[0];
                                            CGPoint coord = CGPointMake([location[0] floatValue] * zoom.x, [location[1] floatValue] * zoom.y);
                                            CGPoint delta = [self requiredScrollDeltaForJSCoord:coord toFocusFrame:focusFrame];
                                            [self scrollWebViewByDelta:delta];
                                            [self notifyCurrentIndex];
                                            success = true;
                                        }
                                    }
                                    if (doneBlock) {
                                        doneBlock(success);
                                    }
                                }];
}

// Notify autocomplete view about the current match position
- (void)notifyCurrentIndex
{
    NSDictionary *userInfo = @{ @"total" : @(_totalMatches),
                                @"current" : @(_currentIndex) };
    [[NSNotificationCenter defaultCenter] postNotificationName:kFulltextSearchResultNotification
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)onNotificationKeyboardDidShow:(NSNotification *)notification
{
    NSDictionary *properties = [notification userInfo];
    // notification delivers UIScreen coordinates
    CGRect rectKeyboard = [properties[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardHeight = rectKeyboard.size.height;
    // recalculate the offset of the current selection
    if (_totalMatches > 0) {
        [self selectMatchWithIndex:_currentIndex doneBlock:nil];
    }
}

- (void)onNotificationKeyboardDidHide:(NSNotification *)notification
{
    // I wanted to be nice and pull the height from userInfo[UIKeyboardFrameEndUserInfoKey]
    // but it apparently may not be just zero but also full height accompanied by Y coordinate
    // outside of the viewport (in other words, keyboard not dismissed but just moved out of sight).
    // Doing screen computations just to get something which will be most probably zero anyway
    // is an overkill. Feel free to fix if the assumption turns out being incorrect.
    _keyboardHeight = 0.0;
    // recalculate the offset of the current selection
    if (_totalMatches > 0) {
        [self selectMatchWithIndex:_currentIndex doneBlock:nil];
    }
}

- (CGPoint)viewportZoomFromJSViewport:(NSArray *)viewportTuple inWebView:(UIWebView *)webView
{
    UIEdgeInsets scrollViewInsets = webView.scrollView.contentInset;

    // the value reported from JS innerWidth/Height adds with insets to the unzoomed webVisibleFrame size
    CGFloat viewportX = [viewportTuple[0] floatValue] + scrollViewInsets.left + scrollViewInsets.right;
    CGFloat viewportY = [viewportTuple[1] floatValue] + scrollViewInsets.top + scrollViewInsets.bottom;
    if (fabs(viewportX) > 0.1 && fabs(viewportY) > 0.1) {
        _lastKnownViewport = CGPointMake(viewportX, viewportY);
    }
    // web.frame and web.bounds have both height = screen height + 84
    // (so on iPhone5 it's 568+84 = 652. Let's use the web superview for real frame.
    CGRect webVisibleFrame = webView.superview.frame;
    /*
     For responsive websites with "viewport width=device-width", the zoom is always 1
     E.g. on iPhone5, the real website width is also 320.
     For plain nonresponsive websites though, the real website width is generally bigger than that
     and scaled down to fit in the webview frame. The scale value needs to be applied to
     the incoming js coords so that the native scrollview offset aligns correctly.
     */
    return CGPointMake(
                       webVisibleFrame.size.width / _lastKnownViewport.x,
                       webVisibleFrame.size.height / _lastKnownViewport.y);
}

- (CGRect)focusFrameInWebView:(UIWebView *)webView withInsets:(UIEdgeInsets)focusInsets
{
    CGRect webVisibleFrame = webView.superview.frame;
    UIEdgeInsets scrollViewInsets = webView.scrollView.contentInset;

    return CGRectMake(
                      webVisibleFrame.origin.x + scrollViewInsets.top + focusInsets.top,
                      webVisibleFrame.origin.y + scrollViewInsets.left + focusInsets.left,
                      webVisibleFrame.size.height - _keyboardHeight - _searchToolBarBottomHeight - scrollViewInsets.bottom - focusInsets.bottom,
                      webVisibleFrame.size.width - scrollViewInsets.right - focusInsets.right);
}

- (CGPoint)requiredScrollDeltaForJSCoord:(CGPoint)coord toFocusFrame:(CGRect)frame
{
    CGPoint minCoord = CGPointMake(frame.origin.x, frame.origin.y);
    CGPoint maxCoord = CGPointMake(
                                   frame.origin.x + frame.size.width,
                                   frame.origin.y + frame.size.height);
    CGPoint delta = CGPointMake(0.0, 0.0);
    if (minCoord.x > coord.x) {
        delta.x = coord.x - minCoord.x; // to left of visible rect (lesser X), move negative (-X)
    }
    if (maxCoord.x < coord.x) {
        delta.x = coord.x - maxCoord.x; // to right of visible rect (greater X), move positive (+X)
    }
    if (minCoord.y > coord.y) {
        delta.y = coord.y - minCoord.y; // above top of visible rect (lesser Y), move negative (-Y)
    }
    if (maxCoord.y < coord.y) {
        delta.y = coord.y - maxCoord.y; // below bottom of visible rect (greater Y), move positive (+Y)
    }
    return delta;
}

- (void)scrollWebViewByDelta:(CGPoint)delta
{
    CGPoint offset = _currentTab.webView.scrollView.contentOffset;
    offset = CGPointMake(offset.x + delta.x, offset.y + delta.y);
    // The "zero scroll" offset is not zero but negative contentInset
    offset.x = MAX(-_currentTab.webView.scrollView.contentInset.left, offset.x);
    offset.y = MAX(-_currentTab.webView.scrollView.contentInset.top, offset.y);
    [_currentTab.webView.scrollView setContentOffset:offset animated:YES];
}

@end
