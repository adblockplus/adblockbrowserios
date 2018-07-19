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

#import "JSInjectorReporter.h"
#import "UIBAlertView.h"
#import "Settings.h"
#import "Utils.h"
#import "SAContentWebView.h"
#import "UIBAlertView.h"
#import "NSJSONSerialization+NSString.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@interface JSInjectorReporter ()

@property (nonatomic, strong) NSArray *apiForContext;

@end

@implementation JSInjectorReporter

static NSString *API_SUCCESS_RETVAL = @"OK";
static NSString *API_SUCCESS_TOKEN = @"__SUCCESS__";

static NSString *ALL_FRAMES = @"_ALL_FRAMES_";
static NSString *ADDON_ID_TOKEN = @"%ADDON_ID%";
static NSString *TAB_ID_TOKEN = @"%TAB_ID%";
static NSString *BROWSERIFIED_API_TOKEN = @"__BROWSERIFIED_API__";
// Content script token must be a complete parseable JS entity, otherwise minification fails.
// This code has an advantage of doing an useful reporting when script injection fails
static NSString *USERSCRIPT_TOKEN = @"throw new Error('Content script not replaced')";
static NSString *CONTENT_SCRIPT_RUN_AT = @"%RUN_AT%";

// @warning Do not reorder unless apiForContext initialization is reordered too!
typedef NS_ENUM(NSUInteger, APIExecutionContext) {
    APIExecutionContext_BrowserAction,
    APIExecutionContext_Background,
    APIExecutionContext_ContentScript,
    APIExecutionContext_ContentDOM,
    APIExecutionContext_ContentMainframe,
    APIExecutionContext_ContentSubframe
};

/**
 @param apiFilename of the browserified API
 @param wrapperFilename of the injection context
 @param relevant execution wrapper as defined above
 */
- (NSString *)stringByInstrumentingBrowserifiedAPIFromJs:(NSString *)apiFilename bundle:(NSBundle *)bundle
{
    NSError *errFileLoad = nil;
    // load the prepared JS API template
    NSString *filePath = [bundle pathForResource:apiFilename ofType:@"js"];
    NSString *apiSource = [NSString stringWithContentsOfFile:filePath
                                                    encoding:NSUTF8StringEncoding
                                                       error:&errFileLoad];
    if (errFileLoad) {
        // Bundle construction problem, not a runtime problem. Crude reporting is good enough
        UIAlertView *alert = [Utils alertViewWithError:errFileLoad title:apiFilename delegate:nil];
        [alert show];
        return @""; // to prevent exception "insert nil" and allow the alert display
    }
    // replace tokens in wrapper
    apiSource = [apiSource stringByReplacingOccurrencesOfString:API_SUCCESS_TOKEN withString:API_SUCCESS_RETVAL];
    return apiSource;
}

- (instancetype)init
{
    return [self initWithBundle:[Settings coreBundle]];
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    if (self = [super init]) {
        // prepare APIs just for %USERSCRIPT% replacement
        // @warning Follow the order of insertion defined by APIExecutionContext enum!
        _apiForContext =
            @[
               [self stringByInstrumentingBrowserifiedAPIFromJs:@"api_popup"
                                                         bundle:bundle],
               [self stringByInstrumentingBrowserifiedAPIFromJs:@"api_background"
                                                         bundle:bundle],
               [self stringByInstrumentingBrowserifiedAPIFromJs:@"api_content_script"
                                                         bundle:bundle],
               [self stringByInstrumentingBrowserifiedAPIFromJs:@"api_content_dom"
                                                         bundle:bundle],
               [self stringByInstrumentingBrowserifiedAPIFromJs:@"api_content_mainframe"
                                                         bundle:bundle],
               [self stringByInstrumentingBrowserifiedAPIFromJs:@"api_content_subframe"
                                                         bundle:bundle]
            ];
    }
    return self;
}

- (NSString *)stringWithBackgroundAPIForExtensionId:(NSString *)extensionId
{
    NSString *wrapperCopy = [NSString stringWithString:_apiForContext[APIExecutionContext_Background]];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:ADDON_ID_TOKEN withString:extensionId];
    return wrapperCopy;
}

- (NSString *)stringWithBrowserActionAPIForExtensionId:(NSString *)extensionId
{
    NSString *wrapperCopy = [NSString stringWithString:_apiForContext[APIExecutionContext_BrowserAction]];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:ADDON_ID_TOKEN withString:extensionId];
    return wrapperCopy;
}

- (NSString *)stringWithContentScriptAPIForExtensionId:(NSString *)extensionId
                                                 tabId:(NSUInteger)tabId
                                                 runAt:(NSString *)runAt
                                        wrappingScript:(NSString *)script
{
    NSString *tabIdStr = [@(tabId) stringValue];
    NSString *wrapperCopy = [NSString stringWithString:_apiForContext[APIExecutionContext_ContentScript]];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:ADDON_ID_TOKEN withString:extensionId];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:TAB_ID_TOKEN withString:tabIdStr];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:USERSCRIPT_TOKEN withString:script];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:CONTENT_SCRIPT_RUN_AT withString:runAt];
    return wrapperCopy;
}

- (NSString *)stringWithContentDOMAPIForExtensionId:(NSString *)extensionId
                                              tabId:(NSUInteger)tabId
{
    NSString *tabIdStr = [@(tabId) stringValue];
    NSString *wrapperCopy = [NSString stringWithString:_apiForContext[APIExecutionContext_ContentDOM]];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:ADDON_ID_TOKEN withString:extensionId];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:TAB_ID_TOKEN withString:tabIdStr];
    return wrapperCopy;
}

- (id)handleInjectionResult:(NSString *)evalResult
             withCallbackId:(NSString *)callbackId
                 withOrigin:(CallbackOriginType)origin
      errorReportProperties:(NSDictionary *)properties
              responseError:(NSError *__autoreleasing *)error
{

    NSString *callbackUndefRetval = [NSString stringWithFormat:@"%@ undefined", callbackId];

    if (evalResult && ![evalResult isKindOfClass:[NSString class]]) {
        return evalResult;
        // injection didn't succeed in some way
    } else if (!evalResult || [evalResult isEqualToString:@""]) {
        // should not happen, something is horribly wrong in the API (syntax etc.)
        evalResult = [NSString stringWithFormat:@"Callback %@ returned null/empty result", callbackId];
    } else if ([evalResult isEqualToString:callbackId]) {
        // callback executed correctly and didn't return any specific synchronous value
        // can return nil because the caller should know from command context that
        // return value is not expected. If there is error, responseError would be set.
        return nil;
    } else if ([evalResult hasPrefix:@"ERRORSTACKTRACE"]) {
        evalResult = [evalResult substringFromIndex:[@"ERRORSTACKTRACE" length]];
        evalResult = [self formattedParagraphFromErrorJSONString:evalResult];
    } else if ([evalResult isEqualToString:callbackUndefRetval]) {
        if (origin == CallbackOriginContent) {
            // content script has undefined callback wrapper, report but ignore
            LogWarn(@"Content callback wrapper does not exist, API not injected yet");
            return nil;
        }
    } else if ([evalResult hasPrefix:@"Callback id not found"]) {
        if (origin == CallbackOriginContent) {
            // content script has undefined callback, report but ignore
            LogWarn(@"JS callback '%@' does not exist, API not injected yet", callbackId);
            return nil;
        }
    } else {
        // should end up here with a callback return object
        id retval = [NSJSONSerialization JSONObjectWithString:evalResult options:0 error:error];
        if (*error) {
            evalResult = [NSString stringWithFormat:@"Expecting JSON parseable callback response, got '%@' error '%@'",
                                   evalResult, [*error localizedDescription]];
        } else {
            return retval;
        }
    }
    if (!(*error)) {
        *error = [NSError errorWithDomain:@"Kitt"
                                     code:0
                                 userInfo:@{ NSLocalizedDescriptionKey : evalResult }];
    }
    [self sendInjectionFailureReport:evalResult withExtraProperties:properties];
    return nil;
}

- (void)handleInjectionResult:(NSString *)evalResult
               withCallbackId:(NSString *)callbackId
                   withOrigin:(CallbackOriginType)origin
        errorReportProperties:(NSDictionary *)properties
                andCompletion:(CommandHandlerBackendCompletion)completion
{
    NSError *error;
    id result = [self handleInjectionResult:evalResult
                             withCallbackId:callbackId
                                 withOrigin:origin
                      errorReportProperties:properties
                              responseError:&error];
    completion(error, result);
}

- (BOOL)injectContentWindowGlobalSymbolsToWebView:(SAContentWebView *)webView
                            orNonMainFrameContext:(JSContext *)context
                                      isMainFrame:(BOOL)isMainFrame
                               scriptsInAllFrames:(BOOL)allFrames
{
    APIExecutionContext executionContext = isMainFrame ? APIExecutionContext_ContentMainframe : APIExecutionContext_ContentSubframe;
    NSString *tabIdStr = [@(webView.identifier) stringValue];
    NSString *wrapperCopy = [NSString stringWithString:_apiForContext[executionContext]];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:ADDON_ID_TOKEN withString:kGlobalScopeExtId];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:TAB_ID_TOKEN withString:tabIdStr];
    wrapperCopy = [wrapperCopy stringByReplacingOccurrencesOfString:ALL_FRAMES withString:allFrames ? @"T" : @"F"];
    NSString *urlString = webView.currentURL.absoluteString;
    return [self injectJavaScriptCode:wrapperCopy
                            toWebView:webView
                            orContext:isMainFrame ? nil : context
                errorReportProperties:@{
                    @"context" : @"content window global symbols",
                    @"url" : urlString ? urlString : [NSNull null]
                }];
}

- (BOOL)injectJavaScriptCode:(NSString *)jsCode
                   toWebView:(UIWebView *)webView
                   orContext:(JSContext *)context
       errorReportProperties:(NSDictionary *)properties
{
    // JS evaluation in UIWebView can only return string
    // The JS API is instrumented to return a specific string on success,
    // or a JSON stringified Error on failure
    NSString *evalResult;
    if (context != nil) {
        JSValue *value = [context evaluateScript:jsCode];
        if (context.exception) {
            value = context.exception;
        }
        evalResult = [value toString];
    } else {
        evalResult = [webView stringByEvaluatingJavaScriptFromString:jsCode];
    }
    if ([API_SUCCESS_RETVAL isEqualToString:evalResult]) {
        return YES;
    }
    // injection didn't succeed in some way
    if (!evalResult || [evalResult isEqualToString:@""]) {
        // should not happen, something is horribly wrong in the API (syntax etc.)
        evalResult = @"Eval returned null/empty result";
    } else {
        evalResult = [self formattedParagraphFromErrorJSONString:evalResult];
    }
    [self sendInjectionFailureReport:evalResult withExtraProperties:properties];
    return NO;
}

- (void)sendInjectionFailureReport:(NSString *)report
               withExtraProperties:(NSDictionary *)properties
{
    // not a dev mode, log silently to service
    NSMutableDictionary *props = [NSMutableDictionary dictionaryWithDictionary:properties];
    props[@"report"] = report;
    LogError(@"INJECTION FAILED\n%@\n%@", report, properties);
}

- (NSString *)formattedParagraphFromErrorJSONString:(NSString *)jsonString
{
    // Unpack the returned string as stack trace
    NSError *parsingError = nil;
    id errorDictionary = [NSJSONSerialization JSONObjectWithString:jsonString options:0 error:&parsingError];
    if (parsingError) {
        return [NSString stringWithFormat:@"Eval result JSON is invalid:%@\n%@",
                         [parsingError localizedDescription], jsonString];
    } else if (![errorDictionary isKindOfClass:[NSDictionary class]]) {
        return [NSString stringWithFormat:@"Eval result is not NSDictionary but %@:\n%@",
                         NSStringFromClass([errorDictionary class]), jsonString];
    } else if ([errorDictionary count] == 0) {
        return [NSString stringWithFormat:@"Eval result is an empty dictionary:\n%@", jsonString];
    }
    NSString *parsedRetval = @"";
    // errorDictionary is a JSONized JS Error object: all properties
    // which JavaScriptCore has put in it.
    for (NSString *frameKey in errorDictionary) {
        id frameValue = errorDictionary[frameKey];
        bool isFrameKeyParsed = NO; // was the current frame key already parsed?
        /*
     Output lines are formatted as "key : value" per key, with exception of any
     value which contains a multiline string. Most prominently the "stack" key.
     Remember this is what JavaScriptCore gave us, not something we created
     ourselves. Such value will be splitted and formatted to multiple
     "key : value" lines.
    */
        // need to check the value type. JSONKit may have given us a different type,
        // like NSNumber or NSNull.
        if ([frameValue isKindOfClass:[NSString class]]) {
            NSArray *frameValueMultiline = [frameValue componentsSeparatedByString:@"\n"];
            if ([frameValueMultiline count] > 1) {
                NSUInteger lineNumber = 0;
                for (NSString *line in frameValueMultiline) {
                    parsedRetval = [parsedRetval stringByAppendingFormat:@"%@ #%lu: %@\n",
                                                 frameKey, (unsigned long)++lineNumber, line];
                }
                isFrameKeyParsed = YES;
            }
        }
        // the above multiline check didn't kick in
        // fall back to default single line formatting
        if (!isFrameKeyParsed) {
            parsedRetval = [parsedRetval stringByAppendingFormat:@"%@ : %@\n",
                                         frameKey, frameValue];
        }
    }
    return parsedRetval;
}
@end
