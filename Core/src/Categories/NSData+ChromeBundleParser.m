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

#import "NSData+ChromeBundleParser.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (ChromeBundleParser)

static NSString *const ERROR_DOMAIN = @"ChromeBundleParser";
static const NSUInteger HEADER_ALIGNMENT = 4;
static const unsigned char CRX_MAGIC[HEADER_ALIGNMENT] = { 0x43, 0x72, 0x32, 0x34 }; // Cr24

// Scattering. Gets bytes from buffer at given range and increments the range
// position by its length to represent the new "current" position
- (BOOL)checkedGetBytes:(void *)buffer rangeMove:(NSRange *)range
{
    @try {
        [self getBytes:buffer range:*range];
        range->location += range->length;
        return TRUE;
    }
    @catch (NSException *exception) {
        return FALSE;
    }
}

// Most common operation, read 4 bytes big endian to NSUInteger
- (BOOL)readBlockToUInt:(NSUInteger *)number
                  range:(NSRange *)range
                  error:(NSError *__autoreleasing *)error
                   code:(CRXValidationCode)code
{
    // CFSwap *has to take uint32_t and nothing else. Giving a dereferenced char array
    // makes it behave strangely, though it's the same 4 bytes and the function should
    // be just shuffling bytes IMO.
    uint32_t blockIn;
    range->length = sizeof(blockIn);
    if (![self checkedGetBytes:&blockIn rangeMove:range]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:code userInfo:nil];
        return NO;
    }
    *number = CFSwapInt32LittleToHost(blockIn);
    return YES;
}

- (BOOL)crxGetZipContent:(NSData *__autoreleasing *)data
                   error:(NSError *__autoreleasing *)error
{
    char headerBlock[HEADER_ALIGNMENT];
    NSRange range = NSMakeRange(0, HEADER_ALIGNMENT);
    if (![self checkedGetBytes:&headerBlock rangeMove:&range]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_MAGIC_UNDERFLOW userInfo:nil];
    } else if (memcmp(CRX_MAGIC, headerBlock, HEADER_ALIGNMENT) != 0) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_MAGIC_BAD userInfo:nil];
        return NO;
    }
    __unused NSUInteger version = 0;
    if (![self readBlockToUInt:&version range:&range error:error code:CRX_VERSION_UNDERFLOW]) {
        return NO;
    }
    NSUInteger pubKeyLen = 0;
    if (![self readBlockToUInt:&pubKeyLen range:&range error:error code:CRX_PUBKEY_UNDERFLOW]) {
        return NO;
    }
    if (pubKeyLen == 0) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_PUBKEY_ZERO_LENGTH userInfo:nil];
        return NO;
    }
    NSUInteger signLen = 0;
    if (![self readBlockToUInt:&signLen range:&range error:error code:CRX_SIG_UNDERFLOW]) {
        return NO;
    }
    if (signLen == 0) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_SIG_ZERO_LENGTH userInfo:nil];
        return NO;
    }
    char pubKey[pubKeyLen];
    range.length = pubKeyLen;
    if (![self checkedGetBytes:&pubKey rangeMove:&range]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_PUBKEY_UNDERFLOW userInfo:nil];
        return NO;
    }
    char signature[signLen];
    range.length = signLen;
    if (![self checkedGetBytes:&signature rangeMove:&range]) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_SIG_UNDERFLOW userInfo:nil];
        return NO;
    }
    // ZIP to the end
    range.length = self.length - range.location;
    if (range.length == 0) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_ZIP_ZERO_LENGTH userInfo:nil];
        return NO;
    }
    *data = [self subdataWithRange:range];

    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    if (CC_SHA1([*data bytes], (CC_LONG)range.length, digest) != digest) {
        *error = [NSError errorWithDomain:ERROR_DOMAIN code:CRX_ZIP_DIGEST_FAIL userInfo:nil];
        return NO;
    }
    // @todo check signature
    // I haven't found a way to convert pubKey NSData -> SecKeyRef without
    // needing a certificate and/or keychain importing
    // SecKeyRawVerify(>>SecKeyRef key<<, kSecPaddingPKCS1SHA1, [*data bytes], range.length, signature, signLen)
    return YES;
}

@end
