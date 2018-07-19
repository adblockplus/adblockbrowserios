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

#import "RuleConditionGroup.h"

@interface RuleConditionGroup () {
  RuleConditionGroupOperator _operator;
  NSMutableArray *_ruleConditions;
}

@end

@implementation RuleConditionGroup

-(instancetype)initWithGroupOperator:(RuleConditionGroupOperator)operator
{
  if(self = [super init]) {
    _operator = operator;
    _ruleConditions = [NSMutableArray new];
  }
  return self;
}

-(void)addRuleCondition:(id<RuleConditionMatchable>)ruleCondition {
  // This looks like a stupid redundant wrapper but it ensures type safety of the elements
  [_ruleConditions addObject:ruleCondition];
}


#pragma mark - RuleConditionMatchable

-(BOOL)matchesDetails:(WebRequestDetails *)details {
  for(id<RuleConditionMatchable> condition in _ruleConditions) {
    switch(_operator) {
      case RuleConditionGroup_Or:
        if([condition matchesDetails:details]) {
          return YES;
        }
        break;
      case RuleConditionGroup_And:
        if(![condition matchesDetails:details]) {
          return NO;
        }
        break;
    }
  }
  switch(_operator) {
    case RuleConditionGroup_Or: return NO; break;
    case RuleConditionGroup_And: return YES; break;
  }
}

-(NSString *)debugDescription
{
  NSString *operator = nil;
  switch(_operator) {
    case RuleConditionGroup_Or: operator = @"OR"; break;
    case RuleConditionGroup_And: operator = @"AND"; break;
  }
  NSMutableString *descr = [NSMutableString stringWithString:@"("];
  for(id condition in _ruleConditions) {
    [descr appendFormat:@" %@ (%@)", operator, [condition debugDescription]];
  }
  [descr appendString:@")"];
  return descr;
}

@end
