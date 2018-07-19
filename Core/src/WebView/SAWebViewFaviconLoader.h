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
Abstraction of SAWebView-related activity: downloading favicon corresponding
to the recently loaded page. Not as straightforward task as it may sound because
there are multiple sources of favicon URL and any of them might be misconfigured
and/or nonexistent.

Possible scenarios in fallback order.
1. DOM upon DOMContentLoaded. May be misconfigured (i.e. broken).
2. DOM at any time later (via DOM mutation). May be misconfigured (i.e. broken).
   Example:wired.com
3. Fallback if both 1 and 2 do not exist or is broken.
   Query the host unchanged with path "/favicon.ico".
4. Fallback from 3. If host 2nd level domain is not "www", try 3 with "www".
   Example:m.slashdot.org

Possible DOM link forms:
"Standard link" = <link rel="(icon|shortcut icon)">
"Apple link" = <link rel="apple-touch-icon">

Apple link be tried first. Sites were observed having a different favicon for
Apple devices - not .ico but .png in different resolution.
 
@todo
Because the process is quite lengthy in case of misconfigured and/or undefined
DOM links, it was decided that this class will cache the found icons against the
webview request URL at the moment. The cache ideally should be factored out
to a separate class, with a persistent storage. Now it's just a runtime non persistent
performance hack, declared static so that all tabs have access to it
through their favicon loaders.

@todo
There is no reason why this class can't be shared by all existing tabs hence
removing the need for static cache. But the immediate origin was a refactoring
out of existing SAContentWebView, resulting in 1:1 relationship. Making the class
shareable would require implementing favicon request queue, which somewhat
overshoots the anticipated scope of this feature at the moment.
*/

#import <Foundation/Foundation.h>

@class BrowserHistoryManager;
@class FaviconGroup;

@protocol FaviconFacade <NSObject>

@property (nonatomic, readonly, nullable) NSString *iconUrl;
@property (nonatomic, readonly, nullable) NSData *iconData;
@property (nonatomic, readonly, nullable) NSNumber *size;

@end

@protocol FaviconLoadingDelegate <NSObject>

- (NSString *__nonnull)stringFromEvalJS:(NSString *__nonnull)jsString;
- (void)setCurrentFavicon:(nullable id<FaviconFacade>)favicon;

@end

@interface SAWebViewFaviconLoader : NSObject

+ (dispatch_queue_t _Nonnull)loadingQueue;

@property (nonatomic, readonly, nullable) NSURLRequest *currentRequest;

@property (nonatomic, readonly, weak, nullable) id<FaviconLoadingDelegate> delegate;

- (instancetype __nonnull)initWithDelegate:(nullable id<FaviconLoadingDelegate>)delegate
                            historyManager:(BrowserHistoryManager *__nullable)historyManager;

- (void)startFaviconLoadingFromURL:(NSURL *__nonnull)currentFaviconURL
                          withSize:(NSUInteger)size
                   andFaviconGroup:(FaviconGroup *__nonnull)faviconGroup;

- (void)startFaviconLoadingWith:(NSURLRequest *__nonnull)currentRequest;

- (BrowserHistoryManager *__nullable)historyManager;

+ (NSString *__nullable)URLStringFromValidatedFaviconURL:(NSURL *__nonnull)url withCurrentURL:(NSURL *__nonnull)currentURL;

@end
