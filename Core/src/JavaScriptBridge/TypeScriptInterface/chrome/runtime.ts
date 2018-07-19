/**
 * chrome.runtime
 */

import * as util from "../modules/util"
import { attachEventToObject } from "./Event"
import { IMessage, IBaseKittInterface } from "../modules/baseKittInterface"

export default function (api: IBaseKittInterface) {
  let runtime
  runtime = {
    sendMessage: function (extensionId: any, message: any, responseCallback: any) {
      if (typeof (message) === "function") {
        // extensionId ommited, shift parameters
        responseCallback = message
        message = extensionId
        extensionId = null
      }
      api.sendMessage(extensionId, message, responseCallback)
    },
    getURL: function (path: string) {
      return api.getBundleURL(path)
    },
    // Mock
    onConnect: {
      addListener: function (_: any) {
        console.log("onConnect.addListener is not supported!")
      }
    },
    get lastError() {
      return api.lastError
    }
  }

  let runtimeEventCallbackInvocation = (handler: (handler: (...a: any[]) => any, message: IMessage) => any,
      message: IMessage) => {
    // flag whether listenerCallback can be called after listenerFunc has finished
    let canCallbackAsync = false
    // flag whether listenerCallback was already called for this batch of listeners
    let isCallbackDone = false
    // flag whether listenerFunc is currently running
    let isListenerRunning = false
    const messageSender: any = {
      id: message.context.extensionId
    }
    if (message.context.tab) {
      messageSender.tab = message.context.tab
      messageSender.url = message.context.tab.url
    }

    if (message.context.frame) {
      messageSender.frameId = message.context.frame.frameId
      messageSender.url = message.context.frame.url
    }

    const listenerCallback = function (responseObject: any) {
      if (!isCallbackDone && (isListenerRunning || canCallbackAsync)) {
        // listenerCallback was not called yet and is either called inside listenerFunc
        // or async callback is allowed (in which case it doesn't matter if listenerFunc is running)
        isCallbackDone = true // flag before invoking the callback to prevent race
        api.respondListenerCallback(responseObject, message.context.callbackResponseId)
      } else {
        // What original chrome says
        throw new Error("Could not send response: The chrome.runtime.onMessage listener must return true if you want to send a response after the listener returns.")
      }
    }
    // chrome.runtime.on*.addListener has 3 different callback signatures
    // no parameters: this data is ignored (message.data may be undefined)
    // 1 parameters: the data, message.data has value
    // 3 parameters: onMessage[External] - as defined here
    isListenerRunning = true
    const listenerWantsAsyncCallback = util.tryInvokeCallbackWithArray(
      "runtime.onMessage listener",
      handler,
      [message.data, messageSender, listenerCallback])
    isListenerRunning = false
    // listenerFunc may not be returning anything
    if (typeof listenerWantsAsyncCallback !== "undefined") {
      canCallbackAsync = listenerWantsAsyncCallback
    }
  }

  runtime = attachEventToObject(runtime, api, "runtime", "onMessage", runtimeEventCallbackInvocation)
  return runtime
}
