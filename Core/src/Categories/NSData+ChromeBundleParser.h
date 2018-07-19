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

// If NSData represents CRX binary, this category will parse it,
// validate it, and return the enclosed ZIP

#import <Foundation/Foundation.h>

@interface NSData (ChromeBundleParser)

// various validation malfunctions
typedef enum {
    CRX_MAGIC_UNDERFLOW,
    CRX_MAGIC_BAD,
    CRX_VERSION_UNDERFLOW,
    CRX_PUBKEY_UNDERFLOW,
    CRX_PUBKEY_ZERO_LENGTH,
    CRX_SIG_UNDERFLOW,
    CRX_SIG_ZERO_LENGTH,
    CRX_ZIP_ZERO_LENGTH,
    CRX_ZIP_DIGEST_FAIL
} CRXValidationCode;

- (BOOL)crxGetZipContent:(NSData **)data error:(NSError **)error;

@end
