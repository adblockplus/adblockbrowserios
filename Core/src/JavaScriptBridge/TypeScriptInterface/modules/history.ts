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

import Caller from "../bridge/nativeCaller"

export default
{
  attachTo: function(window: Window, nativeCaller: Caller)
  {
    const globalScopeHistory = window.history

    // http://www.w3.org/html/wg/drafts/html/master/single-page.html#the-history-interface
    const patchFunctions = {
      pushState: (data: any, title: string, url?: string | null) => {
        return nativeCaller.call("core.html5History", ["pushState", url || window.location.href])
      },
      replaceState: (data: any, title: string, url?: string | null) => {
        return nativeCaller.call("core.html5History", ["replaceState", url || window.location.href])
      },
      back: () => {
        return nativeCaller.call("core.html5History", ["back", window.location.href])
      },
      forward: () => {
        return nativeCaller.call("core.html5History", ["forward", window.location.href])
      }
    }

    for (const functionName of Object.keys(patchFunctions) as (keyof typeof patchFunctions)[]) {
      // extra closure needed to capture each iteration
      // as contrary to defaulting to the last iterated value
      const originalFunction = globalScopeHistory[functionName]
      globalScopeHistory[functionName] = function() {
        // original fn must go first, then window.location.href is updated when patch is executed
        const originalRetval = originalFunction.apply(globalScopeHistory, arguments)
        patchFunctions[functionName].apply(globalScopeHistory, arguments)
        return originalRetval
      }
    }

    window.addEventListener("popstate", function(event) {
      nativeCaller.call("core.html5History", ["popstate", (<any>event.target).location.href.toString()])
    })
  }
}
