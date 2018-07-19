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

NS_ASSUME_NONNULL_BEGIN

@class WebRequestDetails;
@class BlockingResponse;

/// reflection of condition from declarativeWebRequest (RequestMatcher)
@protocol RuleConditionMatchable
- (BOOL)matchesDetails:(WebRequestDetails *)details;
@end

@class BrowserExtension;

@interface RequestRule : NSObject

/// composition constructor
- (id)initWithConditions:(NSArray *)conditions actions:(NSArray *)actions originExtension:(BrowserExtension *)extension;

/// @param request coming to protocol handler
/// @return YES go on with applying this rule
/// @return NO rule not applicable
- (BOOL)matchesDetails:(WebRequestDetails *)details;

/// @return true if the rule was created on behalf of BridgeCallback with specific id
- (BOOL)containsActionWithCallbackId:(NSString *)callbackId;
- (void)applyToResponse:(BlockingResponse *)response
            withDetails:(WebRequestDetails *)details
        completionBlock:(void (^)(void))completionBlock;

@property (nonatomic, readonly) BrowserExtension *originExtension;
@end

NS_ASSUME_NONNULL_END
