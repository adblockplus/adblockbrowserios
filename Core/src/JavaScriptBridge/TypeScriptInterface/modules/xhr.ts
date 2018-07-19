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

/**
 *
 * Cross-site reimplementation of window XMLHttpRequest
 *
 */

import * as util from "./util"
import {IBaseKittInterface, IMessage} from "./baseKittInterface"

interface Content {
  binary?: boolean
  url?: string
  method?: string
  data?: any
  headers?: any
  timeout?: any
  responseHeaders: any
}

export default function(api: IBaseKittInterface) {
  return function() {
    const _content: Content = {
      responseHeaders : {}
    }
    let _abortFlag: boolean | undefined
    let _sendCallback: ((x: any) => void) | undefined
    // http://www.w3.org/TR/XMLHttpRequest/#response-entity-body-0
    // override be kept separately, not only applied to existing response headers
    let _overridenMimeType: string | null = null
    const _eventListeners: {[s: string]: ((x: any) => void)[]} = {
      load : [],
      error : [],
      readystatechange : []
    }
    const _xmlParser = new DOMParser()
    const States = {
      UNSENT : 0, // open() has not been called yet.
      OPENED : 1, // send() has not been called yet.
      HEADERS_RECEIVED : 2, // send() has been called, and headers and status are available.
      LOADING : 3, // Downloading; response holds partial data.
      DONE : 4
    }
    this.readyState = States.UNSENT
    // enum XMLHttpRequestResponseType
    // { "", "arraybuffer", "blob", "document", "json", "text" };
    this.responseType = ""
    this.timeout = 0
    this.abort = function() {
      _abortFlag = true
    }
    this.getAllResponseHeaders = function() {
      const separator = String.fromCharCode(0x003A) + String.fromCharCode(0x0020) // ": "
      const lineSeparator = String.fromCharCode(0x000D) +
          String.fromCharCode(0x000A) // "\r\n"
      let result = ""
      for (let name in _content.responseHeaders) {
        result += name + separator + _content.responseHeaders[name]
        result += lineSeparator
      }
      return result
    }
    this.getResponseHeader = function(header: string) {
      return (header in _content.responseHeaders) ? _content.responseHeaders[header]
          : null
    }
    // @param method string type of request (GET, PORT)
    // @param url string URL to request
    this.open = function(method: string, url: string) {
      method = method.toUpperCase()
      // Only those header are supported
      if ([ "POST", "GET", "HEAD" ].indexOf(method) === -1) {
        throw new SyntaxError()
      }

      // Create base url without last path component
      let baseUrl = window.location.href
      const to = baseUrl.lastIndexOf("/")
      if (to >= 0) {
        baseUrl = baseUrl.substring(0, to + 1)
      }

      // Test && remove location prefix
      if (url.indexOf(baseUrl) === 0) {
        url = url.substring(baseUrl.length)
      }

      _content.url = url
      _content.method = method
      _content.headers = {}
      _content.responseHeaders = {}
      _sendCallback = undefined
      _abortFlag = undefined
      this.readyState = States.OPENED
      this.response = null
      // These attributes should be throwing some exceptions per
      // http://www.w3.org/TR/XMLHttpRequest2/#the-responsetext-attribute
      // hence be full defined properties. But nobody is asking for it
      // at the moment so KISS.
      this.responseText = null
      this.responseXML = null
      this.dispatchEvent(new Event("readystatechange"))
    }
    this.send = function(data: any) {
      if (this.readyState === States.UNSENT || _sendCallback) {
        throw new Error("InvalidStateError")
      }
      if (!!data) {
        // truthiness test covers both "undefined" (no parameter)
        // as well as null (parameter given with null value)
        if (data instanceof ArrayBuffer || data instanceof Uint8Array) {
          // Send data as binary, btoa never fail on this string
          _content.binary = true
          if (data instanceof Uint8Array) {
            _content.data = window.btoa(String.fromCharCode.apply(this, data))
          } else {
            _content.data = window.btoa(String.fromCharCode.apply(this, new Uint8Array(data)))
          }
        } else {
          // Send data as string
          // Do not set binary flag at all, it's simpler for native code to recognize
          // Force toString on objects
          _content.data = "" + data
        }
      }
      _content.timeout = this.timeout
      const self = this
      const matchMIME = function(contentTypeHeader: string) {
        // stored in array to ensure searching order
        // index 0 is the Chrome-required content type
        // indexes 1 to n are corresponding MIME types
        const textualTypeMatches = [
          ["json", "application/json", "text/json"],
          ["document", "application/xml", "text/xml", "text/html"],
          ["text", "text/"] // fallback
        ]
        for (let matcher of textualTypeMatches) {
          for (let m = 1; m < matcher.length; m++) {
            if (contentTypeHeader.indexOf(matcher[m]) !== -1) {
              return matcher[0]
            }
          }
        }
        return "" // default unassigned
      }
      const callback = function(answer: IMessage) {
        // Request has been discarded. According to specification, user may
        // call open method even if request hasn't been completed.
        // Such situation cancels processing of request. Currently,
        // we are not able to abort request which has been sent.
        // This condition prevents from calling events unexpectedly.
        if (callback !== _sendCallback) {
          return
        }
        // False abort, request was aborted
        else if (_abortFlag) {
          return
        } else if (answer.data.error) {
          // Call onerror event
          // I am not at all sure about the 'reason' but i wanted some place
          // to put the error message
          self.dispatchEvent(new Event("error", <any>{"reason": answer.data.error}))
        } else {
          self.status = answer.data.status
          let contentMIMEType: string | null = null
          _content.responseHeaders = {}
          for (let h in answer.data.headers) {
            // Discard cookies as per
            // http://www.w3.org/TR/XMLHttpRequest/#the-getresponseheader()-method
            let contentType: any | null = null
            const headerKey = h.toLowerCase()
            if ([ "set-cookie", "set-cookie2" ].indexOf(headerKey) < 0) {
              const headerValue = answer.data.headers[h]
              if ( "content-type" === headerKey) {
                contentType = headerValue
              } else {
                _content.responseHeaders[h] = headerValue
              }
            }
            // replace with overriden, if available
            contentType = _overridenMimeType || contentType
            if (contentType) {
              _content.responseHeaders["Content-Type"] = contentType
              // strip the charset suffix, if there is any
              const charsetSuffixPos = contentType.indexOf(";")
              if (charsetSuffixPos > 0) {
                contentType = contentType.substr(0, charsetSuffixPos)
              }
              contentMIMEType = contentType
            }
          }
          // Uncategorized data yet
          self.responseType = contentMIMEType ? matchMIME(contentMIMEType) : ""
          self.response = answer.data.data
          if (self.response) {
            if (answer.data.binary) {
              // Data was transported as binary, decode to type-unspecific member
              try {
                self.response = window.atob(self.response)
              } catch (e) {
                throw new util.AnnotatedError("xhr decoding base64 response", e)
              }
            }
            const makeText = function() {
              // assign also to text property but no change needed
              self.responseText = self.response
            }
            const makeJSON = function() {
               try {
                // reassign dejsonized object
                self.response = JSON.parse(self.response)
              } catch (e) {
                // per XHR2 spec
                self.response = null
              }
            }
            const makeXML = function(parseMIME: string) {
              try {
                self.responseXML = _xmlParser.parseFromString(self.response, parseMIME)
              } catch (e) {
                // Setting responseXML has failed, therefore it is null.
                // Do nothing.
              }
            }
            // jQuery XHR wrappers ($.get, $.ajax) appear to require `responseText`
            // unconditionally, regardless of the `responseType`
            // https://github.com/jquery/jquery/blob/97cf5280824027c3d4fcdbb4db49c10ad3c62bce/src/ajax/xhr.js#L105
            makeText()
            switch (self.responseType) {
              case "json": makeJSON()
                break
              case "document": makeXML(<any>contentMIMEType)
                break
              case "":
                // Attempt XML decoding when responseType is undefined
                // https://xhr.spec.whatwg.org/#the-responsexml-attribute
                makeXML("application/xml")
              break
            }
          }
          for (let s of [ States.HEADERS_RECEIVED, States.LOADING, States.DONE ]) {
            self.readyState = s
            // Call onreadystatechange event
            self.dispatchEvent(new Event("readystatechange"))
          }
          // Call onload event
          self.dispatchEvent(new Event("load"))
        }
      }
      api.xhr(_content, callback)
      _sendCallback = callback
    }
    // http://www.w3.org/TR/XMLHttpRequest/#the-overridemimetype()-method
    this.overrideMimeType = function(mime: string) {
      if (this.readyState === States.LOADING || this.readyState === States.DONE || _sendCallback) {
        throw new Error("InvalidStateError")
      }
      // @todo parsing/validating: identified MIME and charset to be kept separately, MIME lowercase
      _overridenMimeType = mime
    }
    this.setRequestHeader = function(header: string, value: any) {
      if (this.readyState === States.UNSENT || _sendCallback) {
        throw new Error("InvalidStateError")
      }
      _content.headers[header.toLowerCase()] = value.toString()
    }
    this.addEventListener = function(type: string, listener: () => void /*, useCapture (will be ignored) */) {
      if (_eventListeners[type].indexOf(listener) === -1) {
        _eventListeners[type].push(listener)
      }
    }
    this.removeEventListener = function(type: string, listener: () => void  /*, useCapture (will be ignored) */) {
      const i = _eventListeners[type].indexOf(listener)
      if (i >= 0) {
        _eventListeners[type].splice(i, 1)
      }
    }
    this.dispatchEvent = function(event: any) {
      event.currentTarget = this
      if (this["on" + event.type]) {
        util.invokeOptionalCallbackWithArray("XMLHttpRequest.on" + event.type, () => {
          this["on" + event.type](event)
        })
      }
      for (let l of _eventListeners[event.type]) {
        util.invokeOptionalCallbackWithArray("XMLHttpRequest.on" + event.type, () => {
          l(event)
        })
      }
    }
  }
}
