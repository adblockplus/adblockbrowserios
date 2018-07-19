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

#import <Foundation/Foundation.h>
#import <KittCore/KittCore-Swift.h>

/**
 (Obj)C variadic functions can be called from Swift, but not vice versa.
 In other words, Swift has functions to handle (Obj)C va_list parameters, but
 ObjectiveC does not understand Swift CVarArgType. So as long as there is ObjC
 code in KittCore, this forwarding adapter is needed.
 */

#define LogDebug(frmt, ...) [KittCoreLogger plainDebug:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define LogInfo(frmt, ...) [KittCoreLogger plainInfo:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define LogWarn(frmt, ...) [KittCoreLogger plainWarn:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
#define LogError(frmt, ...) [KittCoreLogger plainError:[NSString stringWithFormat:frmt, ##__VA_ARGS__]]
