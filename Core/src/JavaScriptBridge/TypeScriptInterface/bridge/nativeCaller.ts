import * as util from "../modules/util"
import { IContext, IMessage, ICallback, CallbackEntry } from "./callbackEntry"


const CALLBACK_TOKEN_LENGTH = 10

interface KittWindow extends Window {
  KittEntryPoint?: (name: string, value: any) => string
  webkit?: {
    messageHandlers?: {
      switchboard?: {
        postMessage(_: any): void
      }
    }
  }
}

export type IMessage = IMessage

export default class Caller {
  private readonly frameId: string

  constructor(globalContext: Window,
              public readonly extensionId: string,
              private readonly callbackEntry: CallbackEntry,
              private readonly tabId?: string) {
    this.frameId = this.callbackEntry.frameId
  }

  private constructBridgeMessage(data: any, context?: IContext, raw?: any): IMessage & { raw?: any, frameURL?: string } {
    // the outgoing message consists of
    // data: the parameter object of the function
    // context: call context
    // - extensionId always
    // - response_id when call is a response to another call (NOT callback!)
    // - callbackId, token in case of defined callback
    // - persistent flag optional in case of callback
    // construct message going out to native side
    const message = {
      data,
      context: context || {},
      raw
    }
    if (this.extensionId) {
      message.context.extensionId = this.extensionId
    }
    if (this.tabId) {
      message.context.tabId = this.tabId
    }
    if (this.frameId) {
      message.context.frameId = this.frameId
    }
    return message
  }

  private requestNativeBridge(funcName: string, message: IMessage & { raw?: any }) {
    // NOTE: this stringify is needed to make the transported object URI-encodable.
    // But it also means that if there is already a string with quotes somewhere
    // in the object (like already stringified object), the quotes will get escaped.
    // These quotes must get unescaped on the native side where applicable
    // (like in XmlHttpRequest handling)

    const kittWindow: KittWindow = window
    const frameURL = window.location.href
    const webkit = kittWindow.webkit

    if (webkit && webkit.messageHandlers && webkit.messageHandlers.switchboard) {
      const message1 = util.stringify({ "c": message.context, "d": message.data })
      webkit.messageHandlers.switchboard.postMessage({ "name": funcName, "message": message1, "raw": message.raw, frameURL })
      return
    }

    if (kittWindow.KittEntryPoint) {
      // We have to split message, because the raw part is not going to be deserialized on native side.
      const message2 = util.stringify({ "c": message.context, "d": message.data })
      // This callback must not be executed using function setTimeout, otherwise
      // it takes one 1s, before this function reaches objective-C part.
      kittWindow.KittEntryPoint(funcName, { "message": message2, "raw": message.raw, frameURL })
      return
    }

    throw new Error("Failed to bridge the message to the native side")
  }

  callSync(funcName: string, parameters: any) {
    const kittWindow: KittWindow = window
    const { context, data } = this.constructBridgeMessage(parameters, undefined, undefined)
    const message = {
      c: context, d: data, frameURL: window.location.href
    }
    if (kittWindow.KittEntryPoint) {
      return kittWindow.KittEntryPoint(funcName, message)
    } else {
      return ""
    }
  }

  callNativeWithRawData(funcName: string, obj: any, raw: any, context: IContext | {}, callback?: (x: any) => any, persistent = false): string | undefined {
    const message = this.constructBridgeMessage(obj, context, raw)
    let callbackId: string | undefined
    if (typeof callback !== "undefined") {
      // security token checked by created callback function before going
      // into the actual client code
      message.context.token = util.makeId(CALLBACK_TOKEN_LENGTH)

      let cb: any = (nativeMessage: IMessage) => {
        if (nativeMessage.context.token === message.context.token) {
          return callback(nativeMessage)
        }
      }
      cb.persistent = persistent

      callbackId = this.callbackEntry.addCallback(cb)
      message.context.callbackId = callbackId
    }
    this.requestNativeBridge(funcName, message)
    return callbackId
  }

  callNative(funcName: string, obj: any[], context: IContext = {}, callback?: ((x: IMessage) => any), persistent = false) {
    return this.callNativeWithRawData(funcName, obj, undefined, context, callback, persistent)
  }

  sendEvent(name: string, state: any) {
    return this.callNativeWithRawData("JSContextEvent", null, { type: name, state }, {}, undefined, false)
  }

  addCallback(callback: ICallback) {
    return this.callbackEntry.addCallback(callback)
  }

  // The only way to remove persistent callbacks
  removeCallback(callbackId: string, completion: () => void) {
    this.callbackEntry.removeCallback(callbackId)
    if (completion) {
      completion()
    }
  }

  get lastError() {
    return this.callbackEntry.lastError
  }

  callWithRawData = this.callNativeWithRawData
  call = this.callNative
}
