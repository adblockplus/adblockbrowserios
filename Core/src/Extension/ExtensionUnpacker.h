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

// Minimal interface for retrieving unpacked bundle resources

@protocol ExtensionBundleDataSource <NSObject>

/// @param resourcePath relative path to bundle root
/// @param extensionId extension to retrieve from
/// @param error [out] any error occured when accessing the filesystem
/// @return data of resource on success
/// @return nil on failure (observe error param)
- (NSData *)dataOfResource:(NSString *)resourcePath
           inExtensionOfId:(NSString *)extensionId
                     error:(NSError **)error;

- (BOOL)writeString:(NSString *)resourceString
           toResource:(NSString *)resourcePath
    ofExtensionWithId:(NSString *)extensionId
                error:(NSError *__autoreleasing *)error;

/// @param resourceData data to (over)write to the resource file
/// @param resourcePath relative path to bundle root
/// @param extensionId extension to retrieve from
/// @param error [out] any error occured when accessing the filesystem
/// @return true if writing finished correctly
/// @return false if any error occured
- (BOOL)writeData:(NSData *)resourceData
           toResource:(NSString *)resourcePath
    ofExtensionWithId:(NSString *)extensionId
                error:(NSError **)error;

- (NSString *)pathForExtensionId:(NSString *)extensionId
                        resource:(NSString *)resourcePath
                           error:(NSError *__autoreleasing *)error;
@end

// Encapsulation of unzipping the extension downloads and operations over
// the unzipped bundles

@interface ExtensionUnpacker : NSObject <ExtensionBundleDataSource>

/// Will try to treat the input data as zipfile and unpack it into
/// unique path constructed with the extension id
/// @param bundle data as received from server
/// @param extensionId
/// @param error [out] any error occured during the unpacking
- (void)unpackBundleData:(NSData *)data
         asExtensionOfId:(NSString *)extensionId
                   error:(NSError **)error;

/// Retrieve ids of all recently installed extensions
/// @param error [out] any error occured when accessing the filesystem
/// @return array of NSString
- (NSArray *)arrayOfInstalledExtensionIdsOrError:(NSError **)error;

/// Remove already installed/unpacked extension
/// @param error [out] any error occured when accessing the filesystem
- (void)deleteUnpackedExtensionOfId:(NSString *)extensionId
                              error:(NSError **)error;

/// Tell whether such extension id is already installed
/// @param error [out] any error occured when accessing the filesystem
- (BOOL)hasExtensionOfId:(NSString *)extensionId error:(NSError **)error;

@end
