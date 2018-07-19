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

(function(window) {
  var api;
  try {
    api = __BROWSERIFIED_API__;
    // global callback injection already created these symbols but this `api` knows
    // its originating content script, so there is more context to the call
    // create an object as similar to the global `window` as possible
    var wrapper = (function() {
      var _wrapper = {}; // The window copy, return value
      // Recreated accessor properties can't be stored directly in _wrapper
      // because accessing it in descriptor getter/setter results in recursion
      var _propertyStorage = {};
      // Iterate all `window` properties
      /* jshint loopfunc: true */
      for(var prop in window) {
        // IIFE to lock the iterator value
        (function(prop) {
          if (typeof(window[prop]) === 'function') {
            // Will call the global window function in scope of the window (not of our copy)
            _wrapper[prop] = function() {
              return window[prop].apply(window, arguments);
            };
          } else {
            // Not a function, create accessor property which will have the same name
            // but use `_propertyStorage`
            var wrapperDesc = {
              get: function() {
                if(window[prop] == window) {
                  // Whenever prop.window is required to be === window (like in jQuery.isWindow)
                  return _wrapper;
                } else {
                  // If this particular `prop` didn't have setter called yet, it doesn't
                  // exist in our private storage.
                  // In such case, return whatever the global window has.
                  return (typeof(_propertyStorage[prop]) === "undefined") ?
                    window[prop] : _propertyStorage[prop];
                }
              },
              set: function(val) {
                // Simply set to private storage, not touching the global window
                _propertyStorage[prop] = val;
              }
            };
            var winDesc = Object.getOwnPropertyDescriptor(window, prop);
            // If the (from global window) copied property has a descriptor,
            // copy applicable properties
            if(winDesc) {
              wrapperDesc.configurable = winDesc.configurable;
              wrapperDesc.enumerable = winDesc.enumerable;
            }
            // Finally, define on the wrapper
            Object.defineProperty(_wrapper, prop, wrapperDesc);
          }
        }(prop));
      }
      return _wrapper;
    })();
    // Assign non copyable global objects
    Object.getOwnPropertyNames(window).filter(function(name) {
      // Whitelist: class objects and some specific functions
      // parseInt required by lodash
      return /^([A-Z]|parse)\w+/.test(name);
    }).filter(function(name) {
      // Blacklist: leave out specific classes
      return (['XMLHttpRequest', 'JSON'].indexOf(name) === -1);
    }).forEach(function(name) {
      wrapper[name] = window[name];
    });
    wrapper.constructor = window.constructor;
    wrapper.addEventListener = function(type, listener, useCapture) {
      if('message' === type) {
        listener = (function(originalListener) {
          return function(event) {
            var newEvent = document.createEvent('MessageEvent');
            newEvent.initMessageEvent('message',
              event.bubbles, event.cancelable, event.data, event.origin,
              event.lastEventId, wrapper, event.ports);
            originalListener(newEvent);
          };
        })(listener);
      }
      window.addEventListener.call(window, type, listener, useCapture);
    };

    var contentScript;
    /* jshint withstmt: true */
    with (wrapper) {
      contentScript = (function(window, chrome, console, XMLHttpRequest, fetch) {
        // Not a meaningful code to stay. To be replaced at injection time.
        // Equal to USERSCRIPT_TOKEN of JSInjectorReporter
        throw new Error('Content script not replaced');
      }).bind(wrapper, wrapper, api.chrome, api.console, api.XMLHttpRequest, api.fetch);
    }

    var runAt = '%RUN_AT%';
    if (runAt === 'document_start') {
      setTimeout(contentScript, 0);
    } else {
      document.addEventListener("DOMContentLoaded", contentScript);
    }
    return '__SUCCESS__';
  } catch(e) {
    return api.stringifyError(e);
  }
})(window);
