/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

import {IBaseKittInterface} from "./baseKittInterface"

/**
 The part of autofill functionality which is not related to chrome polyfill
 and is meant to modify the main frame document.
 */
export default {
  init: function(api: IBaseKittInterface, document: HTMLDocument) {
    api.addListener("autofill.fillSuggestion", {}, function(message) {
      const suggestion = message.data.suggestion;
      (<any>document.activeElement).value = suggestion
    })
  }
}
