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

#import "BrowserStateModel.h"
#import "Settings.h"
#import "ExtensionUnpacker.h"
#import "BridgeSwitchboard.h"
#import "Utils.h"
#import "BrowserStateCoreData.h"
#import "UIBAlertView.h"
#import "JSInjectorReporter.h"
#import "ProtocolHandlerChromeExt.h"
#import "NSURL+Conformance.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@interface BrowserStateModel ()

@property (nonatomic, strong) NSMutableArray *extensions;
@property (nonatomic, strong) BridgeSwitchboard *switchboard;
@property (nonatomic, strong) BrowserStateCoreData *persistence;
@property (nonatomic, strong) ExtensionUnpacker *bundleUnpacker;
@property (nonatomic, strong) JSInjectorReporter *injector;
@property (nonatomic, strong) NSMutableArray *eventDelegates; // aka listeners

@end

static NSDictionary<NSNumber *, NSString *> *transitionTypeMapping;
static NSDictionary<NSNumber *, NSString *> *transitionQualifierMapping;

@implementation BrowserStateModel

+ (void)initialize
{
    // https://developer.chrome.com/extensions/webNavigation#type-TransitionType
    transitionTypeMapping = @{
                              @(TransitionTypeLink) : @"link",
                              @(TransitionTypeTyped) : @"typed",
                              @(TransitionTypeAutoBookmark) : @"auto_bookmark",
                              @(TransitionTypeAutoSubframe) : @"auto_subframe",
                              @(TransitionTypeManualSubframe) : @"manual_subframe",
                              @(TransitionTypeGenerated) : @"generated",
                              @(TransitionTypeStartPage) : @"start_page",
                              @(TransitionTypeFormSubmit) : @"form_submit",
                              @(TransitionTypeReload) : @"reload",
                              @(TransitionTypeKeyword) : @"keyword",
                              @(TransitionTypeKeywordGenerated) : @"keyword_generated"
                              };
    
    // https://developer.chrome.com/extensions/webNavigation#type-TransitionQualifier
    transitionQualifierMapping = @{
                                   @(TransitionQualifierClientRedirect) : @"client_redirect",
                                   @(TransitionQualifierServerRedirect) : @"server_redirect",
                                   @(TransitionQualifierForwardBack) : @"forward_back",
                                   @(TransitionQualifierFromAddressBar) : @"from_address_bar"
                                   };
}

- (id)initWithSwitchboard:(BridgeSwitchboard *)switchboard
              persistence:(BrowserStateCoreData *)persistence
           bundleUnpacker:(ExtensionUnpacker *)unpacker
               jsInjector:(JSInjectorReporter *)injector
{
    if (self = [super init]) {
        _switchboard = switchboard;
        _persistence = persistence;
        _eventDelegates = [NSMutableArray new];
        _extensions = [NSMutableArray new];
        _bundleUnpacker = unpacker;
        _injector = injector;
        return self;
    }
    return nil;
}

- (BOOL)loadExtensions:(NSError *__autoreleasing *)error
{
    if (*error) {
        return NO;
    }
    // look up ids of already installed/unpacked extensions
    NSArray *extensionIds = [_bundleUnpacker arrayOfInstalledExtensionIdsOrError:error];
    if (*error || !extensionIds || ([extensionIds count] == 0)) {
        return NO;
    }
    NSError *localError = nil;
    // re-create the found extensions
    for (NSString *extensionId in extensionIds) {
        BrowserExtension *extension = [self createExtensionWithId:extensionId error:&localError];
        if (localError) {
            [Utils error:error wrapping:localError message:@"Loading extension %@", extensionId];
            return NO;
        }
        [_extensions addObject:extension];
        [self callDelegatesWithEvent:@selector(onModelExtensionAdded:) andParameter:extension];
    }
    return YES;
}

#pragma mark Subscriber pattern

- (void)subscribe:(id<ExtensionModelEventDelegate>)delegate
{
    [_eventDelegates addObject:delegate];
}

- (void)unsubscribe:(id<ExtensionModelEventDelegate>)delegate
{
    [_eventDelegates removeObject:delegate];
}

- (void)callDelegatesWithEvent:(SEL)selector andParameter:(id)param
{
    for (id<ExtensionModelEventDelegate> delegate in _eventDelegates) {
        if ([delegate respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            if (!param) {
                [delegate performSelector:selector];
            } else {
                [delegate performSelector:selector withObject:param];
            }
#pragma clang diagnostic pop
        }
    }
}

- (BrowserExtension *)extensionWithId:(NSString *)extensionId
{
    NSUInteger idx = [_extensions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        if ([((BrowserExtension *)obj).extensionId isEqualToString:extensionId]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    return (idx == NSNotFound) ? nil : [_extensions objectAtIndex:idx];
}

#pragma mark ExtensionModelDataSource

- (NSUInteger)extensionCount
{
    return [_extensions count];
}

- (BrowserExtension *)extensionAtIndex:(NSInteger)number
{
    return [_extensions objectAtIndex:number];
}

- (void)removeExtensionAtIndex:(NSInteger)idx error:(NSError *__autoreleasing *)error
{
    BrowserExtension *extension = [_extensions objectAtIndex:idx];
    if (!extension) {
        [Utils error:error wrapping:nil message:@"Model instructed to remove nonexistent script at index %d", idx];
        return;
    }
    [self removeExtension:extension];
    [self removeExtensionSupportDataById:extension.extensionId persistData:NO error:error];
}

- (void)removeExtensionSupportDataById:(NSString *)extensionId
                           persistData:(BOOL)persist
                                 error:(NSError *__autoreleasing *)error
{
    [_bundleUnpacker deleteUnpackedExtensionOfId:extensionId error:error];
    if (!persist) {
        Extension *extension = [_persistence extensionObjectWithId:extensionId];
        if (extension) {
            [_persistence deleteManagedObjects:@[ extension ]];
        }
    }
}
- (void)removeExtension:(BrowserExtension *)extension
{
    [self callDelegatesWithEvent:@selector(onModelWillRemoveExtension:) andParameter:extension];
    [extension removeCallbacksFor:CallbackOriginContent];
    [_extensions removeObject:extension];
}

#pragma mark BrowserExtensionChangeDelegate

- (void)browserExtension:(BrowserExtension *)extension enabled:(BOOL)enabled
{
    [self callDelegatesWithEvent:@selector(onModelExtensionChanged:) andParameter:extension];
}

#pragma mark - WebNavigationEventsDelegate

- (void)createdNavigationTargetWithURL:(NSURL *)url
                              newTabId:(NSUInteger)tabId
                           sourceTabId:(NSInteger)srcTabId
                         sourceFrameId:(NSInteger)srcFrameId
{
    // https://developer.chrome.com/extensions/webNavigation#event-onCreatedNavigationTarget
    NSDictionary *properties = @{
                                 @"sourceTabId" : @(srcTabId),
                                 @"sourceFrameId" : @(srcFrameId),
                                 @"sourceProcessId" : @(0),
                                 @"url" : url.absoluteString,
                                 @"tabId" : @(tabId),
                                 @"timeStamp" : @(round([[NSDate date] timeIntervalSince1970] * 1000.0))
                                 };
    [_switchboard.eventDispatcher dispatchWebNavigation:CallbackEvent_WebNavigation_OnCreatedNavTarget
                                                   json:properties];
}

- (void)beforeNavigateToURL:(NSURL *)url
                      tabId:(NSUInteger)tabId
                    frameId:(NSUInteger)frameId
              parentFrameId:(NSInteger)parentId
{
    // https://developer.chrome.com/extensions/webNavigation#event-onBeforeNavigate
    NSDictionary *properties = @{
                                 @"frameId" : @(frameId),
                                 @"parentFrameId" : @(parentId),
                                 @"url" : url.absoluteString,
                                 @"tabId" : @(tabId),
                                 @"timeStamp" : @(round([[NSDate date] timeIntervalSince1970] * 1000.0))
                                 };
    [_switchboard.eventDispatcher dispatchWebNavigation:CallbackEvent_WebNavigation_OnBeforeNavigate
                                                   json:properties];
}

- (void)committedNavigationToURL:(NSURL *)url
                           tabId:(NSUInteger)tabId
                         frameId:(NSUInteger)frameId
                            type:(WebNavigationTransitionType)transitionType
                      qualifiers:(NSArray<NSNumber *> *)transitionQualifiers
{
    NSString *transitionTypeString = transitionTypeMapping[@(transitionType)];
    if (!transitionTypeString) {
        transitionTypeString = @"";
    }
    NSMutableArray<NSString *> *transitionQualifiersStrings = [NSMutableArray new];
    [transitionQualifiers enumerateObjectsUsingBlock:^(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        NSString *qualifierString = transitionQualifierMapping[obj];
        if (qualifierString) {
            [transitionQualifiersStrings addObject:qualifierString];
        }
    }];
    // https://developer.chrome.com/extensions/webNavigation#event-onCommitted
    NSDictionary *properties = @{
                                 @"tabId" : @(tabId),
                                 @"url" : url.absoluteString,
                                 @"processId" : @(0),
                                 @"frameId" : @(frameId),
                                 @"transitionType" : transitionTypeString,
                                 @"transitionQualifiers" : transitionQualifiersStrings,
                                 @"timeStamp" : @(round([[NSDate date] timeIntervalSince1970] * 1000.0))
                                 };
    [_switchboard.eventDispatcher dispatchWebNavigation:CallbackEvent_WebNavigation_OnCommitted
                                                   json:properties];
}

- (void)completedNavigationToURL:(NSURL *)url
                           tabId:(NSUInteger)tabId
                         frameId:(NSUInteger)frameId
{
    // https://developer.chrome.com/extensions/webNavigation#event-onCompleted
    NSDictionary *properties = @{
                                 @"tabId" : @(tabId),
                                 @"url" : url.absoluteString,
                                 @"processId" : @(0),
                                 @"frameId" : @(frameId),
                                 @"timeStamp" : @(round([[NSDate date] timeIntervalSince1970] * 1000.0))
                                 };
    [_switchboard.eventDispatcher dispatchWebNavigation:CallbackEvent_WebNavigation_OnCompleted
                                                   json:properties];
}

- (nonnull NSArray *)arrayOfExtensionUnspecificCallbacksOfType:(CallbackEventType)eventType
{
    NSMutableArray *completeList = [NSMutableArray new];
    for (BrowserExtension *extension in _extensions) {
        [completeList addObjectsFromArray:
         [extension callbacksFor:CallbackOriginContent
                           event:eventType]];
    }
    return completeList;
}

#pragma mark - ContentScriptLoaderDelegate

- (void)filterExtensionInstallationFromURL:(NSURL *)reqUrl
                         completionHandler:(void (^)(NSError *))completionHandler
{
    __block NSError *resultError = nil;
    if (![Settings isExtensionInstallationURL:reqUrl]) {
        [Utils error:&resultError wrapping:nil message:@"Server\n%@\nis not authorized source of extensions", [reqUrl host]];
        completionHandler(resultError);
        return;
    }
    NSURLResponse *resp = nil;
    NSError *localErr = nil;
    NSData *respData = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:reqUrl]
                                             returningResponse:&resp
                                                         error:&localErr];
    if (localErr) {
        [Utils error:&resultError wrapping:localErr message:@"Extension data download failure"];
        completionHandler(resultError);
        return;
    }
    // parse script id out of the URL which gave us the data
    NSArray *pathDecomposed = [reqUrl pathComponents];
    NSString *extensionId = pathDecomposed[pathDecomposed.count - 1];
    if (!extensionId) {
        [Utils error:&resultError wrapping:nil message:@"Unrecognizable extension path"];
        completionHandler(resultError);
        return;
    }
    // Remove zip suffix
    if ([extensionId hasSuffix:@".zip"]) {
        extensionId = [extensionId substringToIndex:extensionId.length - 4];
    }
    // check whether the extension is (not) already installed
    BrowserExtension *extension = [self extensionWithId:extensionId];
    BOOL hasBundle = [_bundleUnpacker hasExtensionOfId:extensionId error:&localErr];
    if (localErr) {
        [Utils error:&resultError wrapping:localErr message:@"Error occured while checking extension existence"];
        completionHandler(resultError);
        return;
    }
    if (!extension) {
        if (hasBundle) {
            // The extension is not officially known to be installed. If the unpacked
            // bundle exists, it is most probably a failed previous installation.
            // In any case, delete it completely because it's in undeterminate state.
            [self removeExtensionSupportDataById:extensionId persistData:NO error:&localErr];
            if (localErr) {
                UIAlertView *alert = [Utils alertViewWithError:localErr
                                                         title:@"Removing broken bundle"
                                                      delegate:nil];
                [alert show];
                return;
            }
        }
        [self unpackAndCreateExtensionWithId:extensionId fromData:respData error:&resultError];
        completionHandler(resultError);
        return;
    }
    // Extension already installed, reinstall if user wants it.
    // Use 3rd-party alertview with block-based handler, so that respData and extensionId
    // can continue to be kept as local scope variables. Normal alertview with
    // separate delegate would require making them object members.
    UIBAlertView *alert = [[UIBAlertView alloc] initWithTitle:BundleLocalizedString(@"Extension already installed", @"Extension installation")
                                                      message:BundleLocalizedString(@"Do you want to update or cancel installation?", @"Extension installation")
                                            cancelButtonTitle:BundleLocalizedString(@"Cancel", @"Extension installation")
                                            otherButtonTitles:BundleLocalizedString(@"Update", @"Extension installation"), nil];
    [alert showWithDismissHandler:^(NSInteger selectedIndex, BOOL didCancel) {
        // A new internal error instance must be used. We are in block upon
        // alert button click, which means that the original autoreleased error**
        // is already gone.
        if (didCancel || (selectedIndex != 1)) {
            return;
        }
        // remove just the bundle, persist data storage
        [self removeExtensionSupportDataById:extensionId persistData:YES error:&resultError];
        // extension needs to be removed/uninstalled to initiate clearing of loaded scripts
        [self removeExtension:extension];
        if (!resultError) {
            [self unpackAndCreateExtensionWithId:extensionId fromData:respData error:&resultError];
        }
        completionHandler(resultError);
    }];
}

- (BrowserExtension *)unpackAndCreateExtensionWithId:(NSString *)extensionId
                                            fromData:(NSData *)data
                                               error:(NSError *__autoreleasing *)error
{
    NSError *localErr = nil;
    // try unpacking the bundle
    [_bundleUnpacker unpackBundleData:data asExtensionOfId:extensionId error:&localErr];
    if (localErr) {
        [Utils error:error wrapping:localErr message:@"Failed unpacking"];
        return nil;
    }
    // create the extension
    BrowserExtension *extension = [self createExtensionWithId:extensionId error:&localErr];
    if (localErr) {
        [Utils error:error wrapping:localErr message:@"Failed unpacking"];
        return nil;
    } else {
        [_extensions addObject:extension];
        extension.enabled = YES;
        [self callDelegatesWithEvent:@selector(onModelExtensionAdded:) andParameter:extension];
        return extension;
    }
}

- (BrowserExtension *)createExtensionWithId:(NSString *)extensionId error:(NSError *__autoreleasing *)error
{
    // create manifest
    NSError *localError = nil;
    NSData *manifestData = [_bundleUnpacker dataOfResource:@"manifest.json"
                                           inExtensionOfId:extensionId
                                                     error:&localError];
    if (localError) {
        [Utils error:error wrapping:localError message:@"Getting manifest"];
        return nil;
    }
    
    Manifest *manifest = [[Manifest alloc] initWithData:manifestData error:&localError];
    if (localError) {
        [Utils error:error wrapping:localError message:@"Validating manifest"];
        return nil;
    }
    BrowserExtension *newExtension = [[BrowserExtension alloc] initWithExtensionId:extensionId
                                                                          manifest:manifest
                                                                       persistence:_persistence
                                                                            bundle:_bundleUnpacker
                                                                   commandDelegate:_switchboard];
    newExtension.changeDelegate = self;
    Extension *extension = [_persistence extensionObjectWithId:extensionId];
    if (!extension) {
        extension = [_persistence insertNewObjectForEntityClass:[Extension class]];
        extension.extensionId = extensionId;
        extension.enabled = YES; // default
        [_persistence saveContextWithErrorAlert];
    }
    return newExtension;
}

- (void)configureExtensionWithId:(NSString *)extensionId
               withKeysAndValues:(NSDictionary *)keysAndValues
                           error:(NSError *__autoreleasing *)error
{
    BrowserExtension *extension = [self extensionWithId:extensionId];
    if (!extension) {
        [Utils error:error wrapping:nil message:@"Cannot configure '%@', id invalid", extensionId];
        return;
    }
    [extension.storage merge:keysAndValues error:error];
}

- (NSInteger)injectContentScriptToContext:(JSContext *)context
                                  withURL:(NSURL *)url
                         ofContentWebView:(SAContentWebView *)view
{
    
    NSAssert([NSThread isMainThread], @"Must be run on main thread");
    
    JSValue *window = [context globalObject];
    BOOL isMainFrame = [window isEqualToObject:window[@"top"]];
    if (isMainFrame) {
        // Remove existing callbacks from content scripts of previous page
        [self.switchboard unregisterExtensionsInWebView:view];
    }
    
    NSURL *maybeBundleResURL = [ProtocolHandlerChromeExt URLAsBundleResourceFromString:url.absoluteString];
    if (maybeBundleResURL) {
        NSString *extensionId = [ProtocolHandlerChromeExt extensionIdOfBundleResourceRequest:[NSURLRequest requestWithURL:maybeBundleResURL]];
        NSAssert(extensionId, @"Bundle resource request must have extension id: %@", maybeBundleResURL);
        __block BrowserExtension *bundleExtension = nil;
        [_extensions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            BrowserExtension *iterExtension = (BrowserExtension *)obj;
            if ([iterExtension.extensionId isEqualToString:extensionId]) {
                bundleExtension = iterExtension;
                *stop = YES;
            }
        }];
        NSAssert(bundleExtension, @"Bundle cannot find extension %@", extensionId);
        NSString *injection = [_injector stringWithContentDOMAPIForExtensionId:extensionId
                                                                         tabId:view.identifier];
        // extension registration needs to be before injection because it may result in
        // immediate bridge request which will be already looking for the extension
        [_switchboard registerExtension:bundleExtension inContentWebView:view];
        BOOL injectionSuccess = [_injector injectJavaScriptCode:injection
                                                      toWebView:view
                                                      orContext:isMainFrame ? nil : context
                                          errorReportProperties:@{
                                                                  @"context" : @"bundle resource content script",
                                                                  @"extension" : extensionId,
                                                                  @"url" : url.absoluteString ? url.absoluteString : [NSNull null]
                                                                  }];
        return injectionSuccess ? 0 : -1;
    }
    
    if (isMainFrame) {
        for (BrowserExtension *extension in _extensions) {
            
            if (!extension.enabled) {
                LogDebug(@"Script '%@' is disabled", extension.manifest.name);
                continue;
            }
            
            BOOL found = false;
            for (ContentScript *script in extension.contentScripts) {
                
                NSError *err = nil;
                NSString *contentCode = [extension scriptFor:script error:&err];
                if (err) {
                    UIAlertView *alert = [Utils alertViewWithError:err
                                                             title:@"Injecting content scripts"
                                                          delegate:nil];
                    [alert show];
                    break;
                }
                
                if ([contentCode length] != 0) {
                    found = true;
                    break;
                }
            }
            
            // if the extension doesn't have content script, skip injection
            if (!found) {
                LogDebug(@"Extension '%@' doesn't define content script", extension.manifest.name);
                continue;
            }
            
            [self.switchboard registerExtension:extension inContentWebView:view];
        };
    }
    
    BOOL allFrames = false;
    for (BrowserExtension *extension in view.extensions) {
        for (ContentScript *script in extension.contentScripts) {
            allFrames |= script.allFrames;
        }
    }
    
    // Inject callback entry point in any case, even if there are no extensions
    // because it is also a flag of API injection already passed
    BOOL success = [_injector injectContentWindowGlobalSymbolsToWebView:view
                                                  orNonMainFrameContext:context
                                                            isMainFrame:isMainFrame
                                                     scriptsInAllFrames:allFrames];
    if (!success) {
        return -1;
    }
    
    if ([view.extensions count] == 0) {
        // Nothing to inject
        return 0;
    }
    
    NSUInteger scriptsLoaded = 0;
    for (BrowserExtension *extension in view.extensions) {
        for (ContentScript *script in extension.contentScripts) {
            
            if (!isMainFrame && !script.allFrames) {
                LogDebug(@"Script of extension '%@' must be injected to main frame only.", extension.manifest.name);
                continue;
            }
            
            NSError *err = nil;
            NSString *contentCode = [extension scriptFor:script error:&err];
            if (err) {
                UIAlertView *alert = [Utils alertViewWithError:err
                                                         title:@"Injecting content scripts"
                                                      delegate:nil];
                [alert show];
                continue;
            }
            
            // if the extension doesn't have content script, skip injection
            if ([contentCode length] == 0) {
                LogDebug(@"Extension '%@' doesn't define content script", extension.manifest.name);
                continue;
            }
            
            if (![script applicableOnContentURL:url]) {
                LogDebug(@"Script '%@' not applicable on '%@'", extension.manifest.name, [url absoluteString]);
                continue;
            }
            
            LogDebug(@"Will load content script '%@'", extension.manifest.name);
            NSString *injection = [self.injector stringWithContentScriptAPIForExtensionId:extension.extensionId
                                                                                    tabId:view.identifier
                                                                                    runAt:script.runAt
                                                                           wrappingScript:contentCode];
            // extension registration needs to be before injection because it may result in
            // immediate bridge request which will be already looking for the extension
            NSDictionary *properties =
            @{ @"context" : @"content script",
               @"extension" : extension.extensionId,
               @"url" : url.absoluteString ? url.absoluteString : [NSNull null] };
            
            BOOL injectionSuccess = [self.injector injectJavaScriptCode:injection
                                                              toWebView:view
                                                              orContext:isMainFrame ? nil : context
                                                  errorReportProperties:properties];
            
            if (injectionSuccess) {
                scriptsLoaded++;
            }
        }
    };
    
    return scriptsLoaded;
}

- (BridgeSwitchboard *)bridgeSwitchboard
{
    return _switchboard;
}

@end
