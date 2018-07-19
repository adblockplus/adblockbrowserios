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

#import "ExtensionUnpacker.h"
#import "Utils.h"
#import "ZipArchive.h"
#import "NSData+ChromeBundleParser.h"
#import "Settings.h"
#import "ObjCLogger.h"

// ZipArchive lib requires physical file to deflate, isn't capable of
// working with NSData *or streams. It seems to be a limitation of the
// underlying libz API which everybody uses
#define TEMPFILE_NAME @"kitt-received"
// Subfolder name for unpacked extensions
#define SUBFOLDER_EXTENSIONS @"addons"

#define SUBFOLDER_BUNDLE @"bundle"
// Filter for proper extension names, to leave out dot folders and metafiles
// which iOS creates everywhere
#define ADDON_FOLDER_PREDICATE @"^[A-Za-z0-9_-]+$"

@interface ExtensionUnpacker () <ZipArchiveDelegate>
@property (nonatomic, strong) ZipArchive *unzipper;
/// See TEMPFILE_NAME
@property (nonatomic, strong) NSString *tempZipFilePath;
/// ZipArchive has a weird design of sending out the internal errors via
/// delegate callbacks, so if we want to remember the error when the ZipArchive
/// call returns, we need a transport variable
@property (nonatomic, strong) NSString *unzipErrorCall;
/// See ADDON_FOLDER_PREDICATE
@property (nonatomic, strong) NSPredicate *extensionFolderMatchPredicate;

// private functions

/// @param extensionId unpacked extension to query.
/// If nil, returned path is the SUBFOLDER_EXTENSIONS.
/// @param resourcePath relative to extension bundle root
/// May be nil (equals to extension bundle root path).
/// @param error [out] anything went wrong
/// @return full absolute path for requested resource (or just the root)
- (NSString *)pathForExtensionId:(NSString *)extensionId
                        resource:(NSString *)resourcePath
                           error:(NSError *__autoreleasing *)error;
@end

@implementation ExtensionUnpacker

- (id)init
{
    self = [super init];
    if (self) {
        _unzipper = [ZipArchive new];
        _unzipper.delegate = self;
        _tempZipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:TEMPFILE_NAME];
        _extensionFolderMatchPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ADDON_FOLDER_PREDICATE];
    }
    return self;
}

- (void)unpackBundleData:(NSData *)data
         asExtensionOfId:(NSString *)extensionId
                   error:(NSError *__autoreleasing *)error
{
    NSData *zipData = nil;
    NSError *crxError = nil;
    if (![data crxGetZipContent:&zipData error:&crxError]) {
        [Utils error:error wrapping:crxError message:@"Chrome bundle parsing failure"];
        return;
    }
    // write the data to temp file
    [zipData writeToFile:_tempZipFilePath atomically:YES];
    if (![[NSFileManager defaultManager] fileExistsAtPath:_tempZipFilePath]) {
        [Utils error:error wrapping:nil message:@"Can't create tempfile, out of memory?"];
        return;
    }
    NSString *folder = [self pathForExtensionId:extensionId resource:nil error:error];
    if (*error) {
        return;
    }
    _unzipErrorCall = nil;
    if (![_unzipper UnzipOpenFile:_tempZipFilePath]) {
        [Utils error:error wrapping:nil message:_unzipErrorCall];
        return;
    }
    if (![_unzipper UnzipFileTo:folder overWrite:YES]) {
        [Utils error:error wrapping:nil message:_unzipErrorCall];
        return;
    }
    [_unzipper UnzipCloseFile];
    [[NSFileManager defaultManager] removeItemAtPath:_tempZipFilePath error:error];
}

- (NSArray *)arrayOfInstalledExtensionIdsOrError:(NSError *__autoreleasing *)error
{
    // extensionId is nil, so the root of whole extension installations tree is returned
    // and fromBundle parameter doesn't matter, but let's say NO to be consistent
    // with required return value (no subfolders, just the main root)
    NSString *folder = [self pathForExtensionId:nil resource:nil error:error];
    if (*error) {
        return nil;
    }
    // first check if subfolder for unpacking bundles exists at all. If it doesn't,
    // the following contentsOfDirectoryAtPath does not return empty array but throws
    // an error (which we want to avoid)
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDirectory];
    if (!exists) {
        // not an error, folder for unpacked bundles simply doesn't exist yet
        return nil;
    }
    if (!isDirectory) {
        [Utils error:error wrapping:nil message:@"Extension bundles place name is occupied by an existing file"];
        return nil;
    }
    NSArray *extensionIds = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder
                                                                                error:error];
    if (*error) {
        return nil;
    }
    // We got everything in that folder, filter out the iOS meta junk
    return [extensionIds filteredArrayUsingPredicate:_extensionFolderMatchPredicate];
}

- (void)deleteUnpackedExtensionOfId:(NSString *)extensionId
                              error:(NSError *__autoreleasing *)error
{
    NSString *path = [self pathForExtensionId:extensionId error:error];
    if (*error) {
        return;
    }
    [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

- (BOOL)hasExtensionOfId:(NSString *)extensionId
                   error:(NSError *__autoreleasing *)error
{
    NSString *folder = [self pathForExtensionId:extensionId resource:nil error:error];
    if (*error) {
        return NO;
    }
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:folder
                                                       isDirectory:&isDirectory];
    return exists && isDirectory;
}

#pragma mark -
#pragma ExtensionBundleDataSource

- (NSData *)dataOfResource:(NSString *)resourcePath
           inExtensionOfId:(NSString *)extensionId
                     error:(NSError *__autoreleasing *)error
{
    NSString *path = [self pathForExtensionId:extensionId
                                     resource:resourcePath
                                        error:error];
    if (*error) {
        return nil;
    }

    NSData *data = nil;

    if (data == nil) {
        data = [NSData dataWithContentsOfFile:path
                                      options:NSDataReadingUncached
                                        error:error];
    }

    if (*error) {
        return nil;
    }
    return data;
}

- (BOOL)writeData:(NSData *)resourceData
           toResource:(NSString *)resourcePath
    ofExtensionWithId:(NSString *)extensionId
                error:(NSError *__autoreleasing *)error
{
    // bundle is not writeable, so fromBundle is always NO
    NSString *path = [self pathForExtensionId:extensionId
                                     resource:resourcePath
                                        error:error];
    if (*error) {
        return NO;
    }
    [resourceData writeToFile:path options:NSDataWritingAtomic error:error];
    return !*error;
}

- (BOOL)writeString:(NSString *)resourceString
           toResource:(NSString *)resourcePath
    ofExtensionWithId:(NSString *)extensionId
                error:(NSError *__autoreleasing *)error
{
    // bundle is not writeable, so fromBundle is always NO
    NSString *path = [self pathForExtensionId:extensionId
                                     resource:resourcePath
                                        error:error];

    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    [resourceString writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:error];
    return !*error;
}

#pragma - Public for tests

- (NSString *)pathForExtensionId:(NSString *)extensionId
                        resource:(NSString *)resourcePath
                           error:(NSError *__autoreleasing *)error
{
    NSString *path = [self pathForExtensionId:extensionId error:error];
    if (!path) {
        return nil;
    }
    if (extensionId) {
        /**
         Originally conditioned for plist data storage which was not in the subfolder, so that
         the subfolder can be deleted and data persisted (when upgrading extension). Now the
         storage is in CoreData elsewhere, but let's keep the subfolder for backward compatibility
         of already installed extensions.
         */
        path = [path stringByAppendingPathComponent:SUBFOLDER_BUNDLE];
    }
    if (resourcePath) {
        path = [path stringByAppendingPathComponent:resourcePath];
    }
    return path;
}

#pragma - Private functions

- (NSString *)pathForExtensionId:(NSString *)extensionId
                           error:(NSError *__autoreleasing *)error
{
    NSArray *documentDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (!documentDirs || [documentDirs count] == 0) {
        [Utils error:error wrapping:nil message:@"Documents directory not found"];
        return nil;
    }
    NSString *documentDir = [documentDirs objectAtIndex:0];
    NSString *path = [documentDir stringByAppendingPathComponent:SUBFOLDER_EXTENSIONS];
    if (extensionId) {
        path = [path stringByAppendingPathComponent:extensionId];
    }
    return path;
}

#pragma mark - ZipArchiveDelegate

- (void)ErrorMessage:(NSString *)msg
{
    _unzipErrorCall = msg;
}

- (BOOL)OverWriteOperation:(NSString *)file
{
    // currently no established philosophy for extension upgrading, allow overwriting
    return YES;
}

@end
