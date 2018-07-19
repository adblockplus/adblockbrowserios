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

#import "RuleCondition_ChromeGlob.h"
#import "NSString+PatternMatching.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@interface RuleCondition_ChromeGlob () {
  NSString *_debugOriginalGlob; // just for logging, functionally not needed
  NSRegularExpression *_rex;
}
@end

@implementation RuleCondition_ChromeGlob

-(id)initWithChromeGlob:(NSString *)glob {
  if(self = [super init]) {
    _debugOriginalGlob = glob;
    NSError *err = nil;
    _rex = [glob regexFromChromeGlobPattern:glob parsingError:&err];
    if(err) {
      LogError(@"Failed parsing chrome glob %@ : %@", glob, [err localizedDescription]);
      _rex = nil;
    }
  }
  return self;
}

#pragma - RuleConditionMatchable

-(BOOL)matchesDetails:(WebRequestDetails *)details {
  NSString *urlString = details.request.URL.absoluteString;
  NSUInteger matches = [_rex numberOfMatchesInString:urlString
                                             options:0
                                               range:NSMakeRange(0, urlString.length)];
  return (matches > 0);
}

- (NSString *)debugDescription
{
  return [NSString stringWithFormat:@"Glob %@ -> %@", _debugOriginalGlob, _rex ? _rex.pattern:@"FAIL"];
}

@end
