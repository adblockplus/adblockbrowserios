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

extension NSObject {
    public class func swizzle(method originalSelector: Selector, for swizzledSelector: Selector) {
        var sSelf: AnyClass = self

        // first let's try to get instance methods
        var originalMethod = class_getInstanceMethod(self, originalSelector)
        var swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        // otherwise we assume to be swizzling static methods
        if originalMethod == nil || swizzledMethod == nil {
            originalMethod = class_getClassMethod(self, originalSelector)
            swizzledMethod = class_getClassMethod(self, swizzledSelector)
            sSelf = object_getClass(self)!
        }

        if let originalMethod = originalMethod, let swizzledMethod = swizzledMethod {
            let didAddMethod = class_addMethod(sSelf,
                                               originalSelector,
                                               method_getImplementation(swizzledMethod),
                                               method_getTypeEncoding(swizzledMethod))

            if didAddMethod {
                class_replaceMethod(sSelf, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        } else {
            assert(false, "Method swizzling has failed!")
        }
    }
}
