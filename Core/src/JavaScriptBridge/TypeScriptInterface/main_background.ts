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

import * as callback  from "./bridge/callbackEntry"
import Caller from "./bridge/nativeCaller"

import FullKittInterface from "./modules/fullKittInterface"
import ChromeModule from "./modules/fullChromeApi"
import XHRModule from "./modules/xhr"
import ConsoleModule from "./modules/console"
import * as util from "./modules/util"
import DOMPatch from "./modules/dom_patch"
import createFetch from "./modules/fetch"
import * as common from "./bridge/common"

let callbackEntry = new callback.CallbackEntry();
(window as any)[common.ENTRY_SYMBOL] = callbackEntry

callback.setUpMessageForwardingBetweenFrames(callbackEntry, window)
const nativeCaller = new Caller(window, "%ADDON_ID%", callbackEntry, undefined)

const api = FullKittInterface(nativeCaller)
const dom_patch = new DOMPatch(nativeCaller)
new ConsoleModule(api).patch(window.console)

export const chrome = ChromeModule(api)
export const XMLHttpRequest = XHRModule(api)
export const fetch = createFetch(XMLHttpRequest as any)
export const stringifyError = util.stringifyError
window.onerror = dom_patch.windowOnError
