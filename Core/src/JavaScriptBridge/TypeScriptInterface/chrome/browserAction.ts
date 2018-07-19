/**
 * chrome.browserAction
 */

import { attachEventToObject } from "./SimpleEvent"
import { IFullKittInterface } from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  let browserAction
  browserAction = {
    setIcon: function(details: any, callback: () => void) {
      api.browserAction.setIcon(details, callback)
    },
    setBadge: function () {
      console.log("setBadge is not supported")
    },
    setBadgeText: function () {
      api.console.log("setBadgeText is not supported")
    },
    setBadgeBackgroundColor: function () {
      api.console.log("setBadgeBackgroundColor is not supported")
    }
  }

  browserAction = attachEventToObject(browserAction, api, "browserAction", "onClicked")
  return browserAction
}
