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
 *
 * @param annotation string describing the origin of error
 * @param error the created exception
 */
export class AnnotatedError {
  constructor(public readonly annotation: string, public readonly error: any) {
  }
}

// Must recreate object with explicit iteration of property names
// because Error has unpredictable enumerability out of the box
function stringifiableError(e: any) {
  const result: any = {}
  if (typeof e === "undefined") {
    return result
  }
  if (e.annotation) { // TODO WTF e instanceof AnnotatedError doesn't work??
    result.annotation = e.annotation
    e = e.error
  }
  const ownProperties = Object.getOwnPropertyNames(e)
  for (let idx in ownProperties) {
    let property = ownProperties[idx]
    result[property] = e[property]
  }
  return result
}

// Get a clean unhacked JSON.stringify as soon as this injection is executed
const cleanStringify: (x: any) => string = (function(window: any) {
  return window.JSON.stringify
}(window))

export const stringify = cleanStringify

export const stringifyError = (error: any) => {
  return cleanStringify(stringifiableError(error))
}

export const isString = (s: any): s is string => {
  return typeof s === "string" || s instanceof String
}

export const makeId = (len: number) => {
  const possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  let ret = ""
  for (let i = 0; i < len; i++) {
    ret += possible.charAt(Math.floor(Math.random() * possible.length))
  }
  return ret
}

// When a callback to actual user scripts throws an exception,
// it gets bubbled up to native JS eval, but there is no knowledge
// about which callback has thrown it
// (UIWebView does not give lineNumber, stack, etc.)
// This wrapper gives at least some hint by allowing to prepend
// a custom string.
// @param info a string describing the caller context
// @param callback the actual function to call
// @param ... optional parameters for the callback
// @return the result of call if successful
// @throws an exception with message composed of context info
// and the wrapped exception
export const invokeOptionalCallbackWithArray = <R>(info: string, callback?: (...a: any[]) => R, ...args: any[]) => {
  if (!callback) {
    return
  } else {
    return <R>tryInvokeCallbackWithArray(info, callback, args)
  }
}

// @param params expected to be an Array already
// Can't be merged with the function above to make an universal parameter recognition
// because there is no difference between a single Array arg and args already in an Array
export const tryInvokeCallbackWithArray = <R>(info: string, callback: (...a: any[]) => R, argsArray: any[]) => {
  if (!(argsArray instanceof Array)) {
    throw new Error("tryInvokeCallbackWithArray parameter isn't an Array")
  }
  try {
    return <R>callback.apply(undefined, argsArray)
  } catch (e) {
    throw new AnnotatedError(info + " " + JSON.stringify(argsArray), e)
  }
}

export const invokeOptionalCallback = <T>(info: string, callback: ((t: T) => void) | undefined, t: T) => {
  if (!callback) {
    return
  }
  try {
    callback(t)
  } catch (e) {
    throw new AnnotatedError(info + " " + JSON.stringify(t), e)
  }
}

export const isNewWindowAnchor = (eventTarget: any) => {
  return (eventTarget.tagName.toLowerCase() === "a") &&
          eventTarget.hasAttribute("href") &&
          eventTarget.hasAttribute("target") &&
          (eventTarget.target === "_blank")
}
