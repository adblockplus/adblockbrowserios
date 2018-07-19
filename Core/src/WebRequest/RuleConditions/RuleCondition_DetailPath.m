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

#import "RuleCondition_DetailPath.h"

#import <KittCore/KittCore-Swift.h>

@interface RuleCondition_DetailPath () {
  NSString *_path;
  NSString *_value;
}
@end

@implementation RuleCondition_DetailPath

-(id)initWithPath:(NSString *)path matchingValue:(NSString *)value
{
  if(self = [super init]) {
    _path = path;
    _value = value;
  }
  return self;
}

#pragma - RuleConditionMatchable

-(BOOL)matchesDetails:(WebRequestDetails *)details
{
  NSString *detailValue = [details valueForKeyPath:_path];
  return [detailValue isEqualToString:_value];
}

- (NSString *)debugDescription
{
  return [NSString stringWithFormat:@"Detail %@ ?= %@", _path, _value];
}

@end

