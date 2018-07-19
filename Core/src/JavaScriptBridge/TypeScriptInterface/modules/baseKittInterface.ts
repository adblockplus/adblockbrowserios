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
import Caller, {IMessage} from "../bridge/nativeCaller"
import {ICallback} from "../bridge/callbackEntry"

export type IMessage = IMessage
export type Callback<T> = (x: T) => void

export interface IBaseKittInterface {
  lastError: Error | undefined
  xhr(content: any, callback: Callback<IMessage>): void
  console: { log: (...args: any[]) => void }
  sendMessage(extensionId: string, message: any, callback?: Callback<any>): void
  tabsSendMessage(tabId: number, message: any, callback?: Callback<any>): void
  addListener(event: string, parameters: any, handler: Callback<IMessage>): string
  removeListener(callbackId: string, removalFinishedFunction: () => void): void
  respondListenerCallback(response: any, callbackId?: string): void
  getBundleURL(resourcePath: string): void
  autofill: any
}

export default function(nativeCaller: Caller) {

  const api = <IBaseKittInterface> {
    get lastError() {
      return nativeCaller.lastError
    }
  }

  api.xhr = function(content, callback) {
    nativeCaller.call("core.XMLHTTPRequest", [content], {}, callback)
  }

  api.console = {
    log: function(...argsArray: any[]) {
      let message = argsArray.shift() // console method name
      if (argsArray.length === 0) {
        // Chrome behavior: no arguments, do nothing
        return
      }
      for (let arg of argsArray) {
        if (arg === null) {
          arg = "null"
        } else if (typeof arg === "undefined") {
          arg = "undefined"
        } else if (typeof arg === "object") {
          if (arg instanceof RegExp) {
            // this indeed looks silly but i want the condition chain being
            // easily extendable if yet-another case of object would need
            // specific handling. RegExp has toString applied as is, hence
            // no change to the argument.
            arg = arg
          } else if (arg instanceof Error) {
            arg = util.stringifyError(arg)
          } else {
            // default fallback for any object not of particular type
            try {
              // This is what chrome console renders
              arg = util.stringify(arg)
            } catch (e) {
              // Can't serialize, show understandable replacement
              arg = "[Object]"
            }
          }
        }
        // If the message just started, enforce string operation
        // on arg via concatenation with empty string. That way toString()
        // will be always called on arg when it's not a primitive
        // (primarily to cover Function)
        message += " " + arg
      }
      nativeCaller.call("core.log", [message])
    }
  }
  // runtime.sendMessage: from contents script/popup to background script
  // @param targetId extension id, in case it's different than us (NOT IMPLEMENTED)
  // @param message the message parameters object
  // @param callback [optional] response callback from message listener
  api.sendMessage = function(extensionId, message, callback) {
    const name = "runtime.sendMessage"
    if (callback) {
      nativeCaller.call(name, [extensionId, message], {}, function(message) {
        util.invokeOptionalCallback(name, callback, message.data)
      })
    } else {
      nativeCaller.call(name, [extensionId, message])
    }
  }
  // tabs.sendMessage: from background script/popup to content script
  // @tabId target content script tab id
  // @param message the message parameters object
  // @param callback [optional] response callback from message listener
  api.tabsSendMessage = function(tabId, message, callback) {
    const name = "tabs.sendMessage"
    if (callback) {
      nativeCaller.call(name, [tabId, message], {}, function(message) {
        util.invokeOptionalCallback(name, callback, message.data)
      })
    } else {
      nativeCaller.call(name, [tabId, message])
    }
  }
  /**
   Remember a listening handler of particular event.
   @param event event name @see chrome_api for supported values
   @param parameters [optional] extra parameters to the listener
     (is transported to the native code)
   @param handler function(message) called upon event occurence
   @throws StackedError when handlerFn invocation fails
   @return string identifier of the created event listener callback
  */
  api.addListener = function(eventLabel, parameters, handler) {
    parameters = parameters || {};
    (handler as ICallback).persistent = true
    const callbackId = nativeCaller.addCallback(handler as ICallback)

    nativeCaller.call("listenerStorage.add", [eventLabel, parameters, callbackId])

    return callbackId
  }

  api.removeListener = function(callbackId, removalFinishedFunction) {
    nativeCaller.call("listenerStorage.remove", [callbackId], {}, function() {
      nativeCaller.removeCallback(callbackId, removalFinishedFunction)
    })
  }

  api.respondListenerCallback = function(response, callbackId) {
    nativeCaller.call("core.response", [callbackId, response])
  }

  api.getBundleURL = function(resourcePath) {
    if (resourcePath.charAt(0) !== "/") {
      resourcePath = "/" + resourcePath
    }
    return "chrome-extension://" + nativeCaller.extensionId + resourcePath
  }

  // nonstandard, for emulating autofill functionality
  api.autofill = {
    requestAutofillValues: function(extractedForms: any, callback: any) {
      nativeCaller.call("autofill.requestAutofillValues", [JSON.parse(extractedForms)], {}, function(message) {
        // bridged command handler returns it wrapped in "forms" element, unwrap it
        const unwrappedResult = (message.data && message.data.forms) ? message.data.forms : []
        util.invokeOptionalCallback("autofill.requestAutofillValues", callback, unwrappedResult)
      })
    },
    setKeyboardInputSuggestions: function(suggestions: any) {
      nativeCaller.call("autofill.setKeyboardInputSuggestions", [{suggestions: suggestions}])
    },
    clearKeyboardInputSuggestions: function() {
      nativeCaller.call("autofill.clearKeyboardInputSuggestions", [])
    }
  }

  return api
}
