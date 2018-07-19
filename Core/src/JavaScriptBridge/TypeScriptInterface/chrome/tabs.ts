/**
 * chrome.tabs
 */

import { eventAttacherFactory } from "./SimpleEvent"
import { IFullKittInterface, Callback } from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  let tabs
  tabs = {
    get: function(tabId: number, callback: Callback<any>) {
      api.tabs.get(tabId, callback)
    },
    query: function (queryInfo: any, callback: Callback<any>) {
      api.tabs.query(queryInfo, callback)
    },
    sendMessage: function (tabId: number, message: any, responseCallback?: (x: any) => void) {
      let typeTabId = typeof tabId
      if (typeTabId !== "number") {
        if (tabId === null) {
          typeTabId = "undefined"
        }
        throw new Error("Invocation of form tabs.sendMessage(" + typeTabId + ", " +
                        typeof message + ", " + typeof responseCallback + ") " +
                        "doesn't match definition tabs.sendMessage(integer tabId, " +
                        "any message, optional function responseCallback)")
      }
      api.tabsSendMessage(tabId, message, responseCallback)
    },
    update: function (tabId: number, properties: any, callback?: Callback<any>) {
      api.tabs.update(tabId, properties, callback)
    },
    create: function(createProperties: any, callback?: Callback<any>) {
      api.tabs.create(createProperties, callback)
    },
    remove: function(tabIds: number[], callback?: Callback<any>) {
      api.tabs.remove(tabIds, callback)
    }
  }
  const tabsEventAttacher = eventAttacherFactory(api, "tabs")
  tabs = tabsEventAttacher(tabs, "onCreated")

  // ^^^ no transform, message.data is the Tab object itself
  tabs = tabsEventAttacher(tabs, "onUpdated", function(msg) {
    return [msg.data.tab.id, msg.data.changeInfo, msg.data.tab]
  })

  tabs = tabsEventAttacher(tabs, "onActivated", function(msg) {
    // accept simple tab object to simplify native bridge,
    // construct the expected activeInfo here
    return [{tabId: msg.data.id, windowId: msg.data.windowId}]
  })

  tabs = tabsEventAttacher(tabs, "onRemoved", function(msg) {
    // accept simple tab object to simplify native bridge,
    // construct the expected removeInfo here
    return [msg.data.id, {
              windowId: msg.data.windowId,
              isWindowClosing: false
            }]
    // Kitt has only one window and that is never closed explicitly
    // unless app is being shut down completely (including these listeners)
  })

  tabs = tabsEventAttacher(tabs, "onReplaced")

  tabs = tabsEventAttacher(tabs, "onMoved", function(msg) {
    return [msg.data.id, {windowId: msg.data.windowId,
      fromIndex: msg.data.fromIndex,
      toIndex: msg.data.toIndex}]
  })

  return tabs
}
