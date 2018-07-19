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
 * Replacer of window.console object
 * patch() replaces directly, calls the original implementation too
 * render() creates a compatible object suitable for IIFE mocking (content scripts).
 *
 */
import {IBaseKittInterface} from "../modules/baseKittInterface"

const methods = ("assert clear count debug dir dirxml error exception group " +
  "groupCollapsed groupEnd info log markTimeline profile profileEnd " +
  "table time timeEnd timeStamp trace warn").split(" ")

export default class {

  constructor(private api: IBaseKittInterface) {
  }

  private callApi(scope: any, method: string, args: any) {
    const argsArray = Array.prototype.slice.call(args)
    argsArray.unshift(method)
    this.api.console.log.apply(scope, argsArray)
  }

  patch(globalScopeConsole: Console & {[s: string]: any}) {
    for (let method of methods) {
      // save away the reference before replacing it
      const _originalFunction = globalScopeConsole[method]
      const call = this.callApi.bind(this, globalScopeConsole, method)
      globalScopeConsole[method] = function() {
        call(arguments)
        return _originalFunction.apply(globalScopeConsole, arguments)
      }
    }
  }

  render() {
    const impl: {[s: string]: any} = {}
    for (let method of methods) {
      const call = this.callApi.bind(this, this, method)
      impl[method] = function() {
        call(arguments)
      }
    }
    return impl
  }
}
