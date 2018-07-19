import * as util from "../modules/util"

export interface IContext {
  extensionId?: string
  frameId?: string
  callbackId?: string
  callbackResponseId?: string
  token?: string
  lastError?: Error | undefined
  area?: string

  tabId?: number | string
  tab?: any
  frame?: any
}

export interface IMessage {
  context: IContext
  data: any
}

export type ICallback = ((x: IMessage) => any) & {persistent: boolean}

export class CallbackEntry {
  public readonly frameId = util.makeId(10)
  private readonly idToCallbacks: {[callbackId: string]: ICallback} = {}
  private readonly subframes: {[s: string]: Window} = {}
  private captureLastError: Error | undefined

  constructor() {
    // needs to be bound, this function is invoked on a native side "per partes"
    this.invoke = this.invoke.bind(this)
  }

  get lastError() {
    return this.captureLastError
  }

  addSubframe(frameId: string, frameWindow: Window) {
    this.subframes[frameId] = frameWindow
  }

  private generateCallbackId() {
    return util.makeId(5)
  }

  addCallback(callback: ICallback) {
      let callbackId = this.generateCallbackId()

      this.idToCallbacks[callbackId] = callback
      return callbackId
  }

  removeCallback(callbackId: string) {
    delete this.idToCallbacks[callbackId]
  }

  private invokeInCurrentFrame(nativeMessage: IMessage, callbackId: string) {
    const callbackObject = this.idToCallbacks[callbackId]

    if (typeof callbackObject === "undefined") {
      throw new Error("Calback id " + callbackId + " undefined in context")
    }

    let callbackRetval: any
    try {
      // Last error exposed only during execution of callback function
      this.captureLastError = nativeMessage.context.lastError
      callbackRetval = callbackObject(nativeMessage)
    } finally {
      this.captureLastError = undefined

      if (!callbackObject.persistent) {
        delete this.idToCallbacks[callbackId]
      }
    }

    // stringByEvaluatingJavascript understands only string as return value
    if (typeof callbackRetval === "undefined") {
      // callback did not return anything
      // so give back the original callback id as an ok flag
      callbackRetval = callbackId
    } else {
      // stringified return object, whatever that is
      callbackRetval = util.stringify(callbackRetval)
    }

    return callbackRetval
  }

  invoke(nativeMessage: IMessage) {
    try {
      const callbackId = nativeMessage.context.callbackId

      if (typeof callbackId === "undefined") {
        throw new Error("No calback id in context parameter")
      }

      const messageFrameId = nativeMessage.context.frameId

      if (typeof messageFrameId !== "undefined" && messageFrameId !== this.frameId) {
        const frameWindow = this.subframes[messageFrameId]
        if (typeof frameWindow === "undefined") {
          throw new Error("No frame window")
        }
        const message = {
          context: "KittCore:invoke",
          message: nativeMessage
        }
        frameWindow.postMessage(message, "*")
        return callbackId
      }

      return this.invokeInCurrentFrame(nativeMessage, callbackId)
    } catch (e) {
      // any other return value means error, so give stringified exception
      // with an unique and recognizable prefix
      return "ERRORSTACKTRACE" + util.stringifyError(e)
    }
  }
}

export function setUpMessageForwardingBetweenFrames(callbackEntry: CallbackEntry, window: Window) {
  const isMainFrame = window.top === window.self
  if (isMainFrame) {
    window.addEventListener("message", (event) => {
      const frameWindow = event.source
      const data = event.data

      if (!(data && data.context === "KittCore:registerSubframe")) {
        return
      }

      callbackEntry.addSubframe(data.frameId, frameWindow)
    }, false)
  } else {
    window.addEventListener("message", (event) => {
      const data = event.data

      if (!(data && data.context === "KittCore:invoke")) {
        return
      }
      callbackEntry.invoke(data.message)

    }, false)

    const mainframeRegistrationMessage = {
      context: "KittCore:registerSubframe",
      frameId: callbackEntry.frameId
    }
    window.top.postMessage(mainframeRegistrationMessage, "*")
  }
}
