//
//  WebViewFacade.m
//  Kitt-core
//
//  Created by Jan Dědeček on 04/06/15.
//  Copyright (c) 2015 Salsita s.r.o. All rights reserved.
//

#import "WebViewFacade.h"

@interface FacadeWithUIWebView : WebViewFacade {
  @public
  UIWebView *_webView;
}

@end


@implementation FacadeWithUIWebView

- (UIView *)webView
{
  return _webView;
}

- (NSURL *)URL
{
  return _webView.request.mainDocumentURL;
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
  NSString *result = [_webView stringByEvaluatingJavaScriptFromString:javaScriptString];
  completionHandler(result, nil);
}

@end



@interface FacadeWithWKWebView : WebViewFacade {
@public
  WKWebView *_webView;
}

@end


@implementation FacadeWithWKWebView

- (UIView *)webView
{
  return _webView;
}

- (NSURL *)URL
{
  return _webView.URL;
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
  [_webView evaluateJavaScript:javaScriptString completionHandler:completionHandler];
}

@end



@implementation WebViewFacade

@dynamic URL;

+ (instancetype)webViewFacadeWithUIWebView:(UIWebView *)webView
{
  FacadeWithUIWebView *f = [FacadeWithUIWebView new];
  f->_webView = webView;
  return f;
}

+ (instancetype)webViewFacadeWithWKWebView:(WKWebView *)webView
{
  FacadeWithWKWebView *f = [FacadeWithWKWebView new];
  f->_webView = webView;
  return f;
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
}

@end


