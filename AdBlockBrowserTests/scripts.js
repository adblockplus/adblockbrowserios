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

var AdblockPlusTests = (function()
{
  var framesOfTabs = {};
  var Page = ext.Page;

  var onBeforeRequestCallback = function(details)
  {
    if (details.tabId == -1)
    {
      return;
    }
    var isMainFrame = details.type == "main_frame" || details.frameId == 0 && !(details.tabId in framesOfTabs);
    var frames = null;
    if (!isMainFrame)
    {
      frames = framesOfTabs[details.tabId];
    }
    if (!frames)
    {
      frames = framesOfTabs[details.tabId] = Object.create(null);
    }
    var frame = null;
    var url = new URL(details.url);
    if (!isMainFrame)
    {
      var frameId;
      var requestType;
      if (details.type == "sub_frame")
      {
        frameId = details.parentFrameId;
        requestType = "SUBDOCUMENT";
      }
      else
      {
        frameId = details.frameId;
        requestType = details.type.toUpperCase();
      }
      frame = frames[frameId] || frames[Object.keys(frames)[0]];
      if (frame)
      {
        var results = ext.webRequest.onBeforeRequest._dispatch(url, requestType, new Page(
        {
          id: details.tabId
        }), frame);
        if (results.indexOf(false) != -1)
        {
          return {
            cancel: true
          };
        }
      }
    }
    if (isMainFrame || details.type == "sub_frame")
    {
      frames[details.frameId] = {
        url: url,
        parent: frame
      };
    }
  };
  return {
    testOnBeforeRequest: function (actions) {
      return actions.map(function (action) {
        var result = onBeforeRequestCallback(action.details);
        var ret = {
          requestId: action.details.requestId,
          url: action.details.url,
          response: result || {} // to have a value after JSON.stringify
        };
        if (!!result === !!action.result) {
          ret.success = true;
        } else if (!result || !action.result) {
          ret.success = false;
        } else {
          ret.success = !!result.cancel === !!action.result.cancel;
        }
        return ret;
      });
    }
  };
})();

window.AdblockPlusTests = AdblockPlusTests;
"DONE"
