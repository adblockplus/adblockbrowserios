/**
 * chrome.i18n
 */

import {IFullKittInterface} from "../modules/fullKittInterface"

export default function (api: IFullKittInterface) {
  return {
    getMessage: function(messageName: string, substitutions?: string[]) {
      return api.i18n.getMessage(messageName, substitutions)
    }
  }
}
