/**
 * chrome.windows
 */

import {IFullKittInterface} from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  return {
    getAll: api.windows.getAll,
    getLastFocused: api.windows.getLastFocused,
    onFocusChanged: {
      addListener: function(_: any) {
        // dummy impl
        // Kitt has only one "window" and focus never changes
      }
    }
  }
}
