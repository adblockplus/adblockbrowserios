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

(function() {
  var api = __BROWSERIFIED_API__;
  window.open = api.windowOpen;
  window.close = api.windowClose;
}());

(function(prototypeXhr) {
  var originalOpen = prototypeXhr.open;
  prototypeXhr.open = function() {
    _openImpl.apply(this, arguments);
  };
  // ^^^ the only thing the curious developer sees in the public page
  function _openImpl() {
    originalOpen.apply(this, arguments);
    // ^^^ InvalidStateError (Exception 11) if not done first (before setRequestHeader)
    var possiblyAsync = arguments[2];
    var isAsync = typeof(possiblyAsync) === 'boolean' ? possiblyAsync : true; // default value
    // giving the header even if the request is async (where no special handling is necessary)
    // is useful for knowing deterministically that the request comes from XHR
    this.setRequestHeader('Accept', isAsync ? 'kitt-xhr-async' : 'kitt-xhr-sync');
 /**
  HACK: ^^^ originally a custom header was used. But it appears that WebKitt preflights every XHR
  with an "Access-Control-Request-Headers: X-Requested-With", which some servers (like nytimes.com)
  answer by echoing back.
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS
  This results in WebKit XHR handler to refuse any other custom headers than the one explicitly
  allowed. The only solution left is appending onto one of the standard allowed headers.
  "User-Agent" and "Referer" are rewritten by WebKit before arriving to protocol handler. Luckily
  "Accept" works like a comma separated list - the values set by WebKit are appended to the one
  set here. It smells and walks like a hack, but there is no other option.
  I tried inocuous "Pragma" but it is also prohibited by the CORS management.
  I tested also hooking on the "X-Requested-With" which is allowed specifically by nytimes.com.
  It works, and works like a CSV too. But it is undependable. There might be servers which do not
  allow any custom headers in CORS handshake.

  Possibly more deterministic solution would be hooking on to the preflight request (if it even
  passes through protocol handler!) and add our custom header to it. It is dirty because the server
  would have to approve a header which is not actually sent out. It lives just between
  XMLHttpRequest.send and protocol handler invocation, where it is analyzed and removed from headers.
  But we need to convince WebKit to allow it through.
*/
  }
})(window.XMLHttpRequest.prototype);
// make jshint happy about 'unexpected expression'
(function(){ return '__SUCCESS__'; })();
