//
//  NSObject+EmptyCheck.h
//  FastPhotoTweet
//
//  Created by @peace3884 12/11/02.
//
//  A companion class for NSDictionary+XPath category

#import <Foundation/Foundation.h>

@interface NSObject (EmptyCheck)

/// @return YES if empty or NO if not empty.
- (BOOL)isEmpty;

/// @return NO if empty or YES if not empty.
- (BOOL)isNotEmpty;

@end
