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

#import "Utils.h"
#import "NSString+PatternMatching.h"
#import "ObjCLogger.h"

@implementation CallbackBox
@end

@implementation Utils

static NSRegularExpression *_rexComments;
static NSRegularExpression *_rexWhitespaces;

#define ERR_DOMAIN @"Kitt"

+ (void)initialize
{
    if (self == [Utils class]) {
        NSError *err = nil;
        _rexComments = [NSRegularExpression
                        regularExpressionWithPattern:@"/\\*(.*?)\\*/|//(.*?)\r?\n|[\"']((\\[^\n]|[^\"'\n])*)[\"']"
                        options:NSRegularExpressionDotMatchesLineSeparators
                        error:&err];
        if (err) {
            LogError(@"Error compiling comments pattern: %@", [err description]);
            _rexComments = nil;
        }
        _rexWhitespaces = [NSRegularExpression
                           regularExpressionWithPattern:@"[\\s]*\r?\n[\\s]*"
                           options:0
                           error:&err];
        if (err) {
            LogError(@"Error compiling whitespaces pattern: %@", [err description]);
            _rexWhitespaces = nil;
        }
    }
}

+ (BOOL)error:(NSError *__autoreleasing *)error wrapping:(NSError *)wrappedErr message:(NSString *)fmt, ...
{
    if (!error) {
        return NO; // need error, otherwise nowhere to set the result
    }
    if (!wrappedErr && !fmt) {
        return NO; // need either error or the message, otherwise nothing to display
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    if (fmt) { // has message
        va_list fmtargs;
        va_start(fmtargs, fmt);
        [userInfo setObject:[[NSString alloc] initWithFormat:fmt arguments:fmtargs]
                     forKey:NSLocalizedDescriptionKey];
        va_end(fmtargs);
    }
    if (wrappedErr) {
        [userInfo setObject:wrappedErr forKey:NSUnderlyingErrorKey];
    }
    *error = [NSError errorWithDomain:ERR_DOMAIN code:0 userInfo:userInfo];
    // retval is largely not used but it's needed to prevent compiler whining
    // about code convention when taking pointer-to-pointer parameter
    return YES;
}

+ (NSError *)errorForWrappingError:(NSError *)wrappingError message:(NSString *)message
{
    if (!wrappingError && !message) {
        return nil; // need either error or the message, otherwise nothing to display
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    if (message) { // has message
        [userInfo setObject:message forKey:NSLocalizedDescriptionKey];
    }
    if (wrappingError) {
        [userInfo setObject:wrappingError forKey:NSUnderlyingErrorKey];
    }
    return [NSError errorWithDomain:ERR_DOMAIN code:0 userInfo:userInfo];
}

+ (UIAlertView *)alertViewWithError:(NSError *)err title:(NSString *)title delegate:(id<UIAlertViewDelegate>)delegate
{
    return [[UIAlertView alloc] initWithTitle:title
                                      message:[self localizedMessageOfError:err]
                                     delegate:delegate
                            cancelButtonTitle:@"OK"
                            otherButtonTitles:nil];
}

+ (NSString *)localizedMessageOfError:(NSError *)err
{
    NSString *locDesc = [err.userInfo objectForKey:NSLocalizedDescriptionKey];
    if (!locDesc) {
        locDesc = [err.userInfo objectForKey:@"reason"];
    }
    NSString *msg = locDesc ? [NSString stringWithString:locDesc] : @"";
    NSError *wrappedErr = [err.userInfo objectForKey:NSUnderlyingErrorKey];
    if (wrappedErr) {
        locDesc = [wrappedErr.userInfo objectForKey:NSLocalizedDescriptionKey];
        if (msg) {
            msg = [msg stringByAppendingFormat:@":\n%@", locDesc];
        } else {
            msg = locDesc;
        }
    }
    return msg;
}

+ (NSArray *)arrayOfRegexesFromArrayOfChromeGlobStrings:(NSArray *)strings
                                                  error:(NSError *__autoreleasing *)error
{
    NSMutableArray *regexes = [NSMutableArray arrayWithCapacity:[strings count]];
    for (NSString *pattern in strings) {
        NSError *parsingError = nil;
        NSRegularExpression *regex = [pattern regexFromChromeGlobPattern:pattern parsingError:&parsingError];
        if (parsingError) {
            [Utils error:error wrapping:parsingError message:@"Pattern bad format '%@'", pattern];
            break;
        }
        [regexes addObject:regex];
    }
    return regexes;
}

/**
 Tries to match a string against array of regular expressions
 @param patterns array of regular expression strings
 @param matchString the string to match with the patterns
 @return an index of the first matched pattern, or failed pattern when error occured
 @return NSNotFound if no error occured, but also no match
 */
+ (NSUInteger)indexOfMatchInRegexArray:(NSArray *)regexes
                             forString:(NSString *)matchString
{
    NSUInteger idx = 0;
    for (NSRegularExpression *rex in regexes) {
        NSUInteger matches = [rex numberOfMatchesInString:matchString
                                                  options:0
                                                    range:NSMakeRange(0, [matchString length])];
        if (matches > 0) {
            return idx;
        }
        idx++;
    }
    return NSNotFound;
}

+ (NSString *)callbackOriginDescription:(CallbackOriginType)origin
{
    switch (origin) {
        case CallbackOriginContent:
            return @"CNT";
        case CallbackOriginPopup:
            return @"POP";
        case CallbackOriginBackground:
            return @"BKG";
    }
}

+ (NSString *)applicationName
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
}

+ (BOOL)isObjectReferenceNil:(id)reference
{
    return reference == nil;
}

@end
