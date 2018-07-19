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
#import "WebViewProtocolDelegate.h"

/**
 * A facade over the various URL connection authentication methods,
 * possibly requiring user feedback via alert view.
 */
@interface AuthenticationResult : NSObject <AuthenticationResultProtocol>

- (nonnull instancetype)initWithLevel:(RequestSecurityLevel)level host:(nonnull NSString *)host;
@property (nonatomic, readonly, nonnull) NSString *host;
@property (nonatomic, readonly) RequestSecurityLevel level;
@property (nonatomic, copy, nullable) NSString *EVOrgName;

@end

typedef void (^AuthenticationResultHandler)(id<AuthenticationResultProtocol> __nonnull result);

@interface ConnectionAuthenticator : NSObject

/**
 @param challenge to authenticate.
 @param fallbackHandler called when authenticator is incapable of handling the challenge
 @return nothing. Feedback is given via calls to challenge.sender protocol
 as required by willSendRequestForAuthenticationChallenge
*/
- (void)authenticateChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
                resultHandler:(nonnull AuthenticationResultHandler)resultHandler;

@end
