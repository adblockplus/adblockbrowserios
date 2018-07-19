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

#import "BrowserStateCoreData.h"
#import "Utils.h"

#import <KittCore/KittCore-Swift.h>

static NSString *const DB_NAME = @"BrowserState.sqlite";

@interface BrowserStateCoreData () {
    NSURL *_storeFileURL;
    NSPointerArray *_mutationDelegates;
    NSMutableDictionary *_lastUnsavedMutations;
}

@end

@implementation BrowserStateCoreData

#pragma mark Core Data Simplification Wrappers

- (id)init
{
    if (self = [super init]) {
        // Store in Documents, this is rightfully user-generated data
        NSArray *docDirs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        _storeFileURL = [[docDirs lastObject] URLByAppendingPathComponent:DB_NAME];
        _mutationDelegates = [NSPointerArray weakObjectsPointerArray];
        _lastUnsavedMutations = [NSMutableDictionary new];
    }
    return self;
}

- (void)addMutationDelegate:(id<CoreDataMutationDelegate>)delegate
{
    [_mutationDelegates addPointer:(__bridge void *)(delegate)];
}

- (BOOL)succeededStoreSetupWithFeedback:(BOOL *)storeCreated
{
    NSError *error = nil;
    if (storeCreated != nil) {
        *storeCreated = NO;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:_storeFileURL.path]) {
        if ([self setUpStoreWithMigration:YES error:&error]) {
            return YES;
        }
        // noninvasive failed, delete and recreate store
        NSString *errorMessage = [Utils localizedMessageOfError:error];
        errorMessage = [NSString stringWithFormat:@"User data migration failed: %@.\nData will be cleared.", errorMessage];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Application upgrade"
                                                        message:errorMessage
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        // delete
        if (![[NSFileManager defaultManager] removeItemAtURL:_storeFileURL error:&error]) {
            NSString *errorMessage = [Utils localizedMessageOfError:error];
            errorMessage = [NSString stringWithFormat:@"Could not delete current data: %@.\nApplication will quit.", errorMessage];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Application upgrade"
                                                            message:errorMessage
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return NO;
        }
    }
    if ([self setUpStoreWithMigration:NO error:&error]) {
        *storeCreated = YES;
        return YES;
    }
    NSString *errorMessage = [Utils localizedMessageOfError:error];
    errorMessage = [NSString stringWithFormat:@"Failed generation of user data: %@.\nApplication will quit.", errorMessage];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Application installation"
                                                    message:errorMessage
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    return NO;
}

- (BOOL)setUpStoreWithMigration:(BOOL)tryMigration error:(NSError *__autoreleasing *)error
{
    // Get the current model, merging all the models in the main bundle (in their current version)
    NSBundle *coreBundle = [Settings coreBundle];
    NSManagedObjectModel *destinationModel = [NSManagedObjectModel mergedModelFromBundles:@[ coreBundle ]];
    if (tryMigration) {
        NSDictionary *migrationMetadata = [self metadataIfMigrationNeeded:_storeFileURL destinationModel:destinationModel error:error];
        if (*error) {
            return NO;
        }
        tryMigration = migrationMetadata.count > 0;
        if (tryMigration) {
            // migration need confirmed
            NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:@[ coreBundle ] forStoreMetadata:migrationMetadata];
            [self migrate:_storeFileURL sourceModel:sourceModel destinationModel:destinationModel error:error];
            if (*error) {
                return NO;
            }
        }
    }
    // at this moment, tryMigration==false means "not needed at all, or asked to try but found not needed"
    _context = [self createContextForStoreURL:_storeFileURL withModel:destinationModel wasMigrated:tryMigration error:error];
    if (*error == nil) {
        [self attachContextChangeObservers];
        return YES;
    }
    return NO;
}

- (void)attachContextChangeObservers
{
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextObjectsDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue currentQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      for (NSString *changeKey in @[ NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey ]) {
                                                          for (NSManagedObject *managedObj in note.userInfo[changeKey]) {
                                                              NSDictionary *oldValues = managedObj.changedValuesForCurrentEvent;
                                                              NSDictionary *newValues = managedObj.changedValues;
                                                              if ([oldValues count] == 0 && [newValues count] == 0) {
                                                                  continue;
                                                              }
                                                              NSDictionary *mutations = @{
                                                                  @"instance" : managedObj,
                                                                  @"changeKey" : changeKey,
                                                                  @"oldValues" : oldValues,
                                                                  @"newValues" : newValues
                                                              };
                                                              NSString *className = NSStringFromClass(managedObj.class);
                                                              if (self->_lastUnsavedMutations[className] == nil) {
                                                                  self->_lastUnsavedMutations[className] = [NSMutableArray arrayWithObject:mutations];
                                                              } else {
                                                                  [self->_lastUnsavedMutations[className] addObject:mutations];
                                                              }
                                                          }
                                                      }
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue currentQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      NSDictionary *currentMutations = [NSDictionary dictionaryWithDictionary:self->_lastUnsavedMutations];
                                                      [self->_lastUnsavedMutations removeAllObjects];
                                                      for (id<CoreDataMutationDelegate> delegate in self->_mutationDelegates) {
                                                          if (delegate == nil) {
                                                              continue;
                                                          }
                                                          NSString *className = NSStringFromClass([delegate managedObjectClassOfInterest]);
                                                          NSMutableArray *mutations = currentMutations[className];
                                                          if ([mutations count] != 0) {
                                                              [delegate instancesDidMutate:[NSArray arrayWithArray:mutations]];
                                                          }
                                                      }
                                                  }];
}

- (NSFetchRequest *)fetchRequestForEntityClass:(Class)entityClass
                                 withPredicate:(NSPredicate *)predicate
{
    NSAssert([NSThread isMainThread], @"CoreData fetch not called on main thread");
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(entityClass)];
    if (predicate) {
        [request setPredicate:predicate];
    }
    return request;
}

- (NSArray *)resultsOfFetchWithErrorAlert:(NSFetchRequest *)request
{
    NSError *err = nil;
    NSArray *results = [_context executeFetchRequest:request error:&err];
    if (err) {
        results = nil;
        UIAlertView *alert = [Utils alertViewWithError:err
                                                 title:@"Core Data Fetch"
                                              delegate:nil];
        [alert show];
    }
    return results;
}

- (id)insertNewObjectForEntityClass:(Class)entityClass
{

    return [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(entityClass)
                                         inManagedObjectContext:_context];
}

- (void)deleteObjectsResultingFromFetch:(NSFetchRequest *)request
{
    NSArray *results = [self resultsOfFetchWithErrorAlert:request];
    if (!([results count] != 0)) {
        return;
    }
    [self deleteManagedObjects:results];
}

- (void)deleteManagedObjects:(NSArray *)objectList
{
    [self deleteManagedObjects:objectList saveContext:YES];
}

- (void)deleteManagedObjects:(NSArray *)objectList saveContext:(BOOL)yesNo
{
    for (id object in objectList) {
        [_context deleteObject:object];
    }
    if (yesNo) {
        [self saveContextWithErrorAlert];
    }
}

// All changes in CoreData context are temporary, until it is saved
- (BOOL)saveContextWithErrorAlert
{
    if (![_context hasChanges]) {
        return true;
    }

    NSError *err = nil;
    if (![_context save:&err]) {
        UIAlertView *alert = [Utils alertViewWithError:err
                                                 title:@"Core Data Save"
                                              delegate:nil];
        [alert show];
        return false;
    }
    return true;
}

- (Extension *)extensionObjectWithId:(NSString *)extensionId
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"extensionId == %@", extensionId];
    NSFetchRequest *request = [self fetchRequestForEntityClass:[Extension class] withPredicate:predicate];
    NSArray *results = [self resultsOfFetchWithErrorAlert:request];
    return ([results count] == 1) ? results[0] : nil;
}

- (NSURL *)storeURL
{
    return _storeFileURL;
}

@end
