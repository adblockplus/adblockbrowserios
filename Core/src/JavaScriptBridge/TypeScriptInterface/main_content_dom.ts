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

import * as callback from "./bridge/callbackEntry"
import Caller from "./bridge/nativeCaller"

import FullKittInterface from "./modules/fullKittInterface"
import ChromeModule from "./modules/fullChromeApi"
import XHRModule from "./modules/xhr"
import createFetch from "./modules/fetch"
import ConsoleModule from "./modules/console"
import * as util from "./modules/util"
import html5history from "./modules/history"
import fulltext from "./modules/fulltext"
import DOMPatch from "./modules/dom_patch"

import * as common from "./bridge/common"

let callbackEntry = new callback.CallbackEntry();
(window as any)[common.ENTRY_SYMBOL] = callbackEntry

callback.setUpMessageForwardingBetweenFrames(callbackEntry, window)
const nativeCaller = new Caller(window, "%ADDON_ID%", callbackEntry, "%TAB_ID%")

const api = FullKittInterface(nativeCaller)
const dom_patch = new DOMPatch(nativeCaller)

html5history.attachTo(window, nativeCaller)
new ConsoleModule(api).patch(window.console)

if (window.self === window.top) {
  fulltext.init(api)
  // UIWebView has no 'loaded' event, so hook on the DOM with JSContext bridge
  window.addEventListener("load", function () {
    nativeCaller.sendEvent("DOMDidLoad", {title: document.title, readyState: document.readyState})
  })
}

dom_patch.performActionsRequiringDocumentElement(document)

// objects
export const chrome = ChromeModule(api)
export const XMLHttpRequest = XHRModule(api)
export const fetch = createFetch(XMLHttpRequest as any)
// functions
export const stringifyError = util.stringifyError
export const windowOpen = dom_patch.windowOpen
export const windowClose = dom_patch.windowClose
window.onerror = dom_patch.windowOnError
