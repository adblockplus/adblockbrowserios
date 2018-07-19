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

#import <Foundation/Foundation.h>

/**
 Listens to UI notifications related to fulltext operation.
 UI events are sent only through notifications, no direct delegate calls.

 Constructs appropriate messages for the JS bridge callbacks.
 Interprets the JS execution results and produces relevant notifications.
*/

/// autocomplete view sending valid search query
extern NSString *const kFulltextSearchPhraseNotification;
/// autocomplete view clicked Previous
extern NSString *const kFulltextSearchPreviousNotification;
/// autocomplete view clicked Next
extern NSString *const kFulltextSearchNextNotification;
/// informing autocomplete view about results from JS call
extern NSString *const kFulltextSearchResultNotification;
/// autocomplete view wants to clear search matches
extern NSString *const kFulltextSearchClearNotification;
/// autocomplete view wants to clear search matches
extern NSString *const kFulltextSearchDismissNotification;

@protocol NativeActionCommandDelegate;

@interface FulltextSearchObserver : NSObject

- (id)initWithCommandDelegate:(id<NativeActionCommandDelegate>)delegate andChromeWindow:(id)window;

/**
 @param searchToolBarBottomHeight
 extra space at the webview bottom end occupied by the fulltext search toolbar.
 Default value is 0, so does not need to be called if there is no such toolbar in the design.
 Keyboard showing if observed separately, it makes no difference if such toolbar is displayed
 on top of it. On the other hand, if the toolbar disappears under some UI conditions, this value
 must be set to zero accordingly.
 */
@property (nonatomic) CGFloat searchToolBarBottomHeight;
/**
 @param matchFocusScrollViewInsets
 The padding on sides of the webview, into which the focused match is scrolled. The greater the
 value is, the more centered the match is.
 Default value is 0 which means that the match may be at the very edge of the browser window, or
 even beyond it in case of some dirty CSS tricks on the webpage.
*/
@property (nonatomic) UIEdgeInsets matchFocusScrollViewInsets;

@end
