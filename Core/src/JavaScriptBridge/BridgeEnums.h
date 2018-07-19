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

#import <UIKit/UIKit.h>

@protocol WebViewFacade;

/// Who has originated this callback. Determined by which UIWebViewDelegate has
/// reported the event subscription event.
typedef NS_ENUM(NSInteger, CallbackOriginType) {
    CallbackOriginBackground,
    CallbackOriginContent,
    CallbackOriginPopup
};

/// What was the purpose of originating the callback.
/// Known from parameters of subscription command.
typedef NS_ENUM(NSInteger, CallbackEventType) {
    CallbackEvent_Undefined = -1,
    CallbackEvent_RuntimeStartup,
    CallbackEvent_RuntimeInstall,
    CallbackEvent_RuntimeSuspend,
    CallbackEvent_RuntimeMessage,
    CallbackEvent_DeclarativeWebRequestMessage,
    CallbackEvent_ContextMenuClicked,
    CallbackEvent_BrowserActionClicked,
    CallbackEvent_WebRequest_OnBeforeRequest,
    CallbackEvent_WebRequest_OnBeforeSendHeaders,
    CallbackEvent_WebRequest_OnHeadersReceived,
    CallbackEvent_WebRequest_HandlerBehaviorChanged,
    CallbackEvent_WebNavigation_OnCreatedNavTarget,
    CallbackEvent_WebNavigation_OnBeforeNavigate,
    CallbackEvent_WebNavigation_OnCommitted,
    CallbackEvent_WebNavigation_OnCompleted,
    CallbackEvent_Tabs_OnActivated,
    CallbackEvent_Tabs_OnCreated,
    CallbackEvent_Tabs_OnUpdated,
    CallbackEvent_Tabs_OnMoved,
    CallbackEvent_Tabs_OnRemoved,
    CallbackEvent_FullText_CountMatches,
    CallbackEvent_FullText_MarkMatches,
    CallbackEvent_FullText_UnmarkMatches,
    CallbackEvent_FullText_MakeCurrent,
    CallbackEvent_Storage_OnChanged,
    CallbackEvent_Autofill_FillSuggestion
};
