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

/**
 
 Represents the context menu which is displayed when an active content (link) is long-tapped
 in UIWebView. Inherits from NSObject to enable different physical implementation
 (UIAlertController for iOS8+ or something completely different if appearance customization
 is required.
 
 */

#import <UIKit/UIKit.h>

@protocol ContextMenuDataSource;
@class SAContentWebView; 
@class CurrentContextURLs;
@class WebDownloadsManager;

@interface BrowserContextActionSheet : NSObject

// @param dataSource can be nil if no menu items required by extension are expected
-(instancetype)initWithDataSource:(id<ContextMenuDataSource>)dataSource;
// @return true the action sheet can be created from urls and was created
// @return false urls are not applicable or the creation failed
-(BOOL)createForCurrentWebView:(SAContentWebView *)webView
                actionsForURLs:(CurrentContextURLs *)urls;

// Blocks called upon clicking standard (always present) actions
@property(nonatomic, strong) void(^blockCopyLink)(NSURL *);
@property(nonatomic, strong) void(^blockOpenHere)(NSURL *);
// @param the webview which originated the new tab request
// Will be the same as the webView parameter of create*
@property(nonatomic, strong) void(^blockNewTab)(NSURL*, SAContentWebView *);
@property(nonatomic, strong) void(^blockOpenInBackground)(NSURL*, SAContentWebView *);

// Reimplements UIActionSheet methods to minimize changes in the owning code
-(void)showInView:(UIView *)view;
@property(nonatomic, readonly, getter=isVisible) BOOL visible;

// can be nil if link long-tap saving is not required
@property(nonatomic, weak) WebDownloadsManager *downloadsMgr;

@end
