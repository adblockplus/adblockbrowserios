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

type Promise<T> = PromiseLike<T>

// Promise definition, inspiration has been taken from:
// lib.promise.d.ts

interface PromiseConstructor {
  new <T>(executor: (resolve: (value?: T | PromiseLike<T>) => void, reject: (reason?: any) => void) => void): Promise<T>
}

declare var Promise: PromiseConstructor

// Fetch types, inspiration has been taken from:
// https://github.com/DefinitelyTyped/DefinitelyTyped/blob/7371891d4b0ea31f433da869330fd9e4138d5f6d/isomorphic-fetch/index.d.ts

interface ForEachCallback {
  (keyId: any, status: string): void
}

interface Headers {
  append(name: string, value: string): void
  delete(name: string): void
  forEach(callback: ForEachCallback): void
  get(name: string): string | null
  has(name: string): boolean
  set(name: string, value: string): void
}

declare var Headers: {
  prototype: Headers;
  new(init?: any): Headers;
}

interface Blob {
  readonly size: number
  readonly type: string
  msClose(): void
  msDetachStream(): any
  slice(start?: number, end?: number, contentType?: string): Blob
}

interface Body {
  readonly bodyUsed: boolean
  arrayBuffer(): Promise<ArrayBuffer>
  blob(): Promise<Blob>
  json(): Promise<any>
  text(): Promise<string>
}

interface RequestInit {
  method?: string
  headers?: any
  body?: any
  referrer?: string
  referrerPolicy?: string
  mode?: string
  credentials?: string
  cache?: string
  redirect?: string
  integrity?: string
  keepalive?: boolean
  window?: any
}

interface Request extends Object, Body {
  readonly cache: string
  readonly credentials: string
  readonly destination: string
  readonly headers: Headers
  readonly integrity: string
  readonly keepalive: boolean
  readonly method: string
  readonly mode: string
  readonly redirect: string
  readonly referrer: string
  readonly referrerPolicy: string
  readonly type: string
  readonly url: string
  clone(): Request
}

declare var Request: {
  prototype: Request;
  new(input: Request | string, init?: RequestInit): Request;
}

interface ReadableStream {
  readonly locked: boolean
  cancel(): Promise<void>
}

interface ResponseInit {
  status?: number
  statusText?: string
  headers?: any
}

interface Response extends Object, Body {
  readonly body: ReadableStream | null
  readonly headers: Headers
  readonly ok: boolean
  readonly status: number
  readonly statusText: string
  readonly type: string
  readonly url: string
  clone(): Response
}

declare var Response: {
  prototype: Response;
  new(body?: any, init?: ResponseInit): Response;
}

// Fetch implementation, inspiration has been taken from:
// https://github.com/github/fetch/blob/master/fetch.js

function parseHeaders(rawHeaders: string) {
  const headers = new Headers()
  // Replace instances of \r\n and \n followed by at least one space or horizontal tab with a space
  // https://tools.ietf.org/html/rfc7230#section-3.2
  const preProcessedHeaders = rawHeaders.replace(/\r?\n[\t ]+/g, " ").split(/\r?\n/)
  for (const line of preProcessedHeaders) {
    const parts = line.split(":")
    const part = parts.shift()
    if (part) {
      const key = part.trim()
      if (key) {
        const value = parts.join(":").trim()
        headers.append(key, value)
      }
    }
  }
  return headers
}

export default function (XMLHttpRequest: { new(): XMLHttpRequest }) {
  // Browser does not support fetch api
  if (!(window as any).fetch) {
    return
  }

  return function(input: Request | string, init?: RequestInit): Promise<Response>
  {
    return new Promise(function(resolve, reject) {
      const request = new Request(input, init)
      const xhr = new XMLHttpRequest()

      xhr.onload = function() {
        const options = {
          status: xhr.status,
          statusText: xhr.statusText,
          headers: parseHeaders(xhr.getAllResponseHeaders() || "")
        } as ResponseInit;
        (<any>options).url = "responseURL" in xhr ? xhr.responseURL : options.headers.get("X-Request-URL")
        const body = "response" in xhr ? xhr.response : xhr.responseText
        resolve(new Response(body, options))
      }

      xhr.onerror = function() {
        reject(new TypeError("Network request failed"))
      }

      xhr.ontimeout = function() {
        reject(new TypeError("Network request failed"))
      }

      xhr.open(request.method, request.url, true)

      if (request.credentials === "include") {
        xhr.withCredentials = true
      }

      request.headers.forEach(function(value, name) {
        xhr.setRequestHeader(name, value)
      })

      xhr.send(typeof (<any>request)._bodyInit === "undefined" ? null : (<any>request)._bodyInit)
    })
  }
}
