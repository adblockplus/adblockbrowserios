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

/**
Wrapper for gestures over a currently visible web view. Can attach the recognizers
on the webviev itself or its container superview. Capable of walking the DOM and filling
urls with links of clickable content found at a given point.
 
@warning injects global JS code to the web view (i.e. attached to window)
*/

/// Action block giving the log tap point in webview coordinates
typedef void (^OnLongTapHandlerBlock)(CGPoint);

@class CurrentContextURLs;

@interface WebViewGesturesHandler : NSObject

/// @param viewToRecognize the view which the recognizer(s) will be attached to.
/// It can absolutely be currentWebView itself but it can't change then.
- (instancetype)initWithViewToRecognize:(UIView *)viewToRecognize;

/// The webview which will be tested for DOM hits
@property (nonatomic, weak) UIWebView *currentWebView;

@property (nonatomic, strong) OnLongTapHandlerBlock handlerBlock;

/// Walks the DOM of currentWebView, filling urls with links of clickable content
/// found at the point
- (void)getURLs:(CurrentContextURLs *)urls fromCurrentPosition:(CGPoint)point;

@end
