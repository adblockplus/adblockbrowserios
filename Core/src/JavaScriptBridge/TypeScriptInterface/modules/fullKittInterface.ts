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
import BaseKittInterface, {IBaseKittInterface, Callback, IMessage} from "./baseKittInterface"

export type IMessage = IMessage
export type Callback<T> = Callback<T>

export interface IFullKittInterface extends IBaseKittInterface {
  addRules(rules: any[]): void
  i18n: { getMessage: (messageName: string, substitutions?: string[]) => any }
  tabs: {
    get: (tabId: number, callback: Callback<any>) => void
    query: (queryInfo: any, callback: Callback<any>) => void
    update: (targetTabId: number, properties: any, callback?: Callback<any>) => void
    create: (properties: any, callback?: Callback<any>) => void
    remove: (tabIds: number[], callback?: Callback<any>) => void
  }
  contextMenus: {
    create: (createProperties: any, callback: Callback<any>) => void
    update: (menuId: string, updateProperties: any, callback: Callback<any>) => void
    remove: (menuId: string | undefined, callback: Callback<any>) => void
  }
  storage: {
    get: (area: string, keys: string[], callback: Callback<any>) => void
    set: (area: string, items: {[s: string]: any}, callback?: Callback<any>) => void
    remove: (area: string, keys: string[], callback?: () => void) => void
    clear: (area: string, callback?: () => void) => void
  }
  browserAction: {
    setIcon: (details: any, callback: () => void) => void
  }
  webRequest: {
    handlerBehaviorChanged: (callback: () => void) => void
  }
  windows: {
    getAll: (getInfo: any, callback: Callback<any>) => void
    getLastFocused: (getInfo: any, callback: Callback<any>) => void
  }
  webNavigation: {
    getFrame: (details: any, callback: Callback<any>) => void
    getAllFrames: (details: any, callback: Callback<any>) => void
  }
}

export default function(nativeCaller: Caller) {

  // reexport all members of baseKittInterface
  const api = <IFullKittInterface> BaseKittInterface(nativeCaller)

  // Add request filtering rule to the native code
  // @see declarativeWebRequest
  // @param apiId the id of extension which is adding the rules
  // @param rules array of ContentRule objects
  api.addRules = function(rules) {
    nativeCaller.call("core.addWebRequestRules", [rules])
  }

  const extensionMessageTranslations = (<any>window).extensionMessageTranslations
  delete (<any>window).extensionMessageTranslations

  let i18n_getMessageItem: (x: string, y?: string[]) => undefined | {message: string, placeholders: any}

  if (extensionMessageTranslations) {
    i18n_getMessageItem = function (messageName) {
      return extensionMessageTranslations[messageName]
    }
  } else {
    i18n_getMessageItem = function (messageName, substitutions) {
      return <any>nativeCaller.callSync("i18n.getMessage", {messageName: messageName})
    }
  }

  const substitutionToIndexMap: {[s: string]: number} = {}

  for (let i = 1; i < 10; i++) {
    substitutionToIndexMap["$" + i] = i - 1
  }

  api.i18n = {
    getMessage: function(messageName, substitutions) {
      /*
       If the message is missing, this method returns an empty string ('').
       If some other error occurs, it should throw exception.
      */
      if (arguments.length === 0) {
        return ""
      }

      if (!util.isString(messageName)) {
        return ""
      }

      if (arguments.length === 1 || !substitutions) {
        substitutions = []
      }

      if (substitutions.length > 9) {
        return
      }

      // can only work with strings
      substitutions = substitutions.map(function(s) {
        return util.isString(s) ? s : ""
      })

      const item = i18n_getMessageItem(messageName)

      if (!item) {
        return ""
      }

      let i18n_message = item.message

      if (i18n_message && item.placeholders) {
        const regExp = new RegExp("\\$([^\\$]*)\\$", "ig")

        const placeholders: {[s: string]: {content: string}} = {}
        for (let key in item.placeholders) {
          placeholders[key.toLowerCase()] = item.placeholders[key]
        }

        const _substitutions = substitutions
        i18n_message = i18n_message.replace(regExp, function(token, key) {
          key = key.toLowerCase()
          if (key in placeholders) {
            const content = placeholders[key].content
            if (content in substitutionToIndexMap) {
              return _substitutions[substitutionToIndexMap[content]] || ""
            } else {
              return content
            }
          } else {
            return ""
          }
        })
      }

      return i18n_message || ""
    }
  }

  api.tabs = {
    // @see chrome.tabs.get
    get: function(tabId, callback) {
      nativeCaller.call("tabs.get", [tabId], {}, function(message) {
        util.invokeOptionalCallback("tabs.get", callback, message.data)
      })
    },
    // @see chrome.tabs.query
    query: function(queryInfo, callback) {
      nativeCaller.call("tabs.query", [queryInfo], {}, function(message) {
        util.invokeOptionalCallback("tabs.query", callback, message.data)
      })
    },
    // @see chrome.tabs.update
    update: function(targetTabId, properties, callback) {
      nativeCaller.call("tabs.update", [targetTabId, properties], {}, function(message) {
        util.invokeOptionalCallback("tabs.update", callback, message.data)
      })
    },
    create: function(properties, callback) {
      nativeCaller.call("tabs.create", [properties], {}, function(message) {
        util.invokeOptionalCallback("tabs.create", callback, message.data)
      })
    },
    remove: function(tabIds, callback) {
      nativeCaller.call("tabs.remove", [tabIds], {}, function(message) {
        util.invokeOptionalCallback("tabs.remove", callback, message.data)
      })
    }
  }

  const CONTEXT_MENU_ID_LENGTH = 5
  // Map of arrays of context menu item ids, key is extension id
  let _contextMenuItems: {[s: string]: any} = {}
  let extensionId = nativeCaller.extensionId

  api.contextMenus = {
    create : function(createProperties, callback) {
      const newMenuId = util.makeId(CONTEXT_MENU_ID_LENGTH)
      if (typeof _contextMenuItems[extensionId] === "undefined") {
        _contextMenuItems[extensionId] = [newMenuId]
      } else {
        _contextMenuItems[extensionId].push(newMenuId)
      }
      nativeCaller.call("contextMenus.create", [newMenuId, createProperties], {}, callback)
      return newMenuId
    },
    update : function(menuId, updateProperties, callback) {
      const items = _contextMenuItems[extensionId]
      if (typeof items === "undefined" || items.indexOf(menuId) === -1) {
        throw new Error("Context menu " + menuId + " for ext id " + extensionId + " not found for update")
      }
      nativeCaller.call("contextMenus.update", [menuId, updateProperties], {}, callback)
    },
    remove : function(menuId, callback) {
      // First param is a callback, menuId was omitted
      // All menus for extension id are to be deleted
      const isRemoveAll = (typeof menuId === "undefined")
      // default list of menu items is all items for given extension id
      let items = _contextMenuItems[extensionId]
      if (typeof items === "undefined") {
        if (isRemoveAll) {
          // removeAll called while no menus are defined
          // Do nothing but obey asynchronicity
          setTimeout(callback, 0)
        } else {
          // specific removal, some items must exist
          throw new Error("No context menus for ext id " + extensionId)
        }
      }
      const callbackLocal = callback
      if (isRemoveAll) {
        delete _contextMenuItems[extensionId]
      } else {
        const specificItemIndex = items.indexOf(menuId)
        if (specificItemIndex === -1) {
          throw new Error("Context menu " + menuId + " for ext id " + extensionId + " not found for removal")
        }
        // create a new array of single item
        items = [items[specificItemIndex]]
        // and delete the item from the local map
        delete _contextMenuItems[extensionId][specificItemIndex]
      }
      nativeCaller.call("contextMenus.remove", [items], {}, callbackLocal)
    }
  }

  api.storage = {
    get: function (area, keys, callback) {
      nativeCaller.call("storage.get", [keys], {area: area}, function (answer) {
        util.invokeOptionalCallback("storage.get", callback, answer.data)
      })
    },
    set: function (area, items, callback) {
      nativeCaller.callWithRawData("storage.set", null, [items], {area: area}, function (answer) {
        util.invokeOptionalCallbackWithArray("storage.set", callback)
      })
    },
    remove: function (area, keys, callback) {
      nativeCaller.call("storage.remove", [keys], {area: area}, function (answer) {
        util.invokeOptionalCallbackWithArray("storage.remove", callback)
      })
    },
    clear: function (area, callback) {
      nativeCaller.call("storage.clear", [], {area: area}, function (answer) {
        util.invokeOptionalCallbackWithArray("storage.clear", callback)
      })
    }
  }

  api.browserAction = {
    setIcon: function(details, callback) {
      if (!details.path) {
          throw new Error("Only details.path supported in browserAction.setIcon")
      }
      // @todo make this optional callback wrapping generic, because it should be applied
      // to any API function which has optional callback
      let callbackImpl: ((x: any) => void) | undefined
      if (callback) {
        callbackImpl = function() {
          util.invokeOptionalCallbackWithArray("browserAction.setIcon", callback)
        }
      }
      nativeCaller.call("browserAction.setIcon", [details], {}, callbackImpl)
    }
  }

  api.webRequest = {
    handlerBehaviorChanged: function(callback) {
      nativeCaller.call("webRequest.handlerBehaviorChanged", [], {}, function() {
        util.invokeOptionalCallbackWithArray("webRequest.handlerBehaviorChanged", callback)
      })
    }
  }

  api.windows = {
    getAll: function(getInfo, callback) {
      nativeCaller.call("windows.getAll", [getInfo], {}, function(answer) {
        util.invokeOptionalCallback("windows.getAll", callback, answer.data)
      })
    },
    getLastFocused: function(getInfo, callback) {
      nativeCaller.call("windows.getLastFocused", [getInfo], {}, function(answer) {
        util.invokeOptionalCallback("windows.getLastFocused", callback, answer.data)
      })
    }
  }

  api.webNavigation = {
    getFrame: function(details, callback) {
      nativeCaller.call("webNavigation.getFrame", [details], {}, function(answer) {
        util.invokeOptionalCallback("webNavigation.getFrame", callback, answer.data)
      })
    },
    getAllFrames: function(details, callback) {
      nativeCaller.call("webNavigation.getAllFrames", [details], {}, function(answer) {
        util.invokeOptionalCallback("webNavigation.getAllFrames", callback, answer.data)
      })
    }
  }

  return api
}
