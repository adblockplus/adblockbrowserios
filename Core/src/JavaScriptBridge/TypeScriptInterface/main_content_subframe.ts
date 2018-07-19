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
import * as callback from "./bridge/callbackEntry"
import * as util from "./modules/util"
import DOMPatch from "./modules/dom_patch"
import * as common from "./bridge/common"

let callbackEntry = new callback.CallbackEntry();
(window as any)[common.ENTRY_SYMBOL] = callbackEntry

callback.setUpMessageForwardingBetweenFrames(callbackEntry, window)
const nativeCaller = new Caller(window, "%ADDON_ID%", callbackEntry, "%TAB_ID%")

const dom_patch = new DOMPatch(nativeCaller)
dom_patch.performActionsRequiringDocumentElement(document)
dom_patch.observeSourceableNodes(document)
// functions
export const stringifyError = util.stringifyError
export const windowOpen = dom_patch.windowOpen

window.onerror = dom_patch.windowOnError

// This is a subframe injection, so forcing JS context creation is required
// only if ALL_FRAMES flag was set by the native code
const allFrames: string = "_ALL_FRAMES_"
if (allFrames === "T") {

  // iOS is trying to save phone resources and therefore JSContent is not created for all frames.
  // JSContext of given frame is created by those events:
  // 1) frame is top most from single domain
  // 2) body of frame or one of its subframes contains executable javascript
  // 3) JSContext is accessed from outside (parent frame context)
  // That why, we need to access all contexts of all created frames from same domain.
  // For proper working of ABP, content script has to be injected into all contexts of all frames!

  const iframeObserver = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      for (let i = 0; i < mutation.addedNodes.length; i++) {
        const node = mutation.addedNodes[i]
        if (node.nodeName.toUpperCase() === "IFRAME" && node.nodeType === 1) {
          let html: any = null
          try {
            // deal with older browsers
            const doc = (<any>node).contentDocument || (<any>node).contentWindow.document
            html = doc.body.innerHTML
          } catch (err) {
          }
        }
      }
    })
  })

  iframeObserver.observe(document, {childList: true, subtree: true})
}
