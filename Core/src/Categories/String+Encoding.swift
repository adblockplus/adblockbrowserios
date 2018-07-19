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

import Foundation

/**
 stringByAddingPercentEncodingWithAllowedCharacters is the new iOS9+ way of URL encoding.
 But it works quite differently than the deprecated stringByAddingPercentEscapesUsingEncoding.
 
 stringByAddingPercentEscapesUsingEncoding:
 didn't have specializations on various URL parts, so was encoding everything what would break
 ANY part of URL. On top of obvious out-of-ASCII characters, there were all of =+?&:/.
 The result was a string that was safe for ANY part of URL.
 
 stringByAddingPercentEncodingWithAllowedCharacters takes NSCharacterSet. The companion predefined
 URL*AllowedCharacterSets are specialized per URL parts (host, path, query, fragment). It expects
 that the string already represents one of the parts. path passes slashes, query passes amps, etc.
 
 The simplest way of reconstructing the original stringByAddingPercentEscapesUsingEncoding is to
 use URLQuerySafeCharacterSet and remove the "query safe" chars from it.
 */

private let URLQuerySafeCharacterSet = { () -> CharacterSet in
    var charset = CharacterSet.urlQueryAllowed
    charset.remove(charactersIn: "=+?&:/.")
    return charset
}()

public extension String {
    public func stringByEncodingToURLSafeFormat() -> String? {
        return addingPercentEncoding(withAllowedCharacters: URLQuerySafeCharacterSet)
    }
}
