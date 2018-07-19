//
//  KittCore.h
//  KittCore
//
//  Created by Pavel Zdeněk on 08/06/15.
//  Copyright (c) 2015 Browser Technology s.r.o. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for KittCore.
FOUNDATION_EXPORT double KittCoreVersionNumber;

//! Project version string for KittCore.
FOUNDATION_EXPORT const unsigned char KittCoreVersionString[];

/**
 On top of the framework exported public headers, all ObjC headers with classes
 needed to use in Swift must be manually added here.
 It's a replacement of "Objective-C Bridging Header" which cannot and must not be
 used in framework target.
 */
#import <KittCore/OnePasswordExtension.h>
#import <KittCore/UIBAlertView.h>

#import <KittCore/Settings.h>
#import <KittCore/BridgeSwitchboard.h>
#import <KittCore/SAContentWebView.h>
#import <KittCore/ExtensionBackgroundContext.h>
#import <KittCore/ExtensionUnpacker.h>
#import <KittCore/ExtensionModelEventDelegate.h>
#import <KittCore/ExtensionViewDelegates.h>
#import <KittCore/BrowserPageSharingActivity.h>
#import <KittCore/BrowserStateCoreData.h>
#import <KittCore/BrowserStateModel.h>
#import <KittCore/NSObject+AddWebRequestRules.h>
#import <KittCore/XMLHTTPRequest.h>
#import <KittCore/ConnectionAuthenticator.h>
#import <KittCore/ContextMenuItem.h>
#import <KittCore/ContextMenuProvider.h>
#import <KittCore/DownloadProgressObserver.h>
#import <KittCore/FulltextSearchObserver.h>
#import <KittCore/JSInjectorReporter.h>
#import <KittCore/NSArray+IterateAsyncSeries.h>
#import <KittCore/NSData+ChromeBundleParser.h>
#import <KittCore/NSHTTPURLResponse+Uncacheable.h>
#import <KittCore/NSJSONSerialization+NSString.h>
#import <KittCore/NSString+PatternMatching.h>
#import <KittCore/NSTimer+Blocks.h>
#import <KittCore/NSURL+Conformance.h>
#import <KittCore/NetworkActivityFilter.h>
#import <KittCore/OmniboxDataSource.h>
#import <KittCore/PasteboardChecker.h>
#import <KittCore/NetworkActivityObserver.h>
#import <KittCore/WebViewProtocolDelegate.h>
#import <KittCore/ProtocolHandlerChromeExt.h>
#import <KittCore/ProtocolHandlerJSBridge.h>
#import <KittCore/ReachabilityCentral.h>
#import <KittCore/RequestFilteringCache.h>
#import <KittCore/RequestRule.h>
#import <KittCore/RuleConditionGroup.h>
#import <KittCore/RuleCondition_BlockingResponse.h>
#import <KittCore/RuleCondition_ChromeGlob.h>
#import <KittCore/RuleCondition_DetailPath.h>
#import <KittCore/RuleCondition_UrlFilter.h>
#import <KittCore/SAWebViewFaviconLoader.h>
#import <KittCore/UIImage+Transform.h>
#import <KittCore/UnpreventableUILongPressGestureRecognizer.h>
#import <KittCore/Utils.h>
#import <KittCore/WebRequestEventDispatcher.h>
#import <KittCore/WebViewGesturesHandler.h>
#import <KittCore/NSObject+Thread.h>
#import <KittCore/BrowserContextActionSheet.h>
#import <KittCore/ConnectionDelegateSanitizer.h>
