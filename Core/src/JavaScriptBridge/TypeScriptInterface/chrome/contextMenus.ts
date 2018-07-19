/**
 * chrome.contextMenus
 */

import { attachEventToObject } from "./SimpleEvent"
import { IFullKittInterface, Callback } from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  let contextMenus
  contextMenus = {
    create: function (createProperties: any, callback: Callback<any>) {
      return api.contextMenus.create(createProperties, callback)
    },
    update: function (menuItemId: string, updateProperties: any, callback: Callback<any>) {
      api.contextMenus.update(menuItemId, updateProperties, callback)
    },
    remove: function (menuItemId: string, callback: Callback<any>) {
      api.contextMenus.remove(menuItemId, callback)
    },
    removeAll: function (callback: Callback<any>) {
      api.contextMenus.remove(undefined, callback)
    }
  }

  contextMenus = attachEventToObject(contextMenus, api, "contextMenus", "onClicked", (message) => [message.data, {id: message.context.tabId }])

  return contextMenus
}
