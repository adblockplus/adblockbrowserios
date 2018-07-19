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

// facade for NSUserDefaults

@interface Settings : NSObject

typedef enum {
    ExtensionServerResource_None,
    ExtensionServerResource_Listing,
    ExtensionServerResource_Logger,
    ExtensionServerResource_Extension
} ExtensionServerResourceType;

/// @returns version as defined in Application Target
+ (NSString *)applicationVersion;
+ (NSString *)applicationBuild;
+ (NSString *)coreVersion;
/// whether this application can handle proposed scheme
/// (expected http/s and kitt)
+ (BOOL)allowsScheme:(NSString *)scheme;
/// specific scheme for native bridge (kitt)
+ (NSString *)bridgeScheme;
/// preset scheme of extension server (http/s)
+ (NSString *)extensionServerScheme;
/// development server URL with optional resource path
+ (NSURL *)devServerURLWithResource:(ExtensionServerResourceType)resourceType;
/// THE extension server URL regardless of dev/production
+ (NSURL *)extensionServerURLForExtensionListing;
/// the default User-Agent string as set by OS
+ (NSString *)defaultWebViewUserAgent;
/// the email to which logged application failures should be sent
+ (NSString *)emailAddressForLoggedAppFailures;

/// given a specific URL, determine whether it's extension installation URL
/// (hence it must not be modified before reaching the webview)
+ (BOOL)isExtensionInstallationURL:(NSURL *)url;
/// given parameters from app invocation, determine whether app can open it
/// @param resultingURL [out] if options contained URL parameter, UNCHANGED
+ (BOOL)testLaunchOptions:(NSDictionary *)options containsURL:(NSURL **)resultingURL;
/// Covers the URLs which are NOT extension installation
/// @param resultingURL [out] is optionally modified to have http(s) scheme
/// instead of kitt(s)
+ (BOOL)testOpenabilityOfURL:(NSURL *)url resultingURL:(NSURL **)resultingURL;

/// make a keyword search URL
/// @param query to construct the URL with
/// @return NSString not NSURL because it needs to be feed in UITextField
/// and the browser implementation is making NSURL on its own
+ (NSString *)keywordSearchURLStringWithQuery:(NSString *)query;

+ (NSUInteger)keyboardAdditionalToolbarHeight;

+ (NSTimeInterval)timeoutForLocalFakeHTTPRequest;
+ (NSTimeInterval)timeoutForDevServerHTTPRequest;

+ (BOOL)isDevModeOn;
/// @return bundle produced as target of Kitt-core compilation
+ (NSBundle *)coreBundle;

/// if yes, Kitt core will try to use WKWebView for background script.
+ (BOOL)useWKWebViewIfAvailable;

/// The browser can be "without tabs", ie. all tabs can get closed
+ (BOOL)canCloseLastTab;

+ (void)configureTestEnviroment;

+ (void)overwriteSettingsWithValuesFromDictionary:(NSDictionary *)dictionary;

@end
