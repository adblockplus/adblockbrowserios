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

#import "NSObject+AddWebRequestRules.h"

#import "WebRequestEventDispatcher.h"
#import "RuleCondition_UrlFilter.h"

#import <KittCore/KittCore-Swift.h>

@implementation NSObject (AddWebRequestRules)

+ (void)addWebRequestRules:(NSArray *__nullable)rules
             fromExtension:(BrowserExtension *__nullable)extension
       toRuleActionFactory:(RuleActionFactory *)factory;
{
    // Parse set of rules compliant with chrome.declarativeWebRequest
    // Each rule can have multiple matching conditions and multiple actions
    for (NSDictionary *rule in rules) {
        NSArray *conditions = [rule objectForKey:@"conditions"];
        NSMutableArray *resultConditions = [NSMutableArray arrayWithCapacity:[conditions count]];
        for (NSDictionary *condition in conditions) {
            // RequestMatcher objects
            // at the moment only "url" matcher is handled
            NSDictionary *urlFilter = [condition objectForKey:@"url"];
            // "url" matcher is applicable to any request stage (event type)
            // see https://developer.chrome.com/extensions/declarativeWebRequest
            // "Evaluation of conditions and actions"
            // so RuleCondition doesn't need specific type
            [resultConditions addObject:[[RuleCondition_UrlFilter alloc] initWithJSConfigObject:urlFilter
                                                                                   forEventType:CallbackEvent_Undefined]];
        }
        NSArray *actions = [rule objectForKey:@"actions"];
        NSMutableArray *resultActions = [NSMutableArray arrayWithCapacity:[actions count]];
        for (NSDictionary *action in actions) {
            id<AbstractRuleAction> ruleAction = [factory ruleActionWithProperties:action
                                                                  originExtension:extension];
            if (ruleAction) {
                [resultActions addObject:ruleAction];
            }
        }
        if ([resultConditions count] && [resultActions count]) {
            [[WebRequestEventDispatcher sharedInstance] addRequestRule:
                                                            [[RequestRule alloc] initWithConditions:resultConditions
                                                                                            actions:resultActions
                                                                                    originExtension:extension]];
        }
    }
}

@end
