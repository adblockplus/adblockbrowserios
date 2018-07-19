/**
 * chrome.webNavigation
 */

import { eventAttacherFactory } from "./Event"
import { IFullKittInterface } from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  let webNavigation
  webNavigation = {
    getFrame: api.webNavigation.getFrame,
    getAllFrames: api.webNavigation.getAllFrames
  }
  const webNavigationEventAttacher = eventAttacherFactory(api, "webNavigation")
  webNavigation = webNavigationEventAttacher(webNavigation, "onCreatedNavigationTarget")
  webNavigation = webNavigationEventAttacher(webNavigation, "onBeforeNavigate")
  webNavigation = webNavigationEventAttacher(webNavigation, "onCommitted")
  webNavigation = webNavigationEventAttacher(webNavigation, "onCompleted")
  return webNavigation
}
