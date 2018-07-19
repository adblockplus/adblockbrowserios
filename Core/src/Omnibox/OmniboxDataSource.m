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

#import "OmniboxDataSource.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@interface OmniboxDataSource ()

@property (nonatomic, strong) void (^resultBlock)(NSDictionary *items);
@property (nonatomic, strong) NSDictionary *providers;
@property (nonatomic, strong) NSMutableArray *runningProviders;
@property (strong) NSMutableDictionary *results;

@end

@implementation OmniboxDataSource

- (id)init
{
    if (self = [super init]) {
        _runningProviders = [NSMutableArray new];
        _results = [NSMutableDictionary new];
        return self;
    }
    return nil;
}

- (void)addProvider:(AbstractSuggestionProvider *)provider
{
    if (_providers) {
        NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithDictionary:_providers];
        temp[@(provider.providerId)] = provider;
        _providers = [NSDictionary dictionaryWithDictionary:temp];
    } else {
        _providers = @{ @(provider.providerId) : provider };
    }
}

- (void)setProviderType:(SuggestionProviderType)type enabled:(BOOL)enabled
{
    AbstractSuggestionProvider *provider = _providers[@(type)];
    if (provider) {
        provider.enabled = enabled;
    }
}

- (BOOL)isProviderEnabledForType:(SuggestionProviderType)type
{
    AbstractSuggestionProvider *provider = _providers[@(type)];
    return provider ? provider.enabled : NO;
}

- (NSArray *)installedProviders
{
    return [_providers allKeys];
}

- (void)setDefaultSessionManager:(id)sessionManager
{
    SessionManager *manager;
    if ([sessionManager isKindOfClass:[SessionManager class]]) {
        manager = sessionManager;
    } else {
        manager = SessionManager.defaultSessionManager;
    }

    for (id provider in self.providers.allValues) {
        if ([provider respondsToSelector:@selector(setSessionManager:)]) {
            [provider setSessionManager:manager];
        }
    }
}

- (NSUInteger)minimumCharactersToTrigger
{
    return 1; // Safari behavior: start searching on first character
}

- (void)itemsFor:(NSString *)query result:(void (^)(NSDictionary *items))resultBlock
{
    if (!resultBlock) {
        LogError(@"Omnibox datasource given no result block");
        // without result block, we can't return the results
        return;
    }
    @synchronized(_results)
    {
        [_results removeAllObjects];
        _resultBlock = resultBlock;
    }
    // execute the providers
    [_providers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        AbstractSuggestionProvider *provider = obj;
        if (provider.enabled) {
            [self->_runningProviders addObject:provider];
            [provider startAsyncFindingForQuery:query];
        }
    }];
}

#pragma mark SuggestionProviderDelegate

- (void)provider:(AbstractSuggestionProvider *)provider suggestionsReady:(NSArray *)suggestions
{
    [_runningProviders removeObject:provider];
    // make a copy of the array and sort it
    if (![suggestions count] && [_runningProviders count]) {
        // no results returned yet and there are still providers running
        // do nothing, don't call the result block
        return;
    }
    NSMutableArray *resultCopy = [NSMutableArray arrayWithArray:suggestions];
    [resultCopy sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        OmniboxSuggestion *s1 = (OmniboxSuggestion *)obj1;
        OmniboxSuggestion *s2 = (OmniboxSuggestion *)obj2;
        if (s1.providerId > s2.providerId) {
            return NSOrderedAscending;
        } else if (s1.providerId < s2.providerId) {
            return NSOrderedDescending;
        } else if (s1.rank > s2.rank) {
            return NSOrderedAscending;
        } else if (s1.rank < s2.rank) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    @synchronized(_results)
    {
        [_results setObject:resultCopy forKey:@(provider.providerId)];
    }
    // send the sorted array to view
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_resultBlock(self->_results);
    });
}

#pragma mark OmniboxDataSourceMutable

- (void)deleteSuggestionsInIntervalBack:(NSTimeInterval)interval
{
    [self dispatchSelectorToProviders:_cmd withObject:[NSNumber numberWithDouble:interval]];
}

- (void)dispatchSelectorToProviders:(SEL)selector withObject:(id)object
{
    [_providers enumerateKeysAndObjectsUsingBlock:^(id type, id provider, BOOL *stop) {
        if ([provider respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [provider performSelector:selector
                           withObject:object];
#pragma clang diagnostic pop
        }
    }];
}

@end
