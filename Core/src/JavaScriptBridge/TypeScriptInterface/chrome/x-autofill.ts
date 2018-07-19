/**
 * chrome.autofill
 * No such standard Chrome API exists. It was created here to enable writing autofilling extension.
 * Named x-autofill to distinguish from autofill module which creates DOM modification entry.
 * (Not a problem for JS browserification but for XCode which is confused by naming duplicity)
 */

import {IBaseKittInterface} from "../modules/baseKittInterface"

export default function (api: IBaseKittInterface) {
  return {
    requestAutofillValues: function(extractedForms: any, callback: any) {
      // @typedef {Array<AutofillFormResponseData>}
      // AutofillFormResponseData := {
      //   formName: string
      //   fields: Object<{|fieldname|: |autofillFieldType|}>
      // }
      return api.autofill.requestAutofillValues(extractedForms, callback)
    },
    setKeyboardInputSuggestions: function(suggestions: any) {
      return api.autofill.setKeyboardInputSuggestions(suggestions)
    },
    clearKeyboardInputSuggestions: function() {
      return api.autofill.clearKeyboardInputSuggestions()
    }
  }
}
