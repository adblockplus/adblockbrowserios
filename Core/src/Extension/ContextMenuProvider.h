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
#import "ContextMenuItem.h"

@protocol NativeActionCommandDelegate;

@interface CurrentContextURLs : NSObject
@property (nonatomic, copy) NSURL *page;
@property (nonatomic, copy) NSURL *link;
@property (nonatomic, copy) NSURL *image;
@property (nonatomic, copy) NSString *label;
@end

@protocol ContextMenuDataSource
- (NSArray *)getActivityActionsForURLs:(CurrentContextURLs *)urls;

- (void)activityTypeClicked:(NSString *)type
                withPageURL:(NSURL *)pageURL;

- (void)addActionsForURLs:(CurrentContextURLs *)urls
              toContainer:(UIActionSheet *)container
                inContext:(MenuContextType)contextType;
- (BOOL)isButtonIndex:(NSInteger)actionIndex registeredForContext:(MenuContextType)contextType;

- (void)actionIndexClicked:(NSInteger)actionIndex
             withSelection:(NSString *)selectedText
                  withURLs:(CurrentContextURLs *)urls;

- (void)setEditingWebView:(UIWebView *)webView;
- (BOOL)acceptsEditingMenuSelector:(SEL)aSelector
                          withURLs:(CurrentContextURLs *)urls;
@end

@class BrowserExtension;
@protocol ContextMenuDelegate
- (void)onContextMenuCreateId:(NSString *)createMenuId
               withProperties:(NSDictionary *)properties
                fromExtension:(BrowserExtension *)extension;
- (void)onContextMenuUpdateId:(NSString *)updateMenuId
               withProperties:(NSDictionary *)properties;
- (void)onContextMenuRemoveId:(NSString *)removeMenuId;
- (void)onContextMenuRemoveAllForExtension:(BrowserExtension *)extension;
@end

@interface ContextMenuProvider : NSObject <ContextMenuDelegate, ContextMenuDataSource>

- (id)initWithCommandDelegate:(id<NativeActionCommandDelegate>)commandDelegate;

@end
