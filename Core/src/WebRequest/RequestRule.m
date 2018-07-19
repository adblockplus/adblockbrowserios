
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

#import "RequestRule.h"
#import "WebRequestEventDispatcher.h"
#import "NSArray+IterateAsyncSeries.h"
#import "NSString+PatternMatching.h"
#import <KittCore/KittCore-Swift.h>

@interface RequestRule () {
    NSArray *_conditions;
    NSArray *_actions;
    WebRequestDetails *_details; // remember the details we told being a match for
}
@end

@implementation RequestRule

- (id)initWithConditions:(NSArray *)conditions actions:(NSArray *)actions originExtension:(BrowserExtension *)extension
{
    if (self = [super init]) {
        _conditions = conditions;
        _actions = actions;
        _originExtension = extension;
        return self;
    }
    return nil;
}

- (BOOL)matchesDetails:(WebRequestDetails *)details
{
    // no conditions => no match
    // I found no documented evidence in chrome.declarativeWebRequest that
    // the filtering is a whitelist, but it seems to me as more reasonable
    // behavior, contrary to blacklist (i.e. no condition => match all)
    if (!_conditions || [_conditions count] == 0) {
        return NO;
    }
    for (id<RuleConditionMatchable> cond in _conditions) {
        if (![cond matchesDetails:details]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)containsActionWithCallbackId:(NSString *)callbackId
{
    for (id<AbstractRuleAction> action in _actions) {
        if ([action isKindOfClass:[AbstractRuleActionBlockable class]]) {
            AbstractRuleActionBlockable *actionBlockable = (AbstractRuleActionBlockable *)action;
            if ([actionBlockable.listenerCallback.callbackId isEqualToString:callbackId]) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)applyToResponse:(BlockingResponse *)response
            withDetails:(WebRequestDetails *)details
        completionBlock:(void (^)(void))completionBlock
{
    [_actions iterateSeriesWithBlock:^(id element, void (^continueBlock)(void)) {
        id<AbstractRuleAction> action = (id<AbstractRuleAction>)element;
        [action applyToDetails:details
             modifyingResponse:response
               completionBlock:continueBlock];
    }
        completionBlock:^{
            completionBlock();
        }];
}

- (NSString *)debugDescription
{
    NSMutableString *descr = [NSMutableString stringWithString:@"["];
    BOOL first = YES;
    for (id cond in _conditions) {
        [descr appendString:[NSString stringWithFormat:@"%@%@", first ? @"" : @"&&", [cond debugDescription]]];
        first = NO;
    }
    [descr appendString:@"] -> ["];
    first = YES;
    for (id action in _actions) {
        [descr appendString:[NSString stringWithFormat:@"%@%@", first ? @"" : @"&&", [action debugDescription]]];
        first = NO;
    }
    [descr appendString:@"]"];
    return descr;
}

@end
