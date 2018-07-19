/**
 * chrome.declarativeWebRequest
 */

import { attachEventToObject } from "./SimpleEvent"
import { IFullKittInterface } from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  const moduleName = "declarativeWebRequest"
  // That's how Chromium does it
  // chrome/renderer/resources/extensions/declarative_webrequest_custom_bindings.js
  const _setupInstance = function(instance: any, parameters: any, typeId: string) {
    for (let key in parameters) {
      if (parameters.hasOwnProperty(key)) {
        instance[key] = parameters[key]
      }
    }
    instance.instanceType = [moduleName, typeId].join(".")
  }
  let impl = {
    onRequest: {
      addRules: function (rules: any[]) {
        api.addRules(rules)
      }
    },
    RequestMatcher: function (parameters: any) {
      _setupInstance(this, parameters, "RequestMatcher")
    },
    CancelRequest: function (parameters: any) {
      _setupInstance(this, parameters, "CancelRequest")
    },
    RedirectRequest: function (parameters: any) {
      _setupInstance(this, parameters, "RedirectRequest")
    },
    RedirectToEmptyDocument: function (parameters: any) {
      _setupInstance(this, parameters, "RedirectToEmptyDocument")
    },
    SendMessageToExtension: function (parameters: any) {
      _setupInstance(this, parameters, "SendMessageToExtension")
    }
  }
  attachEventToObject(impl, api, moduleName, "onMessage")

  return impl
}