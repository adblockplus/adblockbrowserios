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
import { IEventInterface } from "./Event"

class SimpleEvent<K extends string> implements IEventInterface {
  private readonly _listeners: ((...a: any[]) => void)[] = []
  private readonly _eventLabel: string
  private callbackId: string | undefined

  constructor(private api: IBaseKittInterface,
    private moduleName: string,
    private eventName: K,
    private messageTransform: (message: IMessage) => any[] = (message) => [message.data]) {
      this._eventLabel = `${this.moduleName}.${this.eventName}`
  }

  addListener(listener: (...a: any[]) => void) {
    if (this._listeners.length === 0) {
      this.callbackId = this.api.addListener(this._eventLabel, {}, this.eventListener.bind(this))
    }

    this._listeners.push(listener)
  }

  removeListener(handler: (...a: any[]) => void) {
    const index = this._listeners.reduce((result, listener, index) => {
      return listener === handler ? index : result
    }, <number | undefined>undefined)
    if (index) {
      this._listeners.splice(index, 1)
    }

    if (this._listeners.length === 0 && this.callbackId) {
      this.api.removeListener(this.callbackId, () =>
        this.api.console.log("Event", this._eventLabel, "callback", this.callbackId, "removed")
      )
      this.callbackId = undefined
    }
  }

  hasListener(handler: (...a: any[]) => void) {
    return this._listeners.some((listener) => listener === handler)
  }

  private eventListener(message: any) {
    const errorMessages = []
    const parameters = this.messageTransform(message)
    const listeners = this._listeners.slice()

    for (const listener of listeners) {
      try {
        util.tryInvokeCallbackWithArray(this._eventLabel, listener, parameters)
      } catch (e) {
        let error
        if (e instanceof util.AnnotatedError) {
          error = e.error
        } else {
          error = e
        }

        if (error instanceof Error) {
          errorMessages.push(error.message)
        } else {
          errorMessages.push(error.toString() as string)
        }
      }
    }

    if (errorMessages.length > 0) {
      const annotation = `${this._eventLabel} ${JSON.stringify(parameters)}`
      const message = `${errorMessages.length} of ${listeners.length} listeners failed with error: ${JSON.stringify(errorMessages)}`
      throw new util.AnnotatedError(annotation, new Error(message))
    }
  }
}

export let attachEventToObject = <T extends Object, K extends string> (
  obj: T,
  api: IBaseKittInterface,
  moduleName: string,
  eventName: K,
  messageTransform?: (message: IMessage) => any) => {
    (obj as any)[eventName] = new SimpleEvent(api, moduleName, eventName, messageTransform)
    return obj as T & { [k in K] : SimpleEvent<K> }
}

export let eventAttacherFactory = (api: IBaseKittInterface, moduleName: string) => {
    return <T extends Object, K extends string>(obj: T, eventName: K, messageTransform?: (message: IMessage) => any) =>
       attachEventToObject(obj,  api, moduleName, eventName, messageTransform)
}
