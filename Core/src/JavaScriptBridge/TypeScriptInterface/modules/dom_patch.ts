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

import * as util from "./util"
import Caller from "../bridge/nativeCaller"

// I couldn't find any standard of window name, so let's assume
// safe set of alphabet, numbers, underscore, dash and space
// Most imporantly NO commas and equal signs (would overlap with 'specs')
const rexWindowName = /^[-\w ]+$/
// CSV with key=value pairs
// @todo the set of allowed keys is limited and well defined
const rexSpecs = /^(\s*([a-z]+)\s*=\s*(yes|no|[0-9]+)\s*(,|$))+/
// all window.open parameters are optional.
// 0: [string] URL
// 1: [string] _blank (default) _parent _self _top "NAME"
// 2: [CSV key=value] specs @todo mapping from regex match groups
// 3: [bool] history replace
const windowOpenValidators = [
  { name: "url",
    mandatory: true,
    validate: function(arg: any) {
    // Anything is accepted as URL. Even high profile sites are using non-compliant
    // strings, like news.google.cz embeds another complete non-urlencoded URL in its path.
    // Naked relative path (ie. not even starting with a slash) has no specific recognizable
    // elements either. There was a regex here but it has become so loose over time that it
    // effectively accepted anything in the end.
      return (typeof arg === "string")
    }
  },
  { name: "target",
    mandatory: false,
    validate: function(arg: any) {
      return (typeof arg === "string") && (
        (["_blank", "_parent", "_self", "_top"].indexOf(arg) > -1) ||
        rexWindowName.test(arg))
    }
  },
  { name: "specs",
    mandatory: false,
    validate: function(arg: any) {
      return (typeof arg === "string") && rexSpecs.test(arg)
    }
  },
  { name: "history",
    mandatory: false,
    validate: function(arg: any) {
      return (typeof arg === "boolean")
    }
  }
]

export default class {

  constructor(private nativeCaller: Caller) {
  }

  _windowOpen(...args: any[]) {
    /*
     All window.open parameters are optional but not free sequence. I.e. it can be called without
     any parameters, in which case it opens `about:blank`, but when there is some parameters, the
     first one is expected to be an URL, followed by a free sequence of other parameters.
     It is not very obvious from any of the docs, the ultimate
     https://developer.mozilla.org/en-US/docs/Web/API/Window/open
     just says that an empty URL string resolves to `about:blank` loading. But the above behavior
     was practically observed with all major browser (well except MSIE).
    */
    const results: {[s: string]: any} = {}
    let argIndex = 0
    let valIndex = 0
    while ( (valIndex < windowOpenValidators.length) && (argIndex < args.length) ) {
      const validator = windowOpenValidators[valIndex++]
      const arg = args[argIndex]
      if (validator.validate(arg)) {
        results[validator.name] = arg
        argIndex++ // validate next arg
      } else if (validator.mandatory) {
        throw new Error("window.open parameter invalid: \"" + validator.name + "\" = \"" + arg + "\"")
      }
    }
    return this.nativeCaller.call("core.open", [results])
  }

  private _windowClose() {
    setTimeout(() => {
      this.nativeCaller.call("core.close", [])
    }, 0)
  }

  private _windowOnError(errorMsg: string, url: string, lineNumber: number) {
    return this.nativeCaller.call("core.log", ["Uncaught Error: " + errorMsg + " in " + url + ", line " + lineNumber])
  }

  private _hookAddEventListener(document: HTMLDocument) {

    const onClickBlankTargetLast = (event: DocumentEventMap["click"]) => {
      /*
      HOT HACK WARNING
      Kitt needs to hook on <a> clicks to provide target="_blank" window opening.
      Unfortunately there are sites which don't trust browser in that respect and
      instantiate their own click listener. The final effect is two windows
      opened on link click. Most prominent example are external facebook links.
      The best we can do is to prevent ourselves when some other listener already
      set the default flag, hence considers the event fully handled.
      In the ideal case, other listeners would get prohibited when we are the first
      in chain, but we can't know what the other handlers would like to do so any
      kind of stop(Immediate)Propagation may be too much of a wrench in the works.

      Ideally we hook on The Real Final Activity, which is window opening,
      and prevent the multiplicity there. But it would require a fragile logic
      of assessing the timing and practical conditions of "multiplicity" in scope
      of one page load, so let's KISS until a worse site malfunction occurs.
      */
      if (event.defaultPrevented) {
        return
      }
      let element: any = event.target
      // the actual anchor element may be up the parent chain
      while (element && !util.isNewWindowAnchor(element)) {
        element = element.parentElement
      }
      if (element) {
        this._windowOpen(element.href, element.target)
        event.preventDefault()
        // stopPropagation was here but it cancels any click handler on whole document.
        // An (occassional) website which doubles the window opening logic is considered
        // a lesser evil (until proven otherwise)
      }
    }

    document.addEventListener("click", onClickBlankTargetLast, false)

    const originalAddEventListener = HTMLDocument.prototype.addEventListener
    HTMLDocument.prototype.addEventListener = function (this: HTMLDocument, type: string, listener: EventListenerOrEventListenerObject, useCapture?: boolean) {
      originalAddEventListener.apply(this, arguments) // propagate the useCapture event
      this.removeEventListener("click", onClickBlankTargetLast)
      originalAddEventListener.call(this, "click", onClickBlankTargetLast, false)
    }
  }

  /**
   Disable the defaut actionSheet when doing a long press
   */
  private _disableDisableDefautActionSheet(document: any) {
    document.body.style.webkitTouchCallout = "none"
    document.documentElement.style.webkitTouchCallout = "none"
  }

  private _performActionsRequiringDocumentElement(document: HTMLDocument) {
    try {
      if (!document.documentElement || !document.body) {
        setTimeout(this._performActionsRequiringDocumentElement.bind(this, document), 0.01)
        return
      }

      this._hookAddEventListener(document)
      this._disableDisableDefautActionSheet(document)
    } catch (e) {
      console.error(e)
    }
  }

  /**
   Because WebKit request 'Accept' header is useless often and webpages regularly
   add/remove script and/or images dynamically, a simple DOM inspection with CSS
   selector is not reliable. Even if it was, the native UI/WKWebView JS eval can't
   inspect subframes. Hence observation of interesting nodes creation is needed
   in mainframe as well as subframes.
  */
  private _observeSourceableNodes(document: HTMLDocument) {
    const observerSourceableNodes = new MutationObserver((mutations) => {
      const nodeNames = ["script", "img"] // only interested in these nodes
      const changes: any[] = []

      const srcEventHandler = (nodeName: string, srcAttrValue: string) => {
        if (srcAttrValue && srcAttrValue.length > 0) {
          changes.push({name: nodeName, src: srcAttrValue})
        }
      }

      mutations.forEach(function(mutation) {
        if (mutation.type === "attributes") {
          // change in attributes of an existing node
          const mutatedNodeName = mutation.target.nodeName.toLowerCase()
          const mutatedAttr = mutation.attributeName
          if (nodeNames.indexOf(mutatedNodeName) !== -1 && mutatedAttr === "src") {
            srcEventHandler(mutatedNodeName, (<any>mutation).target[mutatedAttr])
          }
        } else {
          // iterate potential new nodes
          for (let i = 0; i < mutation.addedNodes.length; i++) {
            const addedNode = mutation.addedNodes[i]
            const addedNodeName = addedNode.nodeName.toLowerCase()
            if (nodeNames.indexOf(addedNodeName) !== -1) {
              srcEventHandler(addedNodeName, (<any>addedNode).src)
            }
          }
        }
      })

      if (changes.length > 0) {
        this.nativeCaller.sendEvent("DOMMutationEvent", changes)
      }
    })

    observerSourceableNodes.observe(document, {
      subtree: true, childList: true, // all mutations to whole document
      attributes: true, attributeFilter: ["src"] // only SCRIPT/IMG
    })
  }

  performActionsRequiringDocumentElement = this._performActionsRequiringDocumentElement
  observeSourceableNodes = this._observeSourceableNodes

  public windowOpen = this._windowOpen.bind(this)
  public windowClose = this._windowClose.bind(this)
  public windowOnError = this._windowOnError.bind(this)
}

