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

#import "SAWebView.h"
#import <AVFoundation/AVFoundation.h>
#import "Utils.h"
#import "Settings.h"
#import "NSURL+Conformance.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

static NSUInteger _staticSubFrameIdentifier = 1;

/// Needed as key in the mapping table, when the object is a provisional KittFrame
@interface ProvisionalWebKitFrame : NSObject <WebKitFrame>
@property (nonatomic, weak) id<WebKitFrame> parentFrame;
@end

@implementation ProvisionalWebKitFrame
- (id<WebKitFrame>)parentFrame
{
    return self.parentFrame;
}
@end

@interface SAWebView ()
/// Map of weak WebFrames to strong KittFrames which retain the relevant JSContext
@property (nonatomic, strong) NSMapTable<id<WebKitFrame>, KittFrame *> *frameContextOwningMap;

/// Something to hold strong references to provisional frames so that it's retained until
/// it's replaced by the real WebKitFrames
@property (nonatomic, strong) NSMutableSet<id<WebKitFrame> > *provisionalWKFrames;

/// The lock to guard both above structures.
/// provisionalWKFrames is always modified together with frameContextOwningMap
@property (nonatomic, strong) NSLock *frameMappingLock;

/**
 Should not be needed for anything, except one weird occassional JSC behavior:
 1. main frame is created (ie. a frame with no parent frame is reported) = A
 2. a subframe B is reported, with a parent frame C which is a new, previously unknown main frame
 3. only then the new parent frame C is officialy reported
 The fact that C is replacing B can be recognized by observing that in step 2, A is nil.
 If it was not nil, it would be a pathological consistency error.
*/
@property (nonatomic, weak) id<WebKitFrame> lastKnownMainFrame;
@end

@implementation SAWebView

- (instancetype)init
{
    // http://stackoverflow.com/questions/19423182/why-uiview-calls-both-init-and-initwithframe/19423494#19423494
    NSAssert(false, @"Call initWithFrame:CGRectZero to maintain single init point");
    return [super init];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    LogDebug(@"SAWebView initWithFrame");
    if (self = [super initWithFrame:frame]) {
        [[WebViewManager sharedInstance] add:self];
        // http://stackoverflow.com/questions/11616001/uiwebview-html5-audio-pauses-in-ios-6-when-app-enters-background
        // Doing this in webview common ancestor because not only content webview may
        // want to make sounds. Probably needs to be set again before each instantiation
        // because phone may be muted/unmuted/remuted at any time
        NSError *err = nil;
        if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err]) {
            UIAlertView *alert = [Utils alertViewWithError:nil
                                                     title:[LocalizationResources
                                                               bundleString:@"Web audio setup"
                                                                    comment:@"Web audio setup"]
                                                  delegate:nil];
            alert.message = [LocalizationResources bundleString:@"Failed to set audio session for the webview; there may be no sound."
                                                        comment:@"Web audio setup"];
            [alert show];
        }

        _frameContextOwningMap = [NSMapTable weakToStrongObjectsMapTable];
        _provisionalWKFrames = [NSMutableSet new];
        _frameMappingLock = [NSLock new];
    }
    return self;
}

- (void)dealloc
{
    [[WebViewManager sharedInstance] remove:self];
    LogDebug(@"SAWebView dealloc");
}

- (CallbackOriginType)origin
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

#pragma mark - JavaScriptCore

- (NSEnumerator *)threadsafeKittFrames
{
    NSMutableArray<KittFrame *> *objectEnumeratorCopy = [NSMutableArray new];
    @synchronized(_frameMappingLock)
    {
        for (KittFrame *frame in [self.frameContextOwningMap objectEnumerator]) {
            [objectEnumeratorCopy addObject:frame];
        }
    }
    return [objectEnumeratorCopy objectEnumerator];
}

- (KittFrame *)mainThreadAddContext:(JSContext *)context
                          fromFrame:(id<WebKitFrame>)webKitFrame
{
    NSAssert([NSThread isMainThread], @"Adding JS context not from main thread");
    KittFrame *kittFrame = nil;
    @synchronized(_frameMappingLock)
    {
        kittFrame = [self.frameContextOwningMap objectForKey:webKitFrame];
    }
    if (kittFrame) {
        // This used to be Warning but recycling frames seems to be a normal operation mode for JSCore
        LogInfo(@"JSC is reusing known wkframe (%@ %@) %@", kittFrame.frameId, kittFrame.parentFrameId, kittFrame.fullURLString);
        /*
         This used to be "else" and the following new frame mapping creation was not executed.
         However, it normally happens that after a frame is reused, ProtocolHandler still
         receives requests with a referer of the previous frame. So all evolutions of the one frame
         must be kept. We must trust JSC to clear them up.
         */
    }
    /*
     webKitFrame may not be a direct child of already known frame. There may be intermediate frames.
     Descend until a known frame is reached or a frame root is hit (webKitFrame is a mainFrame).
     Remember all frames in between.
     */
    NSMutableArray *unknownFrameChain = [NSMutableArray arrayWithObject:webKitFrame];
    NSNumber *parentFrameId = nil;
    NSNumber *frameId = nil;
    for (id currentFrame = webKitFrame;;) {
        id parentFrame = [currentFrame parentFrame];
        if (parentFrame == nil) {
            if ([unknownFrameChain count] > 1) {
                // @see lastKnownMainFrame doc for explanation of this assert
                NSAssert(!_lastKnownMainFrame, @"Frame parent descending reached an unknown main frame %p, expected %p", currentFrame, _lastKnownMainFrame);
            } else {
                // webKitFrame is a main frame
                _lastKnownMainFrame = currentFrame;
                // main frame is the only case where frameId is set in this iteration
                frameId = @(0);
            }
            parentFrameId = @(-1);
            break;
        }
        NSAssert([parentFrame respondsToSelector:@selector(parentFrame)], @"");
        id<WebKitFrame> parentWebKitFrame = parentFrame;
        @synchronized(_frameMappingLock)
        {
            kittFrame = [self.frameContextOwningMap objectForKey:parentWebKitFrame];
        }
        if (kittFrame) {
            // reached a known parent frame
            parentFrameId = kittFrame.frameId;
            break;
        }
        // create LIFO, will be iterated from parent down to child to establish a proper frameid chaining
        [unknownFrameChain insertObject:parentWebKitFrame atIndex:0];
        currentFrame = parentWebKitFrame;
    }
    // Assign frame ids to all newly found (descended) subframes
    for (id<WebKitFrame> newFrame in unknownFrameChain) {
        kittFrame = [KittFrame new];
        kittFrame.parentFrameId = parentFrameId;
        if (frameId) {
            // webKitFrame was a main frame
            NSAssert([unknownFrameChain count] == 1, @"Frame with nil parent expected to be alone main frame");
            kittFrame.frameId = frameId;
        } else {
            kittFrame.frameId = @(_staticSubFrameIdentifier++);
            parentFrameId = [kittFrame.frameId copy];
        }
        NSAssert(kittFrame.parentFrameId && kittFrame.frameId, @"frameId and parentFrameId must be set!");
        @synchronized(_frameMappingLock)
        {
            [self.frameContextOwningMap setObject:kittFrame forKey:newFrame];
        }
    }
    kittFrame.context = context;
    kittFrame.provisional = false;
    JSValue *href = [context globalObject][@"location"][@"href"];
    [kittFrame assignFrameURL:[href toString]];
    [self purgeProvisionalFrameWithURL:kittFrame.fullURLString];
    [self purgeFrameMaps];
    return kittFrame;
}

- (KittFrame *)kittFrameForWebKitFrame:(id<WebKitFrame>)frame
{
    @synchronized(_frameMappingLock)
    {
        return [self.frameContextOwningMap objectForKey:frame];
    }
}

- (KittFrame *)kittFrameForReferer:(NSString *)referer
{
    NSArray *tuple = [self keyValueTupleForReferer:referer];
    return tuple ? tuple[1] : nil;
}

- (KittFrame *)provisionalFrameForURL:(NSString *)url
             parentFrameRefererString:(NSString *)parentFrameRefererString
{
    ProvisionalWebKitFrame *tempWKFrame = [ProvisionalWebKitFrame new];
    KittFrame *tempKittFrame = [KittFrame new];
    tempKittFrame.provisional = true;
    BOOL doClearProvisionalFrames = NO;
    if (parentFrameRefererString) {
        // subframe
        NSArray *tuple = [self keyValueTupleForReferer:parentFrameRefererString];
        NSAssert(tuple, @"Mapping does not exist for provisional frame referer %@", parentFrameRefererString);
        tempWKFrame.parentFrame = tuple[0];
        KittFrame *parentKittFrame = tuple[1];
        tempKittFrame.parentFrameId = [parentKittFrame.frameId copy];
        tempKittFrame.frameId = @(_staticSubFrameIdentifier++);
    } else {
        // mainframe
        tempWKFrame.parentFrame = nil;
        tempKittFrame.frameId = @(0);
        tempKittFrame.parentFrameId = @(-1);
        doClearProvisionalFrames = YES;
    }
    [tempKittFrame assignFrameURL:url];
    NSAssert(tempKittFrame.parentFrameId && tempKittFrame.frameId, @"frameId and parentFrameId must be set!");
    @synchronized(_frameMappingLock)
    {
        [self.frameContextOwningMap setObject:tempKittFrame forKey:tempWKFrame];
        if (doClearProvisionalFrames) {
            [self.provisionalWKFrames removeAllObjects];
        }
        [self.provisionalWKFrames addObject:tempWKFrame];
    }
    return tempKittFrame;
}

- (void)assignAliasForCurrentMainFrame:(NSString *__nullable)alias
{
    @synchronized(_frameMappingLock)
    {
        for (id<WebKitFrame> key in self.frameContextOwningMap.keyEnumerator) {
            KittFrame *frame = [self.frameContextOwningMap objectForKey:key];
            if ([frame.frameId isEqualToNumber:@(0)]) {
                frame.alias = alias;
            }
        }
    }
}

- (BridgeSwitchboard *)bridgeSwitchboard
{
    NSAssert(false, @"This should not be called");
    return nil;
}

#pragma mark - Private

/// @return @[id<WebKitFrame>, KittFrame*]
- (NSArray *)keyValueTupleForReferer:(NSString *)referer
{
    @synchronized(_frameMappingLock)
    {
        for (id<WebKitFrame> key in self.frameContextOwningMap.keyEnumerator) {
            KittFrame *obj = [self.frameContextOwningMap objectForKey:key];
            if ([referer isEqualToString:obj.fullURLString]) {
                return @[ key, obj ];
            }
        }

        // Full URL match not found, try to match on partial path-only URL
        // (it is really produced by WebKit as Referer header sometimes)
        for (id<WebKitFrame> key in self.frameContextOwningMap.keyEnumerator) {
            KittFrame *obj = [self.frameContextOwningMap objectForKey:key];
            if ([referer isEqualToString:obj.refererURLString]) {
                return @[ key, obj ];
            }

            if ([referer isEqualToString:obj.alias]) {
                return @[ key, obj ];
            }
        }

        return nil;
    }
}

- (void)purgeFrameMaps
{
    id<WebKitFrame> wkFrame = nil;
    KittFrame *kittFrame = nil;
    @synchronized(_frameMappingLock)
    {
        // Just iterate to nudge the weak ref clearing
        for (id<WebKitFrame> key in self.frameContextOwningMap.keyEnumerator) {
            wkFrame = key;
            kittFrame = [self.frameContextOwningMap objectForKey:key];
        }
    }
}

- (void)purgeProvisionalFrameWithURL:(NSString *)urlString
{
    id<WebKitFrame> wkFrameToDelete = nil;
    @synchronized(_frameMappingLock)
    {
        for (id<WebKitFrame> key in [self.frameContextOwningMap keyEnumerator]) {
            KittFrame *obj = [self.frameContextOwningMap objectForKey:key];
            NSAssert(obj.provisional == [key isKindOfClass:[ProvisionalWebKitFrame class]], @"Provisional flag mismatch");
            BOOL match = obj.provisional && [obj.fullURLString isEqualToString:urlString];
            if (match) {
                wkFrameToDelete = key;
                break;
            }
        }
        if (wkFrameToDelete) {
            NSAssert([self.provisionalWKFrames containsObject:wkFrameToDelete], @"Provisional WK frame was retained but does not exist");
            [self.provisionalWKFrames removeObject:wkFrameToDelete];
            [self.frameContextOwningMap removeObjectForKey:wkFrameToDelete];
        }
    }
}

#pragma mark - WebViewProtocol

- (NSURL *)URL
{
    return self.request.mainDocumentURL;
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
    NSString *result = [self stringByEvaluatingJavaScriptFromString:javaScriptString];
    if (completionHandler) {
        completionHandler(result, nil);
    }
}

@end
