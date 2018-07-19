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

#import "RuleCondition_UrlFilter.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

typedef NSString*(^UrlPartProducerBlock)(NSURL *);
typedef BOOL(^UrlPartMatcherBlock)(NSString*, NSString *);
typedef BOOL(^StaticMatcherBlock)(NSURL*, id);
typedef BOOL(^ParameterizedMatcherBlock)(NSURL *);

static NSDictionary *_staticMatcherBlocks;
static NSDictionary *_ignoredMatchersForEvent;
static NSDictionary *_regexCache;

@interface RuleCondition_UrlFilter () {
  NSString *_debugEventType;
  NSMutableArray<NSString*> *_debugMatcherDescriptions;
  NSMutableArray *_matcherBlocks;
}
@end

@implementation RuleCondition_UrlFilter

+(void)initialize {
  // per Chrome requirements
  _ignoredMatchersForEvent = @{
    @(CallbackEvent_WebNavigation_OnCreatedNavTarget): @[@"schemes", @"ports"],
    @(CallbackEvent_WebNavigation_OnBeforeNavigate): @[@"schemes",@"ports"],
    @(CallbackEvent_WebNavigation_OnCommitted): @[@"schemes",@"ports"],
    @(CallbackEvent_WebNavigation_OnCompleted): @[@"schemes", @"ports"]
  };

  NSDictionary *partProducers = @{
    @"host": ^NSString*(NSURL *url) {
      return url.host;
    },
    @"path": ^NSString*(NSURL *url) {
      return url.path;
    },
    @"query": ^NSString*(NSURL *url) {
      return url.query;
    },
    @"url": ^NSString*(NSURL *url) {
      // "without fragment identifier"
      return [url.absoluteString componentsSeparatedByString:@"#"][0];
    },
    @"originAndPath": ^NSString*(NSURL *url) {
      // "URL without query segment and fragment identifier"
      // "Port numbers are stripped if they match the default port number"
      // @todo ^^^ would mean manual recomposition of whole URL
      return [url.absoluteString componentsSeparatedByString:@"?"][0];
    }
  };

  NSDictionary *partMatchers = @{
    @"Contains": ^BOOL(NSString *whole, NSString *expr) {
      return [whole rangeOfString:expr].location != NSNotFound;
    },
    @"Equals": ^BOOL(NSString *whole, NSString *expr) {
      return [whole isEqualToString:expr];
    },
    @"Prefix": ^BOOL(NSString *whole, NSString *expr) {
      return [whole hasPrefix:expr];
    },
    @"Suffix": ^BOOL(NSString *whole, NSString *expr) {
      return [whole hasSuffix:expr];
    },
    @"Matches": ^BOOL(NSString *whole, NSString *expr) {
      // @todo how is "RE2 syntax" (Google) different from "ICU syntax" (NSRegularExpression) ???
      // https://code.google.com/p/re2/wiki/Syntax
      // http://userguide.icu-project.org/strings/regexp
      NSRegularExpression *rex = _regexCache[expr];
      if(!rex) {
        NSError *err = nil;
        rex = [NSRegularExpression regularExpressionWithPattern:expr options:0 error:&err];
        if(err) {
          LogError(@"Regex '%@' parser error %@", expr, err.localizedDescription);
          return NO;
        }
        [_regexCache setValue:rex forKey:expr];
      }
      NSRange wholeRange = NSMakeRange(0, [whole length]);
      NSRange matchRange = [rex rangeOfFirstMatchInString:whole options:0 range:wholeRange];
      return NSEqualRanges(matchRange, wholeRange);
    }
  };

  NSArray *simpleMatcherNames = @[
    @"host_Contains", @"host_Equals", @"host_Prefix", @"host_Suffix",
    @"path_Contains", @"path_Equals", @"path_Prefix", @"path_Suffix",
    @"query_Contains", @"query_Equals", @"query_Prefix", @"query_Suffix",
    @"url_Contains", @"url_Equals", @"url_Matches", @"url_Prefix", @"url_Suffix",
    @"originAndPath_Matches"];

  NSMutableDictionary *staticMatchers = [NSMutableDictionary dictionaryWithCapacity:[simpleMatcherNames count]];
  for(NSString *matcherName in simpleMatcherNames) {
    NSArray *parts = [matcherName componentsSeparatedByString:@"_"];
    UrlPartProducerBlock producerBlock = partProducers[parts[0]];
    UrlPartMatcherBlock matcherBlock = partMatchers[parts[1]];
    [staticMatchers setObject:^(NSURL *url, NSString *expr) {
      return matcherBlock( producerBlock(url), expr);
    } forKey:[parts componentsJoinedByString:@""]];
  }
  staticMatchers[@"schemes"] = ^BOOL(NSURL *url, NSArray *schemes) {
    return [schemes containsObject:url.scheme];
  };
  staticMatchers[@"ports"] = ^BOOL(NSURL *url, NSArray *portsAndRanges) {
    // [80, 443, [1000, 1200]] matches all requests on port 80, 443 and in the range 1000-1200.
    NSNumber *portObject = url.port;
    if(!portObject) {
      portObject = @(80);
    }
    for(id portOrRange in portsAndRanges) {
      if([portOrRange isKindOfClass:[NSNumber class]]) {
        if([portOrRange isEqualToNumber:portObject]) {
          return YES;
        }
      } else if([portOrRange isKindOfClass:[NSArray class]]) {
        NSArray *range = portOrRange;
        if([range count] == 2) {
          NSNumber *rangeStart = portOrRange[0];
          NSNumber *rangeEnd = portOrRange[1];
          if(rangeStart && rangeEnd
            && ([rangeStart unsignedIntegerValue] <= [portObject unsignedIntegerValue])
            && ([rangeEnd unsignedIntegerValue] >= [portObject unsignedIntegerValue])) {
            return YES;
           }
        }
      }
    }
    return NO;
  };

  // immutate
  _staticMatcherBlocks = [NSDictionary dictionaryWithDictionary:staticMatchers];
}

-(id)initWithJSConfigObject:(NSDictionary *)configObject
               forEventType:(CallbackEventType)eventType {
  if(self = [super init]) {
    _debugEventType = [BridgeCallback eventStringFor:eventType];
    _matcherBlocks = [NSMutableArray arrayWithCapacity:[configObject count]];
    _debugMatcherDescriptions = [NSMutableArray arrayWithCapacity:[configObject count]];
    [configObject enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      if([_ignoredMatchersForEvent[@(eventType)] containsObject:key]) {
        [self->_debugMatcherDescriptions addObject:[NSString stringWithFormat:@"%@ ignored", key]];
        return;
      }
      StaticMatcherBlock block = _staticMatcherBlocks[key];
      if(block) {
        [self->_debugMatcherDescriptions addObject:[NSString stringWithFormat:@"%@ ok", key]];
        [self->_matcherBlocks addObject:^BOOL(NSURL *url) {
          // parameterize StaticMatcherBlock
          return block(url, obj);
        }];
      } else {
        [self->_debugMatcherDescriptions addObject:[NSString stringWithFormat:@"%@ undefined", key]];
      }
    }];
  }
  return self;
}

#pragma - RuleConditionMatchable

-(BOOL)matchesDetails:(WebRequestDetails *)details {
  // "filter won't be invoked for events that don't pass the filter"
  // i.e. AND condition
  if([_matcherBlocks count]==0) {
    return NO;
  }
  for(ParameterizedMatcherBlock block in _matcherBlocks) {
    if(!block(details.request.URL)) {
      return NO;
    }
  }
  return YES;
}
- (NSString *)debugDescription
{
  NSMutableString *descr = [NSMutableString stringWithString:@""];
  for(NSString *matcher in _debugMatcherDescriptions) {
    [descr appendFormat:@"%@%@", (descr.length == 0 ? @" ":@","), matcher];
  }
  return [NSString stringWithFormat:@"URL %@ %@", _debugEventType, descr];
}


@end
