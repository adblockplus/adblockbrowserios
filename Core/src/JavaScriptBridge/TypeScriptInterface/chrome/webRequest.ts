/**
 * chrome.webRequest
 */

import { eventAttacherFactory } from "./Event"
import { IFullKittInterface } from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  let webRequest
  webRequest = {
    handlerBehaviorChanged: function(callbackFn: () => void) {
      api.webRequest.handlerBehaviorChanged(callbackFn)
    }
  }

  const webRequestEventAttacher = eventAttacherFactory(api, "webRequest", function(listenerParams) {
    // 0: request filter
    // 1: opt_extraInfoSpec
    return {filter: listenerParams[0], extraInfo: listenerParams[1]}
  })

  webRequest = webRequestEventAttacher(webRequest, "onBeforeRequest")
  webRequest = webRequestEventAttacher(webRequest, "onBeforeSendHeaders")
  webRequest = webRequestEventAttacher(webRequest, "onHeadersReceived")
  return webRequest
}
