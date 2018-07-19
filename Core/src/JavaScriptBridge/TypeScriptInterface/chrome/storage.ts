/**
 * chrome.storage
 */

import { attachEventToObject } from "./SimpleEvent"
import { IFullKittInterface, Callback } from "../modules/fullKittInterface"
import { IMessage } from "../modules/baseKittInterface"

export default function (api: IFullKittInterface) {
  const StorageArea = function (area: string) {

    const keysToArray = function (keys: string | string[] | {[s: string]: any}) {
      let _keys
      if (typeof keys === "string" || keys instanceof String) {
        _keys = [keys.toString()]
      } else if (keys instanceof Array) {
        _keys = keys
      } else {
        _keys = []
        for (let key in keys) {
          _keys.push(key)
        }
      }
      return _keys
    }

    // *AdBlock Plus performance improvement*
    // Caches is used for JS bridge requests. It is expected that,
    // chrome storage will not be accessed from outside.
    // Currently, this feature is needed for ABP browser.
    const cache: {[k: string]: any} = {}

    return {
      get: function (keys: string | string[] | {[s: string]: any}, callback: Callback<any>) {
        const results: typeof cache = {}
        const query: string[] = []
        for (let key of keysToArray(keys)) {
          if (typeof cache[key] !== "undefined") {
            results[key] = cache[key]
          } else {
            query.push(key)
          }
        }

        if (query.length === 0) {
          callback(results)
          return
        }

        api.storage.get(area, query, function (response) {
          for (let key in response) {
            cache[key] = JSON.parse(response[key])
            results[key] = cache[key]
          }
          callback(results)
        })
      },
      set: function (items: {[s: string]: any}, callback?: Callback<any>) {
        const results: {[s: string]: string} = {}
        for (let key in items) {
          // The result of JSON.parse should stored in cache instead of raw value, since
          // this equation holds JSON.parse(JSON.stringify(item)) != item. But due to performance reason
          // we are not going to that.
          cache[key] = items[key]
          results[key] = JSON.stringify(items[key])
        }
        api.storage.set(area, results, callback)
      },
      remove: function (keys: string | string[], callback?: () => void) {
        const _keys = keys instanceof Array ? keys : [keys]
        api.storage.remove(area, _keys, function () {
          for (let key of _keys) {
            delete cache[key]
          }
          if (callback) {
            callback()
          }
        })
      },
      clear: function (callback?: () => void) {
        api.storage.clear(area, function () {
          for (let key in cache) {
            delete cache[key]
          }
          if (callback) {
            callback()
          }
        })
      }
    }
  }

  let storage
  storage = {
    sync: StorageArea("sync"),
    local: StorageArea("local")
  }


  let changedEventMessageTransform = function(message: IMessage) {
    for (let key in message.data.changes) {
      const storageChange = message.data.changes[key]
      if (storageChange.oldValue) {
        storageChange.oldValue = JSON.parse(storageChange.oldValue)
      }
      if (storageChange.newValue) {
        storageChange.newValue = JSON.parse(storageChange.newValue)
      }
    }
    // https://developer.chrome.com/extensions/storage#event-onChanged
    return [message.data.changes, message.data.areaName]
  }

  storage = attachEventToObject(storage, api, "storage", "onChanged", changedEventMessageTransform)
  return storage
}
