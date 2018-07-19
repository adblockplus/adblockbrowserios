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
 * A separate injection unit for content scripts. Creates just the callback
 * entry, because the actual content script wrapper will be possibly injected
 * more than once, hence it would unnecessarily reinject the global callback entry
 */

import Caller from "./bridge/nativeCaller"
import * as callback from "./bridge/callbackEntry"
import BaseKittInterface from "./modules/baseKittInterface"
import * as util from "./modules/util"
import html5history from "./modules/history"
import fulltext from "./modules/fulltext"
import DOMPatch from "./modules/dom_patch"
import autofill from "./modules/autofill"
import * as common from "./bridge/common"

let callbackEntry = new callback.CallbackEntry();
(window as any)[common.ENTRY_SYMBOL] = callbackEntry

callback.setUpMessageForwardingBetweenFrames(callbackEntry, window)
const nativeCaller = new Caller(window, "%ADDON_ID%", callbackEntry, "%TAB_ID%")

const api = BaseKittInterface(nativeCaller)
const dom_patch = new DOMPatch(nativeCaller)

html5history.attachTo(window, nativeCaller)
// Public webpages having access to our console implementation is basically a good idea
// but it turns out that public webpages got tons of ignored warnings in it, which makes
// filtering and debugging OUR warnings unnecessarily hard.
// new ConsoleModule(api).patch(window.console);

fulltext.init(api)
autofill.init(api, document)

// UIWebView has no 'loaded' event, so hook on the DOM with JSContext bridge
window.addEventListener("load", function () {
  nativeCaller.sendEvent("DOMDidLoad", {title: document.title, readyState: document.readyState})
})

// Send to readyState change events to bridge
const onReadyStateChange = function () {
  nativeCaller.sendEvent("ReadyStateDidChange", {readyState: document.readyState})
}
onReadyStateChange()
document.addEventListener("readystatechange", onReadyStateChange)


dom_patch.performActionsRequiringDocumentElement(document)
dom_patch.observeSourceableNodes(document)
// functions
export const stringifyError = util.stringifyError
export const windowOpen = dom_patch.windowOpen
export const windowClose = dom_patch.windowClose

window.onerror = dom_patch.windowOnError

const observerHead = new MutationObserver(function(mutations) {
  // iOS is trying to save phone resources and therefore JSContent is not created for all frames.
  // JSContext of given frame is created by those events:
  // 1) frame is top most from single domain
  // 2) body of frame or one of its subframes contains executable javascript
  // 3) JSContext is accessed from outside (parent frame context)
  // That why, we need to access all contexts of all created frames from same domain.
  // For proper working of ABP, content script has to be injected into all contexts of all frames!
  mutations.forEach(function(mutation) {
    for (let i = 0; i < mutation.addedNodes.length; i++) {
      const node: any = mutation.addedNodes[i]
      if (node.nodeName.toUpperCase() === "IFRAME" && node.nodeType === 1) {
        let html: any = null
        try {
          // deal with older browsers
          const doc = node.contentDocument || node.contentWindow.document
          html = doc.body.innerHTML
        } catch (err) {
        }
      }
    }
  })

  const favicons: any[] = []

  mutations.forEach(function(mutation) {
    const mutatedNodeName = mutation.target.nodeName.toUpperCase()
    // Because we're observing subtree, mutations to HEAD subnodes go here too.
    // We're interested in TITLE and LINK but LINK doesn't appear as mutated
    // because it's only added and doesn't have further subnodes. TITLE has #text.
    if ( mutatedNodeName !== "HEAD" && mutatedNodeName !== "TITLE" ) {
      return
    }
    for (let i = 0; i < mutation.addedNodes.length; i++) {
      const addedNode: any = mutation.addedNodes[i]
      if (mutatedNodeName === "TITLE" && addedNode.nodeName === "#text" ) {
        // TITLE is telling us it's got a new #text subnode
        nativeCaller.sendEvent("TitleDidChanged", {newValue: addedNode.nodeValue})
      } else if (addedNode.nodeName === "LINK") {
        // HEAD is telling us it's got a LINK subnode
        const linkRelName = addedNode.rel.toLowerCase()
        if (["icon", "shortcut icon", "apple-touch-icon"].indexOf(linkRelName) != -1) {
          favicons.push({href: addedNode.href, rel: linkRelName, sizes: addedNode.getAttribute("sizes")})
        }
      }
    }
  })

  if (favicons.length > 0) {
    nativeCaller.sendEvent("FaviconsDidChanged", favicons)
  }
})
// Logically we should be able to observe document.head because it DOES exist in the
// case we're covering immediately (Mobify wrapper on wired pages), only it contains
// dynamic garbage which gets transmutated to the real content on the fly.
// But MutationObserver then gives just one mutation of HEAD with no addedNodes.
// All the mutations under HEAD start flowing in only if whole document is observed.
// It feels like a bug but i know little about how MutationObserver is supposed to work.
observerHead.observe(document, {childList: true, subtree: true})
