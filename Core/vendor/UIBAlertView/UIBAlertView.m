//
//  UIBAlertView.m
//  UIBAlertView
//
//  Created by Stav Ashuri on 1/31/13.
//  Copyright (c) 2013 Stav Ashuri. All rights reserved.
//

#import "UIBAlertView.h"

@interface UIBAlertView() <UIAlertViewDelegate>

@property (strong, nonatomic) UIBAlertView *strongAlertReference;

@property (copy) AlertDismissedHandler activeDismissHandler;

@property (strong, nonatomic) NSString *activeTitle;
@property (strong, nonatomic) NSString *activeMessage;
@property (strong, nonatomic) NSString *activeCancelTitle;
@property (strong, nonatomic) NSString *activeOtherTitles;
@property (strong, nonatomic) UIAlertView *activeAlert;
@property (strong, nonatomic) NSMutableArray *otherButtonIndexes;
@end

@implementation UIBAlertView

#pragma mark - Public (Initialization)

- (id)initWithTitle:(NSString *)aTitle
            message:(NSString *)aMessage
  cancelButtonTitle:(NSString *)aCancelTitle
   otherButtonArray:(NSArray *)otherTitles
{
  if (self = [super init]) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:self cancelButtonTitle:aCancelTitle otherButtonTitles:nil];
    if (otherTitles != nil) {
      _otherButtonIndexes = [NSMutableArray arrayWithCapacity:[otherTitles count]];
      for (NSString *title in otherTitles) {
        [_otherButtonIndexes addObject:@([alert addButtonWithTitle:title])];
      }
    }
    self.activeAlert = alert;
  }
  return self;
}

- (id)initWithTitle:(NSString *)aTitle
            message:(NSString *)aMessage
  cancelButtonTitle:(NSString *)aCancelTitle
  otherButtonTitles:(NSString *)otherTitles,...
{
  if (self = [super init]) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:aTitle message:aMessage delegate:self cancelButtonTitle:aCancelTitle otherButtonTitles:otherTitles, nil];
    if (otherTitles != nil) {
      va_list args;
      va_start(args, otherTitles);
      NSString * title = nil;
      while((title = va_arg(args,NSString*))) {
        [_otherButtonIndexes addObject:@([alert addButtonWithTitle:title])];
      }
      va_end(args);
    }
    self.activeAlert = alert;
  }
  return self;
}

#pragma mark - Public (Functionality)

- (void)showWithDismissHandler:(AlertDismissedHandler)handler {
  self.activeDismissHandler = handler;
  self.strongAlertReference = self;
  [self.activeAlert show];
}

#pragma mark - Reimplemented UIAlertView

-(void)setAlertViewStyle:(UIAlertViewStyle)alertViewStyle {
  self.activeAlert.alertViewStyle = alertViewStyle;
}

-(UIAlertViewStyle)alertViewStyle {
  return self.activeAlert.alertViewStyle;
}

- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex {
  return [self.activeAlert textFieldAtIndex:textFieldIndex];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
  [self.activeAlert dismissWithClickedButtonIndex:buttonIndex animated:animated];
}

-(NSInteger)cancelButtonIndex {
  return self.activeAlert.cancelButtonIndex;
}

-(void)setCancelButtonIndex:(NSInteger)cancelButtonIndex {
  self.activeAlert.cancelButtonIndex = cancelButtonIndex;
}

-(NSInteger)firstOtherButtonIndex {
  return _otherButtonIndexes ? [_otherButtonIndexes[0] integerValue] : -1;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (self.activeDismissHandler) {
    self.activeDismissHandler(buttonIndex,buttonIndex == alertView.cancelButtonIndex);
  }
  self.strongAlertReference = nil;
}

-(void)willPresentAlertView:(UIAlertView *)alertView {
}
@end
