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

/**
 * Full Chrome API for background/browser/page action scripts
 */

import ChromeExtension from "../chrome/extension"
import ChromeRuntime from "../chrome/runtime"
import ChromeTabs from "../chrome/tabs"
import ChromeDeclarativeWebRequest from "../chrome/declarativeWebRequest"
import ChromeContextMenus from "../chrome/contextMenus"
import ChromeStorage from "../chrome/storage"
import ChromeBrowserAction from "../chrome/browserAction"
import ChromeWebRequest from "../chrome/webRequest"
import ChromeWebNavigation from "../chrome/webNavigation"
import ChromeWindows from "../chrome/windows"
import ChromeI18n from "../chrome/i18n"
// not a regular chrome API
import ChromeXAutofill from "../chrome/x-autofill"
import {IFullKittInterface} from "./fullKittInterface"

export default function(api: IFullKittInterface) {
  return {
    extension : ChromeExtension(api),
    runtime :  ChromeRuntime(api),
    tabs : ChromeTabs(api),
    declarativeWebRequest : ChromeDeclarativeWebRequest(api),
    contextMenus : ChromeContextMenus(api),
    storage : ChromeStorage(api),
    browserAction : ChromeBrowserAction(api),
    webRequest : ChromeWebRequest(api),
    webNavigation : ChromeWebNavigation(api),
    windows: ChromeWindows(api),
    i18n : ChromeI18n(api),
    autofill: ChromeXAutofill(api)
  }
}
