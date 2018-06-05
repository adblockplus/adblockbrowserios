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

#ifndef AdBlockPlus_Swift_Bridge_h
#define AdBlockPlus_Swift_Bridge_h

/**
 All ObjC headers with classes needed to use in Swift must be manually added here.
 The location of this file must be set in Build Settings "Objective-C Bridging Header"
 exactly the same way as "Info.plist file" setting, with the same path relation
 */

#import "CYRKeyboardButton.h"
#import "UIImage+animatedGIF.h"
#import "MacroSettingsExpander.h"

#import <KittCore/Utils.h>
#import <KittCore/Settings.h>
#import <KittCore/ReachabilityCentral.h>
#import <KittCore/NSString+PatternMatching.h>
#import <KittCore/NSURL+Conformance.h>

#import <KittCore/ExtensionUnpacker.h>
#import <KittCore/BrowserStateCoreData.h>
#import <KittCore/WebRequestEventDispatcher.h>
#import <KittCore/RequestFilteringCache.h>
#import <KittCore/BrowserStateCoreData.h>
#import <KittCore/SAWebViewFaviconLoader.h>
#import <KittCore/WebViewGesturesHandler.h>

#import <KittCore/JSInjectorReporter.h>
#import <KittCore/BridgeSwitchboard.h>
#import <KittCore/ExtensionBackgroundContext.h>

#import <KittCore/ProtocolHandlerChromeExt.h>

#import <KittCore/OmniboxDataSource.h>
#import <KittCore/NSTimer+Blocks.h>

#endif
