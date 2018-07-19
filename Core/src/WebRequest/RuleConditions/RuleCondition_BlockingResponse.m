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

#import "RuleCondition_BlockingResponse.h"

#import <KittCore/KittCore-Swift.h>

@interface RuleCondition_BlockingResponse () {
  BOOL _blockingFlag;
}

@end

@implementation RuleCondition_BlockingResponse

-(instancetype)initWithBlockingFlag:(BOOL)blocking {
  if(self = [super init]) {
    _blockingFlag = blocking;
  }
  return self;
}

#pragma - RuleConditionMatchable

-(BOOL)matchesDetails:(WebRequestDetails *)details {
  return
    (details.resourceType != WebRequestResourceTypeXhr) // not XHR, allow
    || details.isXHRAsync // XHR is async, allow
    || !_blockingFlag; // sync XHR, allow only if not blocking response
}

- (NSString *)debugDescription
{
  return [NSString stringWithFormat:@"AcceptBlocking %@", _blockingFlag ? @"yes" : @"no"];
}

@end
