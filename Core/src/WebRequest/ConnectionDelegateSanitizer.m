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

#import "ConnectionDelegateSanitizer.h"
#import <KittCore/KittCore-Swift.h>

@interface ConnectionDelegateSanitizer ()

@property (weak) ProtocolHandler *protocolHandler;

@end

@implementation ConnectionDelegateSanitizer

- (instancetype)initWithForwardHandler:(ProtocolHandler *)handler
{
    self = [super init];
    if (self) {
        _protocolHandler = handler;
    }
    return self;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [_protocolHandler connectionDidFinishLoading:connection];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [_protocolHandler connection:connection didFailWithError:error];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [_protocolHandler connection:connection willSendRequestForAuthenticationChallenge:challenge];
}

- (nullable NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(nullable NSURLResponse *)response
{
    return [_protocolHandler connection:connection willSendRequest:request redirectResponse:response];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (response == nil) {
        // Connection with nil response is corrupt.
        // We could not execute any activity in didReceiveResponse.
        // We could let it keep running, but an "Protocol event ordering violation" occurs most probably.
        // Stopping/cancelling the connection is the safest strategy.
        [_protocolHandler cancelLoading];
        return;
    }
    [_protocolHandler connection:connection didReceiveResponse:response];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_protocolHandler connection:connection didReceiveData:data];
}

@end
