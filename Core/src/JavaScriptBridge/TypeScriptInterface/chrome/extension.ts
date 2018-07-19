/**
 * chrome.extension
 */

import {IBaseKittInterface} from "../modules/baseKittInterface"

export default function (api: IBaseKittInterface) {
  return {
    getURL: function (path: string) {
      return api.getBundleURL(path)
    },
    getBackgroundPage: function (_: string) {
      console.log("getBackgroundPage is not supported")
      return {}
    }
  }
}