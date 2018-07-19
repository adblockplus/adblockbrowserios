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

#import "BrowserContextActionSheet.h"
#import <KittCore/ContextMenuProvider.h>
#import <KittCore/SAContentWebView.h>
#import <KittCore/Settings.h>
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

@interface BrowserContextActionSheet () <UIActionSheetDelegate> {
  NSInteger _copyLinkButtonIndex;
  NSInteger _openLinkHereButtonIndex;
  NSInteger _openInNewTabButtonIndex;
  NSInteger _openInBackgroundButtonIndex;
  NSInteger _saveResourceButtonIndex;

  id<ContextMenuDataSource> _dataSource;
  UIActionSheet *_currentSheet; // remember to deallocate when dismissed
  CurrentContextURLs *_currentURLs; // used when button clicked
  SAContentWebView *_currentWebView; // used when button clicked
}
@end

@implementation BrowserContextActionSheet

-(instancetype)initWithDataSource:(id<ContextMenuDataSource>)dataSource
{
  if(self = [super init]) {
    _dataSource = dataSource;
  }
  return self;
}

-(BOOL)isVisible {
  return _currentSheet.visible;
}

-(BOOL)createForCurrentWebView:(SAContentWebView *)webView
                actionsForURLs:(CurrentContextURLs *)urls {
  NSURL *actionableURL = [[self class] usableURLFromCurrent:urls];
  if(!actionableURL) {
    return false;
  }
  _currentWebView = webView;
  _currentURLs = urls;
  _currentSheet = [UIActionSheet new];
  _currentSheet.title = [[self class] titleFromCurrentURLs:_currentURLs];
  _currentSheet.delegate = self;
  _currentSheet.actionSheetStyle = UIActionSheetStyleDefault;
  _openLinkHereButtonIndex = [_currentSheet addButtonWithTitle:
                              BundleLocalizedString(@"Open Here", @"Link long-press context menu")];
  _openInNewTabButtonIndex = [_currentSheet addButtonWithTitle:
                              BundleLocalizedString(@"Open in New Tab", @"Link long-press context menu")];
  if (_blockOpenInBackground != nil) {
    _openInBackgroundButtonIndex = [_currentSheet addButtonWithTitle:
                                    BundleLocalizedString(@"Open in Background Tab", @"Link long-press context menu")];
  }
  __strong WebDownloadsManager *sMgr = self.downloadsMgr;
  if(sMgr) {
    if(_currentURLs.image) {
      _saveResourceButtonIndex = [_currentSheet addButtonWithTitle:
                                  BundleLocalizedString(@"Save Image", @"Link long-press context menu")];
    } else {
      NSNumber *typeNumber = [ResourceTypeDetector objc_detectTypeFromURL:actionableURL allowExtended:YES];
      if(typeNumber && [typeNumber integerValue] == WebRequestResourceTypeExtVideo) {
        _saveResourceButtonIndex = [_currentSheet addButtonWithTitle:
                                    BundleLocalizedString(@"Save Video", @"Link long-press context menu")];
      }
    }
  }
  _copyLinkButtonIndex = [_currentSheet addButtonWithTitle:
                          BundleLocalizedString(@"Copy Link", @"Link long-press context menu")];

  if(_dataSource) {
    [_dataSource addActionsForURLs:_currentURLs
                       toContainer:_currentSheet
                         inContext:MenuContext_LinkLongTap];
  }
  _currentSheet.cancelButtonIndex = [_currentSheet addButtonWithTitle:
                                     BundleLocalizedString(@"Cancel",@"Link long-press context menu")];
  return true;
}

-(void)showInView:(UIView *)view {
  _currentWebView.ignoreAllRequests = YES;
  [_currentSheet showInView:view];
}

#pragma mark - Private

+ (NSURL *)usableURLFromCurrent:(CurrentContextURLs *)currentURLs {
  NSURL *url = currentURLs.link;
  if(!url) {
    url = currentURLs.image;
  }
  return url;
}

+ (NSString *)titleFromCurrentURLs:(CurrentContextURLs *)currentURLs {
  if(currentURLs.label) {
    return currentURLs.label;
  }
  NSURL *url = [self usableURLFromCurrent:currentURLs];
  if(!url) {
    return nil;
  }
  NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
  components.query = nil;
  components.fragment = nil;
  return [[components.URL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSURL *actionableURL = [[self class] usableURLFromCurrent:_currentURLs];
  if(!actionableURL) {
    LogWarn(@"Webpage context action sheet has no URL to work on");
    return;
  }
  if (_copyLinkButtonIndex == buttonIndex) {
    if(self.blockCopyLink) {
      self.blockCopyLink(actionableURL);
    }
  } else if (_openLinkHereButtonIndex == buttonIndex) {
    if(self.blockOpenHere) {
      self.blockOpenHere(actionableURL);
      _currentURLs.link = nil;
      // @todo ^^^ try to recall why this is needed
    }
  } else if(_openInNewTabButtonIndex == buttonIndex) {
    if(self.blockNewTab) {
      self.blockNewTab(actionableURL, _currentWebView);
    }
  } else if(_openInBackgroundButtonIndex == buttonIndex) {
    if(self.blockOpenInBackground) {
      self.blockOpenInBackground(actionableURL, _currentWebView);
    }
  } else if(_saveResourceButtonIndex == buttonIndex) {
    __strong WebDownloadsManager *sMgr = self.downloadsMgr;
    if(sMgr) {

      SaveableWebLink *link = [[SaveableWebLink alloc] initWithUrl:_currentURLs.image ? _currentURLs.image : _currentURLs.link
                                                              type:(_currentURLs.image ? LinkTypeImage : LinkTypeVideo)];
      [sMgr enqueue:link];
    }
  } else if (_dataSource && [_dataSource isButtonIndex:buttonIndex
                                  registeredForContext:MenuContext_LinkLongTap]) {
    NSString *selectedText = [_currentWebView stringByEvaluatingJavaScriptFromString:@"window.getSelection().toString()"];
    _currentURLs.page = _currentWebView.currentURL;
    [_dataSource actionIndexClicked:buttonIndex withSelection:selectedText withURLs:_currentURLs];
  }
  _currentWebView.ignoreAllRequests = NO;
}

-(void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
  _currentWebView.ignoreAllRequests = NO;
  _currentSheet = nil;
}


@end
