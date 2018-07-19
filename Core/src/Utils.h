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
#import <KittCore/BridgeEnums.h>

/**
 In process of deallocation, WebKit2 calls all still opened JS evaluation callbacks with
 an error which announces the instance invalidation to the callback handlers. Unfortunately,
 these callback blocks are already deallocated. It is not known whether it's a general bug
 of WebKit, of WKWebView, or just some weird corner case of ObjC-Swift bridging. In any case,
 the callback blocks need to survive, i.e. be owned by someone else besides the WKWebView instance.
 This simple reference holder does the trick.
 */
@interface CallbackBox : NSObject
@property id callback;
@end

@interface Utils : NSObject

/**
 create NSError with domain "Kitt" and a specified localized message
 @param error ptr-to-ptr of object to construct
 @param wrappedErr the original error due to which this one is being created. Can be nil.
 @param message the error message formatted. Can be nil if wrappedErr is not.
 @return FALSE if error parameter is nil or both wrappedErr and message is nil
 Must be a pointer to pointer to NSError (which can be nil)
 @note Taking NSError** is a standard Objective-C construct.
 This function isolated would be more understandable if taking just NSError*
 (it's gonna be replaced by a new instance anyway) but the flow of passing
 error parameter would be broken
 */
+ (BOOL)error:(NSError *__autoreleasing *)error wrapping:(NSError *)wrappedErr message:(NSString *)fmt, ...;

+ (NSError *)errorForWrappingError:(NSError *)wrappingError message:(NSString *)message;

/**
 @param err the error to inspect for messages. Can be nil
 Inspect the error itself and underlying error too, if there is any
 @param title to give to the alert
 @param delegate to give to the alert. Can be nil.
 @return UIAlertView with a title and message combined from given error
 */
+ (UIAlertView *)alertViewWithError:(NSError *)err title:(NSString *)title delegate:(id<UIAlertViewDelegate>)delegate;

/// @return description, or wrapped error description (if there is one)
/// or both concatenated
+ (NSString *)localizedMessageOfError:(NSError *)err;

/// @param strings the array of regular expression patterns
/// @param error [out] not nil if some pattern was not parseable
/// @return array of NSRegularExpression compiled from the strings
+ (NSArray *)arrayOfRegexesFromArrayOfChromeGlobStrings:(NSArray *)strings
                                                  error:(NSError **)error;

/**
 Tries to match a string against array of regular expressions
 @param regexes array of NSRegularExpression
 @param matchString the string to match with the patterns
 @return an index of the first matched pattern
 @return NSNotFound if no match
 */
+ (NSUInteger)indexOfMatchInRegexArray:(NSArray *)regexes
                             forString:(NSString *)matchString;

+ (NSString *)callbackOriginDescription:(CallbackOriginType)origin;

/// returns CFBundleName from main bundle
+ (NSString *)applicationName;

/**
 The test case:
 A legacy Cocoa ObjC code, having a newly Swift-ified interfaces, with Swift-enforced nullability
 contract - parameters declared as (non-)optionals. But ObjC caller does not enforce the stated
 nullability, and Swift bridge does not check it. The contract declares best known expectation,
 not a verified state. So in case of highly complex legacy ObjC code (URL loading, UI delegates),
 ObjC may attempt to call with a nil parameter where Swift interface prescribes non-optional. Due
 to strict typesafety of Swift, the nilness is not verifiable in Swift. Compiler will straight refuse
 to compile a nilness check on nonoptional type. If tricked (supposedly) through casting to optional
 ancestor type, the check is observably optimized away.
 */
+ (BOOL)isObjectReferenceNil:(id)reference;

@end
