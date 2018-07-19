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
 Wrapper class for SYS-tem related functions - querying low level OS.
 The used functions and data structures would require importing <sys/?> headers in ObjC.
 */

open class Sys {
    open static let physicalMemory: Int64 =
        // NSProcessInfo.processInfo().physicalMemory // Returns 0 on real device???
        {
            do {
                // Gives the same number as NSProcessInfo.physicalmemory (when that works and does not say 0)
                return try Sys.sysctlInt(CTL_HW, HW_MEMSIZE)
            } catch let error {
                Log.error("Getting physical memory: " + String(describing: error))
                return 0
            }
    }()

    public typealias MemoryValues = (resident: Int64, allowed: Int64, physical: Int64)
    open static func memoryUsage() -> MemoryValues {
        var info = task_basic_info()
        let machTaskBasicInfoCount = (MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        var count = mach_msg_type_number_t(machTaskBasicInfoCount)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: Int32.self, capacity: 1) { myTaskInfo in
                task_info(mach_task_self_,
                          task_flavor_t(TASK_BASIC_INFO),
                          myTaskInfo,
                          &count)
            }
        }

        let residentMemory: Int64 = {
            if kerr == KERN_SUCCESS {
                return Int64(info.resident_size)
            } else {
                Log.error("Getting resident memory: " +
                    String(describing: mach_error_string(kerr)) )
                return 0
            }
        }()

        let allowedMemory: Int64 = {
            do {
                // return try sysctlInt(CTL_HW, HW_PHYSMEM) // Signed 32 bit only (<= 2GB)
                return try sysctlInt(CTL_HW, HW_USERMEM)
            } catch let error {
                Log.error("Getting allowed memory: " + String(describing: error))
                return 0
            }
        }()
        return (residentMemory, allowedMemory, physicalMemory)
    }

    // Recognizable "commercial" device model name
    // i.e. not "iPhone6,2" but "iPhone 5s"
    open static let deviceModelName: String = {

        var systemInfo = utsname() // C: struct utsname
        uname(&systemInfo)
        // systemInfo.machine in (Objective-)C is a C-string.
        // C-string in swift is a weird beast: A tuple of fixed count of Int8 values.
        // To make a string of it, the tuple must be iterated, which can be done only by Reflection.
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        var machineCode = ""
        let collection = machineMirror.children.makeIterator()
        while let val = collection.next()?.value {
            guard let char = val as? Int8, char != 0 else {
                break
            }
            machineCode += String(UnicodeScalar(UInt8(char)))
        }
        if let deviceModelName = deviceNamesByCode[machineCode] {
            return deviceModelName
        }
        return machineCode
    }()

    // http://stackoverflow.com/a/20062141
    fileprivate static let deviceNamesByCode = [
        "i386": "Simulator 32bit",
        "x86_64": "Simulator 64bit",
        "iPod1,1": "iPod Touch 1",      // (Original)
        "iPod2,1": "iPod Touch 2",      // (Second Generation)
        "iPod3,1": "iPod Touch 3",      // (Third Generation)
        "iPod4,1": "iPod Touch 4",      // (Fourth Generation)
        "iPod5,1": "iPod Touch 5",
        "iPod7,1": "iPod Touch 6",
        "iPhone1,1": "iPhone 1",          // (Original)
        "iPhone1,2": "iPhone 3G",         // (3G)
        "iPhone2,1": "iPhone 3GS",        // (3GS)
        "iPhone3,1": "iPhone 4",
        "iPhone3,2": "iPhone 4",
        "iPhone3,3": "iPhone 4",
        "iPhone4,1": "iPhone 4S",       //
        "iPhone5,1": "iPhone 5",        // (model A1428, AT&T/Canada)
        "iPhone5,2": "iPhone 5",        // (model A1429, everything else)
        "iPhone5,3": "iPhone 5c",       // (model A1456, A1532 | GSM)
        "iPhone5,4": "iPhone 5c",       // (model A1507, A1516, A1526 (China), A1529 | Global)
        "iPhone6,1": "iPhone 5s",       // (model A1433, A1533 | GSM)
        "iPhone6,2": "iPhone 5s",       // (model A1457, A1518, A1528 (China), A1530 | Global)
        "iPhone7,1": "iPhone 6 Plus",
        "iPhone7,2": "iPhone 6",
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE",
        "iPad1,1": "iPad 1",
        "iPad2,2": "iPad 2",
        "iPad2,3": "iPad 2",
        "iPad2,4": "iPad 2",
        "iPad2,5": "iPad Mini",       // (Original)
        "iPad2,6": "iPad Mini",
        "iPad2,7": "iPad Mini",
        "iPad3,1": "iPad 3",
        "iPad3,2": "iPad 3",
        "iPad3,3": "iPad 3",
        "iPad3,4": "iPad 4",
        "iPad3,5": "iPad 4",
        "iPad3,6": "iPad 4",
        "iPad4,1": "iPad Air", // 5th Generation iPad (iPad Air) - Wifi
        "iPad4,2": "iPad Air", // 5th Generation iPad (iPad Air) - Cellular
        "iPad4,3": "iPad Air",
        "iPad4,4": "iPad Mini 2", // (2nd Generation iPad Mini - Wifi)
        "iPad4,5": "iPad Mini 2", // (2nd Generation iPad Mini - Cellular)
        "iPad4,6": "iPad Mini 2",
        "iPad4,7": "iPad Mini 3",
        "iPad4,8": "iPad Mini 3",
        "iPad4,9": "iPad Mini 3",
        "iPad5,1": "iPad Mini 4",
        "iPad5,2": "iPad Mini 4",
        "iPad5,3": "iPad Air 2",
        "iPad5,4": "iPad Air 2",
        "iPad6,3": "iPad Pro",
        "iPad6,4": "iPad Pro",
        "iPad6,7": "iPad Pro",
        "iPad6,8": "iPad Pro",
        "AppleTV5,3": "Apple TV"
    ]
}

// lifted from 
// https://github.com/mattgallagher/CwlUtils/blob/master/CwlUtils/CwlSysctl.swift
extension Sys {
    //  Created by Matt Gallagher on 2016/02/03.
    //  Copyright © 2016 Matt Gallagher ( http://cocoawithlove.com ). All rights reserved.
    //
    //  Permission to use, copy, modify, and/or distribute this software for any
    //  purpose with or without fee is hereby granted, provided that the above
    //  copyright notice and this permission notice appear in all copies.
    //
    //  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
    //  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
    //  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
    //  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
    //  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
    //  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
    //  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
    //

    enum SysctlError: Error {
        case unknown
        case invalidSize // neither Int32 nor Int64
        case posixError(POSIXErrorCode)
    }

    /// Wrapper around `sysctl` that preflights and allocates an [Int8] for the result and throws a Swift error if anything goes wrong.
    fileprivate static func sysctl(levels: [Int32]) throws -> [Int8] {
        return try levels.withUnsafeBufferPointer { levelsPointer throws -> [Int8] in
            // Preflight the request to get the required data size
            var requiredSize = 0
            let preFlightResult = Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: levelsPointer.baseAddress),
                                                UInt32(levels.count),
                                                nil,
                                                &requiredSize,
                                                nil,
                                                0)
            if preFlightResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map { SysctlError.posixError($0) } ?? SysctlError.unknown
            }

            // Run the actual request with an appropriately sized array buffer
            let data = [Int8](repeating: 0, count: requiredSize)
            let result = data.withUnsafeBufferPointer { dataBuffer -> Int32 in
                return Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: levelsPointer.baseAddress),
                                     UInt32(levels.count),
                                     UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress),
                                     &requiredSize,
                                     nil,
                                     0)
            }
            if result != 0 {
                throw POSIXErrorCode(rawValue: errno).map { SysctlError.posixError($0) } ?? SysctlError.unknown
            }

            return data
        }
    }

    // Helper function used by the various int from sysctl functions, below
    fileprivate static func intFromSysctl(_ levels: [Int32]) throws -> Int64 {
        let buffer = try sysctl(levels: levels)
        switch buffer.count {
        case 4:
            return buffer.withUnsafeBufferPointer {
                $0.baseAddress.map {
                    $0.withMemoryRebound(to: Int32.self, capacity: 1) { Int64($0.pointee) }
                } ?? 0
            }
        case 8:
            return buffer.withUnsafeBufferPointer {
                $0.baseAddress.map {
                    $0.withMemoryRebound(to: Int64.self, capacity: 1) { $0.pointee }
                } ?? 0
            }
        default:
            throw SysctlError.invalidSize
        }
    }

    /// Get an arbitrary sysctl value and cast it to an Int64
    static func sysctlInt(_ levels: Int32...) throws -> Int64 {
        return try intFromSysctl(levels)
    }
}
