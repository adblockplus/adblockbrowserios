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

#import "ShareViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>


@interface ShareViewController () {
  // The block to contain mandatory NSExtensionContext callback
  // signalling finished operation
  void(^_dismissBlock)(UIViewController *__nonnull);
}

@end

static NSArray* kAllowedSchemes;

@implementation ShareViewController

+(void)initialize {
  // The schemes this extension is interested in
  kAllowedSchemes = @[@"http", @"https", @"adblockbrowser", @"adblockbrowsers"];
}

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  if( self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil] ) {
    __weak typeof(self) weakSelf = self;
    _dismissBlock = ^(UIViewController* controller){
      [controller dismissViewControllerAnimated:NO completion:nil];
      [weakSelf.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    };
  }
  return self;
}

-(void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  NSItemProvider* provider = [self attachmentWithTypeIdentifier:(NSString*)kUTTypeURL
                                             inExtensionContext:self.extensionContext];
  if(provider) {
    [provider loadItemForTypeIdentifier:(NSString*)kUTTypeURL
                                options:nil
                      completionHandler:^(NSURL *url, NSError *error) {
      // this handler block emerges from a worker thread, not the main thread
      dispatch_async(dispatch_get_main_queue(), ^{
        BOOL validURL = !error && url && [kAllowedSchemes containsObject:url.scheme];
        // It would be MUCH prettier if the extension was disabled/greyed out for non applicable
        // contexts. Something like, you know, Android intents. Now, when the user already clicked
        // the extension icon, it must do some visual feedback. So good old failure alert.
        UIViewController *controller = validURL ? [self successAlertForURL:url] : [self failureAlert];
        [self presentViewController:controller animated:animated completion:nil];
      });
    }];
  } else {
    // kUTTypeURL provider not found in the extension. Which is rather strange for
    // a web browser extension, so failure alert is appropriate.
    [self presentViewController:[self failureAlert] animated:animated completion:nil];
  }
}

#pragma mark - Privates

// Look for an attachment provider of given type in the context
-(NSItemProvider*)attachmentWithTypeIdentifier:(NSString*)typeIdentifier
                            inExtensionContext:(NSExtensionContext*)context
{
  for(NSExtensionItem* item in context.inputItems) {
    for(NSItemProvider* attachment in item.userInfo[NSExtensionItemAttachmentsKey]) {
      if([attachment hasItemConformingToTypeIdentifier:typeIdentifier]) {
        return attachment;
      }
    }
  }
  return nil;
}

-(UIAlertController*)failureAlert {
  UIAlertController *ctrl = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"Open in Adblock Browser?", @"Sharing extension popup")
                                        message:NSLocalizedString(@"URL not found", @"Sharing extension popup")
                                        preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *dismiss = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Dismiss", @"Sharing extension popup")
                             style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction *action)
                             {
                               self->_dismissBlock(ctrl);
                             }];
  [ctrl addAction:dismiss];
  return ctrl;
}

-(UIAlertController*)successAlertForURL:(NSURL*)url {
  NSURLComponents* components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  // http(s) -> kitt(s)
  components.scheme = [components.scheme stringByReplacingOccurrencesOfString:@"http" withString:@"adblockbrowser"];
  UIAlertController *ctrl = [UIAlertController
    alertControllerWithTitle:NSLocalizedString(@"Open in Adblock Browser?", @"Sharing extension popup")
                     message:components.URL.host
              preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *cancel = [UIAlertAction
    actionWithTitle:NSLocalizedString(@"Cancel", @"Sharing extension popup")
              style:UIAlertActionStyleCancel
            handler:^(UIAlertAction *action)
            {
              self->_dismissBlock(ctrl);
            }];

  UIAlertAction *open = [UIAlertAction
    actionWithTitle:NSLocalizedString(@"Open", @"Sharing extension popup")
              style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action)
    {
      UIResponder* responder = self;
      // This iteration skips self as the first responder. It's correct because it essentialy
      // looks for UIApplication, and it's surely not self.
      while ((responder = [responder nextResponder]) != nil) {
        if([responder respondsToSelector:@selector(openURL:)] == YES) {
          // postpone the potential app switch after the following dismiss block
          dispatch_async(dispatch_get_main_queue(), ^{
            [responder performSelector:@selector(openURL:) withObject:components.URL];
          });
          break;
        }
      }
      self->_dismissBlock(ctrl);
    }];
  [ctrl addAction:cancel];
  [ctrl addAction:open];
  return ctrl;
}
@end
