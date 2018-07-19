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

/// The types here correspond to enumeration of
/// https://developer.chrome.com/extensions/contextMenus#method-create
/// but are named relevantly to Kitt usage contexts.
typedef enum {
    MenuContext_All,
    MenuContext_WholeWebPage, // "sharing menu"
    MenuContext_TextSelection, // non-url text selection
    MenuContext_LinkLongTap // long tap on URL
} MenuContextType;

@class BrowserExtension;

@interface ContextMenuItem : NSObject
/// constructor
/// @param menuId unique id as assigned by JS code
/// @param originExtension the extension which requested menu item creation
- (id)initWithMenuId:(NSString *)menuId originExtension:(BrowserExtension *)originExtension;

/// Set properties on menu item creation (coming from API command 'create')
/// @param error [out] set if parameters preprocessing failed
- (void)setInitialProperties:(NSDictionary *)properties error:(NSError **)error;

/// Update properties (coming from API command 'update')
/// @param error [out] set if parameters preprocessing failed
- (void)mergeWithProperties:(NSDictionary *)properties error:(NSError **)error;

/// getters for relevant context menu properties. May expand over the time
- (NSArray *)arrayOfRegexesForDocumentURL;
- (NSArray *)arrayOfRegexesForTargetURL;
- (BOOL)isApplicableToContext:(MenuContextType)contextType;
- (BOOL)isEnabled;
- (NSString *)title;

/// getters for values injected via constructor
@property (nonatomic, readonly) NSString *menuId;
@property (nonatomic, readonly) BrowserExtension *originExtension;
/// assigned button index in case this menu item is added to UIActionSheet
@property (nonatomic) NSInteger buttonIndex;
/// the page URL on which this menu item was displayed the last time
/// (chrome API requires this value to be returned in response)
@property (nonatomic, strong) NSURL *lastPageURL;
/// Two property used by UIActivity subclass.
@property (nonatomic, readonly) NSString *activityType;
@property (nonatomic, readonly) UIImage *grayscaleIcon;

@end
