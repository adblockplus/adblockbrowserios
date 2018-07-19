//
//  UIBAlertView.h
//  UIBAlertView
//
//  Created by Stav Ashuri on 1/31/13.
//  Copyright (c) 2013 Stav Ashuri. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^AlertDismissedHandler) (NSInteger selectedIndex, BOOL didCancel);

@interface UIBAlertView : NSObject

// This method can be seen from Swift
- (id)initWithTitle:(NSString *)aTitle
            message:(NSString *)aMessage
  cancelButtonTitle:(NSString *)aCancelTitle
   otherButtonArray:(NSArray *)otherTitles;

- (id)initWithTitle:(NSString *)aTitle
            message:(NSString *)aMessage
  cancelButtonTitle:(NSString *)aCancelTitle
  otherButtonTitles:(NSString *)otherTitles,...NS_REQUIRES_NIL_TERMINATION;
- (void)showWithDismissHandler:(AlertDismissedHandler)handler;

#pragma - Reimplemented UIAlertView
@property(nonatomic,assign) UIAlertViewStyle alertViewStyle NS_AVAILABLE_IOS(5_0);
@property(nonatomic) NSInteger cancelButtonIndex;
@property(nonatomic, readonly) NSInteger firstOtherButtonIndex;
- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex NS_AVAILABLE_IOS(5_0);
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;

@end