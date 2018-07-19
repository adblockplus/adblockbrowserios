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

#import "PasteboardChecker.h"
#import "BridgeSwitchboard.h"
#import "NSString+PatternMatching.h"
#import "NSURL+Conformance.h"
#import "Settings.h"

static NSString *const kPasteboardCountKey = @"PasteboardLastCount";
static NSString *const kPasteboardLastURL = @"PasteboardLastURL";
static NSArray *kAllowedExternalSchemes;

@implementation PasteboardChecker

+ (void)checkPasteboard:(UIPasteboard *_Nonnull)pasteboard
        URLOpeningBlock:(void (^_Nonnull)(NSURL *_Nonnull url))block
{
    NSInteger newCount = pasteboard.changeCount;
    // return 0 if the key doesn't exist which is not really a detection of existence
    // but is fine in this case because 0 changeCount means no changes too.
    NSInteger oldCount = [[NSUserDefaults standardUserDefaults] integerForKey:kPasteboardCountKey];
    if (newCount == oldCount) {
        // no new paste
        return;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:newCount forKey:kPasteboardCountKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // first check native NSURL
    NSURL *newURL = pasteboard.URL;
    if (!newURL) {
        // fallback to validate string as URL
        newURL = [pasteboard.string URLValue];
    }
    if (!(newURL && [Settings allowsScheme:newURL.scheme])) {
        // URL not detected or not an acceptable scheme
        return;
    }
    NSURL *oldURL = [[NSUserDefaults standardUserDefaults] URLForKey:kPasteboardLastURL];
    if ([newURL isRFC2616EquivalentOf:oldURL]) {
        // the same URL pasted
        return;
    }
    [[NSUserDefaults standardUserDefaults] setURL:newURL forKey:kPasteboardLastURL];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    block(newURL);
}

@end
