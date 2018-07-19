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

#import "NSJSONSerialization+NSString.h"

@implementation NSJSONSerialization (NSString)

static const NSStringEncoding STRING_CODEC = NSUTF8StringEncoding;

+ (id)JSONObjectWithString:(NSString *)string options:(NSJSONReadingOptions)options error:(NSError *__autoreleasing *)error
{
    return [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:STRING_CODEC]
                                           options:options
                                             error:error];
}

+ (NSString *)stringWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError *__autoreleasing *)error
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj
                                                       options:opt
                                                         error:error];
    return *error ? nil : [[NSString alloc] initWithData:jsonData encoding:STRING_CODEC];
}

@end
