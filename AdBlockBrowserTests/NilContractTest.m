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

/**
 Simulation of important runtime hazard in Objc->Swift bridge. Cocoa has annotated delegate/callback
 interfaces for Swift optionality typing and checks them at compilation. But it does not verify
 the optionality at runtime, hence there are cases of delegate calls where parameters are annotated
 as nonnull at ObjC side and represented as nonoptional at Swift side, but still happen to be null.

 Known locations:
 UITextFieldDelegate.shouldChangeCharactersInRange: replacementString
 NSHTTPURLResponse.allHeaderFields
 NSURLConnectionDataDelegate.didReceiveResponse: response

 */
#import <XCTest/XCTest.h>
#import <AdblockBrowserTests-Swift.h>

@interface NilContractTest : XCTestCase

@end

@implementation NilContractTest

- (void)testNilContract
{
    NSString *aString = nil;
    XCTAssertNil(aString);
    // DO NOT DEBUG-STEP THE FOLLOWING CODE! Xcode will pretend empty string instead of nil
    // (hence failing the assert) to prevent the embarrasment of admitting that it does not
    // check the ObjC-Swift bridge annotation
    XCTAssertTrue([NilContractTestSupport testNonOptionalObjectNil:aString]);
    aString = @"abcd";
    XCTAssertNotNil(aString);
    XCTAssertFalse([NilContractTestSupport testNonOptionalObjectNil:aString]);
}

@end
