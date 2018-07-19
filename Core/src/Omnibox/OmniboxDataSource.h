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

@class AbstractSuggestionProvider;

@protocol SuggestionProviderDelegate <NSObject>
/// Event of completed suggestion retrieval
/// @param provider the provider returning the suggestions
/// @param suggestions array of Suggestion objects
- (void)provider:(AbstractSuggestionProvider *)provider suggestionsReady:(NSArray *)suggestions;
@end

@class BrowserHistoryManager;

/// Data source for omnibox searching
/// @implements ACEAutocompleteDataSource
/// @see ACEAutocompleteBar
@interface OmniboxDataSource : NSObject <SuggestionProviderDelegate>

/// Define enumeration ordinals explicitly. C(++(11)) standard ensures that,
/// @see http://stackoverflow.com/questions/18752430/does-the-actual-value-of-a-enum-class-enumeration-remain-constant-invariant
/// but we want to express that it's being used to sort the results in presentation
/// layer and that the order matters (which it normally doesn't with C enums)
typedef enum {
    SuggestionProviderHistory = 0,
    SuggestionProviderGoogle = 1,
    SuggestionProviderDuckDuckGo = 2,
    SuggestionProviderBaidu = 3,
    SuggestionProviderFindInPage = 4
} SuggestionProviderType;

- (void)addProvider:(AbstractSuggestionProvider *)provider;

 ///Providers are enabled by default. Disabling them means they still run
 ///but are not getting any tasks, hence do not make any requests.
- (void)setProviderType:(SuggestionProviderType)type enabled:(BOOL)enabled;
- (BOOL)isProviderEnabledForType:(SuggestionProviderType)type;

- (NSArray *)installedProviders;

- (NSUInteger)minimumCharactersToTrigger;

- (void)itemsFor:(NSString *)query result:(void (^)(NSDictionary *items))resultBlock;

- (void)setDefaultSessionManager:(id)sessionManager;

@end
