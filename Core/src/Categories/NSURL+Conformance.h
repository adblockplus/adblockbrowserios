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

@interface NSURL (Conformance)

// Referrers are supposed to be just path, no query/params/fragment. Unfortunately
// full URLs with query were observed too (e.g. latimes.com). Looks like UIWebView glitch.
// Let's normalize the URL preemptively.
- (NSString *)conformantRefererString;

// Idea taken from
// http://stackoverflow.com/questions/12310258/reliable-way-to-compare-two-nsurl-or-one-nsurl-and-an-nsstring
// but corrected and improved significantly
- (BOOL)isRFC2616EquivalentOf:(NSURL *)aURL;

// URL is such that is of no interest for the user and should not be displayed
- (BOOL)shouldBeHidden;

@end
