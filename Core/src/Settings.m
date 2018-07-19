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

#import "Settings.h"
// This header dependency is not pretty and should not be here but is needed for
// defaultWebViewUserAgent hack
#import "SAContentWebView.h"
#import "ObjCLogger.h"

// http://gcc.gnu.org/onlinedocs/cpp/Stringification.html#Stringification
#define MACRO_NAME(name) #name
#define MACRO_NSSTRING(name) @MACRO_NAME(name)
// ^ NSString constructor signature, not a GCC magic

#define GREATER_THAN_OR_EQUAL_TO(ver, test) ([ver compare:test options:NSNumericSearch] != NSOrderedAscending)

@implementation Settings

// plists
static NSDictionary *_settings;
static NSDictionary *_mainBundleDefaultPlist;

static NSArray *_schemes;
static NSString *_bridgeScheme;
static NSURL *_devServerURL; // as configured in settings
static NSURL *_prodServerURL; // as taken from compile time parameter
static NSBundle *_kittCoreBundle;

+ (void)initialize
{
    if (self == [Settings class]) {
        [self registerDefaultsFromSettingsBundle];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"];
        _settings = [[NSDictionary alloc] initWithContentsOfFile:path];

        NSString *infoPath = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
        _mainBundleDefaultPlist = [[NSDictionary alloc] initWithContentsOfFile:infoPath];

        NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
        // CFBundleURLTypes contains two sections: "Editor" and "Viewer"
        // Editor declares scheme specific to Kitt bridge (kitt:)
        // Viewer declares all applicable schemes (kitt, kitts, http, https)
        for (NSDictionary *oneUrl in urlTypes) {
            NSArray *inputSchemes = [oneUrl objectForKey:@"CFBundleURLSchemes"];
            NSString *role = [oneUrl objectForKey:@"CFBundleTypeRole"];
            if ([role isEqualToString:@"Editor"]) {
                _bridgeScheme = inputSchemes[0];
            }
            if ([role isEqualToString:@"Viewer"]) {
                _schemes = inputSchemes;
            }
        }
        // cmdline parameters are loaded into NSUser defaults
        // with high priority via NSArgumentDomain
        // NSUserDefaults *stdUserDefs = [NSUserDefaults standardUserDefaults];
        // _extensionServerHost = [stdUserDefs stringForKey:@"server"];
        // if( !_extensionServerHost ) {
        // }
        // CMDLINE PARAMETERS NOT USED NOW
        _prodServerURL = [NSURL URLWithString:
                          [NSString stringWithFormat:@"https://%@",
                           MACRO_NSSTRING(DEPLOY_SERVER)]];
    }
}

/**
 A workaround unfortunately needed to work around the limitations of app-specific iOS Setttings. The values
 in Root.plist initially become just labels in the Settings. NSUserDefaults query does not return
 the values, until the value is written (ie. modified) in the Settings. To make the Root.plist a real
 startup defaults, the file must be opened from bundle, default values harvested, and registered.
 - Settings.bundle
 - Root.plist (XML)
 <PreferenceSpecifiers>
 array of dictionaries...
 <Key>Key</Key><string>the_default_value_name</string>
 <Key>DefaultValue</Key><various_element_type_per_default/>
 */
+ (void)registerDefaultsFromSettingsBundle
{
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if (!settingsBundle) {
        LogInfo(@"Settings.bundle does not exist, will not register defaults");
        return;
    }
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];

    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for (NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if (key) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
}

+ (NSString *)applicationVersion
{
    return [_mainBundleDefaultPlist objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString *)applicationBuild
{
    return [_mainBundleDefaultPlist objectForKey:@"CFBundleVersion"];
}

+ (NSString *)coreVersion
{
    return [[self coreBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (BOOL)allowsScheme:(NSString *)scheme
{
    return [_schemes containsObject:scheme];
}

+ (NSURL *)extensionServerURL
{
    if ([self isDevModeOn]) {
        // fallback value if dev_server_ip isn't set properly
        NSURL *extensionServerURL = _prodServerURL;
        NSString *extensionServerStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"dev_server_ip"];
        if (extensionServerStr && ![extensionServerStr isEqualToString:@""]) {
            extensionServerStr = [NSString stringWithFormat:@"http://%@", extensionServerStr];
            NSInteger port = [[NSUserDefaults standardUserDefaults] integerForKey:@"dev_server_port"];
            if (port > 0) {
                extensionServerStr = [extensionServerStr stringByAppendingFormat:@":%ld", (long)port];
            }
            extensionServerURL = [NSURL URLWithString:extensionServerStr];
        }
        return extensionServerURL;
    } else {
        return _prodServerURL;
    }
}

+ (NSURL *)devServerURLWithResource:(ExtensionServerResourceType)resourceType
{
    NSString *resource = nil;
    NSString *scheme = _bridgeScheme;
    switch (resourceType) {
        case ExtensionServerResource_Listing:
            resource = [_settings objectForKey:@"ExtensionServerResource_Listing"];
            // listing must not be presented with kitt: scheme because it is displayed
            // in public webview and is wrongly treated as extension installation request
            scheme = [self extensionServerScheme];
            break;
        case ExtensionServerResource_Logger:
            resource = [_settings objectForKey:@"ExtensionServerResource_Logger"];
            break;
        case ExtensionServerResource_Extension: {
            resource = [_settings objectForKey:@"ExtensionServerResource_ResourceHosting"];
        } break;
        default:
            resource = @"/";
            break;
    }
    // NSURL has no method to get complete hostname with port. Sidestep hack is to
    // get resourceSpecifier and strip leading double slash
    NSString *extensionServerWithPort = [[self extensionServerURL].resourceSpecifier substringFromIndex:2];
    return [[NSURL alloc] initWithScheme:scheme host:extensionServerWithPort path:resource];
}

+ (NSURL *)extensionServerURLForExtensionListing
{
    return [self isDevModeOn] ? [self devServerURLWithResource:ExtensionServerResource_Listing] : _prodServerURL;
}

/// must be lazy init.
/// When it was directly in constructor, it was invoking JS context creation too early
+ (NSString *)defaultWebViewUserAgent
{
    static NSString *defaultUIWebViewUserAgent;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // The following JS evaluation invokes JS context creation. It ends up in didCreateJSContext
        // listener which expects that the originating webview is known, i.e. registered with
        // SAWebViewManager. So a webview of the right type must be created and temporarily registered.
        UIWebView *tempWebView = [[SAPopupWebView alloc] initWithFrame:CGRectZero];
        defaultUIWebViewUserAgent = [tempWebView
                                     stringByEvaluatingJavaScriptFromString:
                                     @"window.navigator.userAgent"];
        NSAssert(defaultUIWebViewUserAgent && defaultUIWebViewUserAgent.length > 0, @"Cannot determine default User-Agent");
        NSString *safariVersion = @"600.1.4"; // default for iOS 8, oldest applicable version
        NSError *err = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"AppleWebKit/([0-9.]+)"
                                                                               options:0
                                                                                 error:&err];
        NSTextCheckingResult *match = [regex firstMatchInString:defaultUIWebViewUserAgent
                                                        options:0
                                                          range:NSMakeRange(0, [defaultUIWebViewUserAgent length])];
        if (match) {
            // iOS8+ _seems_ to be simply copying WebKit version to Safari version
            // It can be absolutely found untrue with future iOS versions
            safariVersion = [defaultUIWebViewUserAgent substringWithRange:[match rangeAtIndex:1]];
        } else {
            LogError(@"WebView userAgent does not contain AppleWebKit token");
            // fallback to hardcoded versions
            NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
            if (GREATER_THAN_OR_EQUAL_TO(systemVersion, @"8.0")) {
                safariVersion = @"601.1.4"; // iOS9+
            }
        }
        defaultUIWebViewUserAgent = [NSString stringWithFormat:@"%@ Safari/%@", defaultUIWebViewUserAgent, safariVersion];
    });
    return defaultUIWebViewUserAgent;
}

+ (NSString *)extensionServerScheme
{
    return [self extensionServerURL].scheme;
}

+ (NSString *)bridgeScheme
{
    return _bridgeScheme;
}

+ (BOOL)isExtensionInstallationURL:(NSURL *)url
{
    if ([self allowsScheme:[url scheme]]) {
        if ([url.scheme isEqualToString:_bridgeScheme]) {
            if ([url.host isEqualToString:[self extensionServerURL].host] ||
                [url.host hasSuffix:[_settings objectForKey:@"ExtensionServerWhitelistSuffix"]]) {
                return YES;
            }
            LogWarn(@"Downloading %@ not allowed from %@",
                    _bridgeScheme, [url host]);
        }
    }
    return NO;
}

+ (BOOL)testOpenabilityOfURL:(NSURL *)url resultingURL:(NSURL **)resultingURL
{
    NSString *incomingScheme = url.scheme;
    if (![self allowsScheme:incomingScheme]) {
        return NO;
    }
    if (resultingURL) {
        *resultingURL = [url copy]; // default: give back the original URL
        if (![self isExtensionInstallationURL:url] && [incomingScheme hasPrefix:_bridgeScheme]) {
            // scheme starts with kitt *but is not extension installation
            // switch kitt(s) to http(s)
            NSURLComponents *components = [NSURLComponents componentsWithURL:url
                                                     resolvingAgainstBaseURL:NO];
            components.scheme = [components.scheme stringByReplacingOccurrencesOfString:_bridgeScheme
                                                                             withString:@"http"];
            *resultingURL = components.URL;
        }
    }
    return YES;
}

+ (BOOL)testLaunchOptions:(NSDictionary *)options containsURL:(NSURL *__autoreleasing *)resultingURL;
{
    if (resultingURL) {
        *resultingURL = nil;
    }
    if (!options) {
        // started with no options
        return YES;
    }
    NSURL *urlFromOptions = [options objectForKey:UIApplicationLaunchOptionsURLKey];
    if (!urlFromOptions) {
        // given some options, but not URL
        return YES;
    }
    return [self testOpenabilityOfURL:urlFromOptions resultingURL:resultingURL];
}

+ (NSString *)keywordSearchURLStringWithQuery:(NSString *)query
{
    query = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"https://www.google.com/search?q=%@", query];
}

+ (NSUInteger)keyboardAdditionalToolbarHeight
{
    // iOS default is 49 but let's be smaller to minimize obscured space
    return 40;
}

+ (BOOL)isDevModeOn
{
    NSNumber *flag = [[NSUserDefaults standardUserDefaults] objectForKey:@"dev_server_enable"];
    return flag ? [flag boolValue] : NO;
}

+ (NSTimeInterval)timeoutForLocalFakeHTTPRequest
{
#ifdef DEBUG
    return (NSTimeInterval)CGFLOAT_MAX;
#else
    return (NSTimeInterval)5.0; // seconds
#endif
}

+ (NSTimeInterval)timeoutForDevServerHTTPRequest
{
#ifdef DEBUG
    return (NSTimeInterval)CGFLOAT_MAX;
#else
    return (NSTimeInterval)10.0; // seconds
#endif
}

+ (NSString *)emailAddressForLoggedAppFailures
{
    return [_settings objectForKey:@"EmailAddressForLoggedAppFailures"];
}

+ (NSBundle *)coreBundle
{
    if (!_kittCoreBundle) {
        NSString *bundleFolderName = _settings[@"KittCoreBundleName"];
        NSString *kittCoreBundlePath = [[NSBundle mainBundle] pathForResource:bundleFolderName ofType:@"bundle"];
        _kittCoreBundle = [NSBundle bundleWithPath:kittCoreBundlePath];
    }
    return _kittCoreBundle;
}

+ (BOOL)useWKWebViewIfAvailable
{
    id value = _settings[@"UseWKWebViewIfAvailable"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value boolValue];
    } else {
        return NO;
    }
}

+ (BOOL)canCloseLastTab
{
    id value = _settings[@"CanCloseLastTab"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value boolValue];
    } else {
        return NO;
    }
}

+ (void)configureTestEnviroment
{
    _bridgeScheme = @"kitt";

    NSString *bundleFolderName = @"KittCoreBundle";
    NSString *kittCoreBundlePath = [[NSBundle bundleForClass:BrowserExtension.class] pathForResource:bundleFolderName ofType:@"bundle"];
    _kittCoreBundle = [NSBundle bundleWithPath:kittCoreBundlePath];
    _mainBundleDefaultPlist = @{ @"CFBundleShortVersionString" : @"1.5.2",
                                 @"CFBundleVersion" : @"0"
                                 };
    _settings = @{ @"UseWKWebViewIfAvailable" : @YES };
}

+ (void)overwriteSettingsWithValuesFromDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *settings = [_settings mutableCopy];
    [settings addEntriesFromDictionary:dictionary];
    _settings = settings;
}

@end
