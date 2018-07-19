/**
A concept of listenable Event to generate an object with
Chrome-compatible functions which is appendable to an existing Chrome API coverage object.
someChromeModule {
  onSomeModuleEvent {
    addListener: function(handlerFn, ...)
    hasListener: function(handlerFn)
    removeListener: function(handlerFn)
  }
}
*/

import * as util from "../modules/util"
import { IBaseKittInterface, IMessage } from "../modules/baseKittInterface"

export interface IEventInterface {
  addListener: (listener: (...a: any[]) => void, ...args: any[]) => void
  removeListener: (listener: (...a: any[]) => void) => void
  hasListener: (listener: (...a: any[]) => void) => void
}

class Event<K extends string> implements IEventInterface {
  private readonly _listeners: {callback: (...a: any[]) => any, callbackId: string}[] = []
  private readonly callbackWrapper: (callback: (...a: any[]) => any, message: IMessage) => any
  private readonly _eventLabel: string

  constructor(private api: IBaseKittInterface,
    private moduleName: string,
    private eventName: K,
    callbackWrapper?: (callback: (...a: any[]) => void, message: IMessage) => any,
    private filterTransform?: (_: any[]) => any,
    private messageTransform: (message: IMessage) => any = (message) => [message.data]) {

      this._eventLabel = [this.moduleName, this.eventName].join(".") // for logging

      if (typeof callbackWrapper === "undefined") {
        this.callbackWrapper = (callback, message) =>
          util.tryInvokeCallbackWithArray(this._eventLabel, callback, this.messageTransform(message))
      } else {
        this.callbackWrapper = callbackWrapper
      }
  }

  addListener(listener: (...a: any[]) => void, ...args: any[]) {
    let eventFilterObject: any
    if (typeof this.filterTransform !== "undefined") {
      eventFilterObject = this.filterTransform(args)
    } else {
      eventFilterObject = args.length > 1 ? args[1] : {}
    }

    const callbackId = this.api.addListener(this._eventLabel, eventFilterObject,
      (message) => this.callbackWrapper(listener, message))

    this._listeners.push({
      callback: listener,
      callbackId: callbackId
    })
  }

  removeListener(handler: (...a: any[]) => void) {
    const index = this._listeners.reduce((result, listener, index) => {
      return listener.callback === handler ? index : result
    }, <number | undefined>undefined)
    if (index) {
      const listener = this._listeners[index]
      this._listeners.splice(index, 1)
      this.api.removeListener(listener.callbackId, () =>
        this.api.console.log("Event", this._eventLabel, "callback", listener.callbackId, "removed")
      )
    }
  }

  hasListener(handler: (...a: any[]) => void) {
    return this._listeners.some((listener) => listener.callback === handler)
  }
}

export let attachEventToObject = <T extends Object, K extends string> (
  obj: T,
  api: IBaseKittInterface,
  moduleName: string,
  eventName: K,
  callbackWrapper?: (callback: (...a: any[]) => any, message: IMessage) => any,
  filterTransform?: (_: any[]) => any,
  messageTransform?: (message: IMessage) => any) => {
    (obj as any)[eventName] = new Event(api, moduleName, eventName, callbackWrapper, filterTransform, messageTransform)
    return obj as T & { [k in K] : Event<K> }
}

export let eventAttacherFactory = (api: IBaseKittInterface,
    moduleName: string,
    filterTransform?: (x: any[]) => any,
    callbackWrapper?: (callback: (...a: any[]) => any, message: IMessage) => any) => {
      return <T extends Object, K extends string>(obj: T, eventName: K, messageTransform?: (message: IMessage) => any) =>
         attachEventToObject(obj,  api, moduleName, eventName, callbackWrapper, filterTransform, messageTransform)
}
