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

import Caller from "./bridge/nativeCaller"

import {ENTRY_SYMBOL} from "./bridge/common"

import BaseKittInterface from "./modules/baseKittInterface"
import ChromeModule from "./modules/baseChromeApi"
import XHRModule from "./modules/xhr"
import createFetch from "./modules/fetch"
import ConsoleModule from "./modules/console"
import * as util from "./modules/util"

const nativeCaller = new Caller(window, "%ADDON_ID%", (window as any)[ENTRY_SYMBOL], "%TAB_ID%")
const api = BaseKittInterface(nativeCaller)
// objects
export const chrome = ChromeModule(api)
export const console = new ConsoleModule(api).render()
export const XMLHttpRequest = XHRModule(api)
export const fetch = createFetch(XMLHttpRequest as any)
// functions
export const stringifyError = util.stringifyError
