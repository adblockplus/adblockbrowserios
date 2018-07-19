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

#import "ConnectionAuthenticator.h"
#import "Settings.h"
#import "UIBAlertView.h"
#import "ObjCLogger.h"

@interface AuthenticationResult ()

@property (nonatomic, readwrite) RequestSecurityLevel level;
@property (nonatomic, readwrite) NSString *host;

@end

@implementation AuthenticationResult

- (nonnull instancetype)initWithLevel:(RequestSecurityLevel)level host:(nonnull NSString *)host
{
    if (self = [super init]) {
        self.level = level;
        self.host = host;
    }
    return self;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"Level %ld org %@", (unsigned long)self.level, self.EVOrgName];
}

@end

@interface ConnectionAuthenticator ()

@end

static NSDictionary *_authMethods;

typedef void (^FallbackHandler)(void);
typedef void (^AlertDismissHandler)(NSInteger, BOOL);
typedef void (^AuthenticationHandler)(ConnectionAuthenticator *, NSURLAuthenticationChallenge *, AuthenticationResultHandler);

@implementation ConnectionAuthenticator

+ (void)initialize
{
    _authMethods = @{
                     NSURLAuthenticationMethodServerTrust: ^(typeof(self) this,
                                                             NSURLAuthenticationChallenge *challenge,
                                                             AuthenticationResultHandler handler) {
                         [this authenticateSSLChallenge:challenge
                                          resultHandler:handler];
                     },
                     NSURLAuthenticationMethodHTTPBasic  : ^(typeof(self) this,
                                                             NSURLAuthenticationChallenge *challenge,
                                                             AuthenticationResultHandler handler) {
                         [this authenticateBasicChallenge:challenge resultHandler:handler];
                     }
                     };
}

- (void)authenticateChallenge:(NSURLAuthenticationChallenge *)challenge
                resultHandler:(AuthenticationResultHandler)resultHandler
{
    NSString *authenticationMethod = challenge.protectionSpace.authenticationMethod;
    AuthenticationHandler authHandler = _authMethods[authenticationMethod];
    if (!authHandler) {
        LogError(@"Unimplemented auth method %@", authenticationMethod);
        resultHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelUnknown host:challenge.protectionSpace.host]);
        return;
    }
    authHandler(self, challenge, resultHandler);
}

#pragma mark - Handlers

- (void)authenticateSSLChallenge:(NSURLAuthenticationChallenge *)challenge
                   resultHandler:(AuthenticationResultHandler)resultHandler
{
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    void (^acceptHandler)(AuthenticationResult *result) = ^(AuthenticationResult *result) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
        [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
        resultHandler(result);
    };

    SecTrustResultType secresult = kSecTrustResultInvalid;
    if (SecTrustEvaluate(serverTrust, &secresult) != errSecSuccess) {
        resultHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelUnknown host:challenge.protectionSpace.host]);
        return;
    }

    if (secresult == kSecTrustResultUnspecified || // The OS trusts this certificate implicitly.
        secresult == kSecTrustResultProceed) { // The user explicitly told the OS to trust it, previously in session or in configuration
        // default result
        AuthenticationResult *result = [[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelTrustImplicit host:challenge.protectionSpace.host];
        // Verify potential Extended Validation
        CFDictionaryRef cfCertProps = SecTrustCopyResult(serverTrust);
        NSDictionary *certProps = (__bridge NSDictionary *)(cfCertProps);
        NSNumber *maybeEV = certProps[(__bridge NSString *)kSecTrustExtendedValidation];
        if (maybeEV && maybeEV.boolValue) {
            NSString *maybeEVOrg = certProps[(__bridge NSString *)kSecTrustOrganizationName];
            if ([maybeEVOrg length] > 0) {
                result = [[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelTrustExtended host:challenge.protectionSpace.host];
                result.EVOrgName = maybeEVOrg;
            }
        }
        CFRelease(cfCertProps);
        acceptHandler(result);
        return;
    }
    if (secresult == kSecTrustResultRecoverableTrustFailure) {
        // user overridable failure. Valid but misconfigured cert falls here.
        // challenge.protectionSpace.host not used now
        NSString *message = BundleLocalizedString(@"The site's security certificate is not trusted. Do you want to proceed?", @"HTTPS server verification");
        UIBAlertView *confirmationPopup = [[UIBAlertView alloc] initWithTitle:BundleLocalizedString(@"Warning", @"HTTPS server verification")
                                                                      message:message
                                                            cancelButtonTitle:BundleLocalizedString(@"Cancel", @"HTTPS server verification")
                                                            otherButtonTitles:BundleLocalizedString(@"Proceed", @"HTTPS server verification"), nil];
        [self dispatchAlert:confirmationPopup
            withDismissHandler:^(NSInteger selectedIndex, BOOL didCancel) {
                if (didCancel) {
                    // Cancel produces kCFURLErrorUserCancelledAuthentication
                    // which is ignored in UIWebViewDelegate.
                    // Safari does not display any affirmative error message either
                    [challenge.sender cancelAuthenticationChallenge:challenge];
                    acceptHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelUntrusted host:challenge.protectionSpace.host]);
                } else {
                    acceptHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelTrustForced host:challenge.protectionSpace.host]);
                }
            }];
        return;
    }
    // @TODO more SecTrustResultType handling
    // http://www.opensource.apple.com/source/libsecurity_keychain/libsecurity_keychain-34101/lib/SecTrust.h
    resultHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelUnknown host:challenge.protectionSpace.host]);
}

- (void)authenticateBasicChallenge:(NSURLAuthenticationChallenge *)challenge
                     resultHandler:(AuthenticationResultHandler)resultHandler
{
    /*
   Failure limitation is primarily on behalf of the server IMHO. Mobile Safari doesn't
   seem to impose any limit on its own. The fact that server may not have any retry
   limit should not be an argument for making up on client side.
   */
    NSString *username = nil;
    NSURLCredential *proposedCredential = challenge.proposedCredential;
    if (proposedCredential) {
        // Fragile, but cannot do better at the moment. It is unknown whether previousFailureCount will get
        // reset when success happens. Hence we don't know what arrives here when credentials get changed
        // on the server during authenticated session.
        // @todo simulate password change on the server and test
        if ([proposedCredential hasPassword] && challenge.previousFailureCount == 0) {
            // initial success and is complete credential, can be used as-is
            [challenge.sender useCredential:proposedCredential forAuthenticationChallenge:challenge];
        } else {
            // Either it already failed (and trying again) or the proposed credential is incomplete.
            // Give user a chance to try again
            username = proposedCredential.user;
        }
    }
    // wording follows iOS7 Mobile Safari
    UIBAlertView *credentialPopup = [[UIBAlertView alloc] initWithTitle:BundleLocalizedString(@"Authentication Required", @"User/pwd server verification")
                                                                message:challenge.protectionSpace.host
                                                      cancelButtonTitle:BundleLocalizedString(@"Cancel", @"User/pwd server verification")
                                                      otherButtonTitles:BundleLocalizedString(@"Log In", @"User/pwd server verification"), nil];
    credentialPopup.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    UITextField *usernameField = [credentialPopup textFieldAtIndex:0];
    usernameField.placeholder = BundleLocalizedString(@"Username", @"User/pwd server verification");
    usernameField.text = username;
    UITextField *passwordField = [credentialPopup textFieldAtIndex:1];
    passwordField.placeholder = BundleLocalizedString(@"Password", @"User/pwd server verification");
    [self dispatchAlert:credentialPopup
        withDismissHandler:^(NSInteger selectedIndex, BOOL didCancel) {
            if (didCancel) {
                // continuing with fallback is the right thing to do for basic authentication
                // because it will result in the server displaying auth failure page
                resultHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelUnknown host:challenge.protectionSpace.host]);
            } else {
                // NSURLCredential is designed as immutable, hence create a new one
                NSURLCredential *cred = [NSURLCredential credentialWithUser:usernameField.text
                                                                   password:passwordField.text
                                                                persistence:NSURLCredentialPersistenceForSession];
                // remember for session
                [[NSURLCredentialStorage sharedCredentialStorage] setCredential:cred
                                                             forProtectionSpace:challenge.protectionSpace];
                [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
                resultHandler([[AuthenticationResult alloc] initWithLevel:RequestSecurityLevelInsecure host:challenge.protectionSpace.host]);
            }
        }];
}

#pragma mark - Private utility

- (void)dispatchAlert:(UIBAlertView *)alertView
    withDismissHandler:(AlertDismissHandler)dismissHandler
{
    // Block-based UIAlertView implementation is way more convenient here.
    // Delegate-based default implementation would require saving away challenge
    // object as well as introspecting the UITextFields again
    dispatch_async(dispatch_get_main_queue(), ^{
        [alertView showWithDismissHandler:^(NSInteger selectedIndex, BOOL didCancel) {
            dismissHandler(selectedIndex, didCancel);
        }];
    });
}

@end
