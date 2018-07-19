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
#import "RequestRule.h"

NS_ASSUME_NONNULL_BEGIN

/**
 
 Group of conditions which implements the same interface as a single condition.
 Evaluates the group by given logical operator.
 */

typedef NS_ENUM(NSUInteger, RuleConditionGroupOperator) {
  RuleConditionGroup_And,
  RuleConditionGroup_Or
};

@interface RuleConditionGroup : NSObject <RuleConditionMatchable>

-(instancetype)initWithGroupOperator:(RuleConditionGroupOperator)operator;
-(void)addRuleCondition:(id<RuleConditionMatchable>)ruleCondition;

@end


NS_ASSUME_NONNULL_END
