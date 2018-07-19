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
 Wrapper of basic CoreData operations over one specific database
 "BrowserState".
 
 @todo this class doesn't show off any significant designing. It was simply
 ripped out of the existing logic hardcoded for omnibox history. Namely spitting out
 one-off alertviews instead of returning NSError is a simplistic feature.
 It obviously could use some database file parameterisation and
 better thinking about the API.
 */

#import <CoreData/CoreData.h>

@class Extension;

@protocol CoreDataMutationDelegate <NSObject>

- (Class)managedObjectClassOfInterest;
- (void)instancesDidMutate:(NSArray *)mutations;

@end

@interface BrowserStateCoreData : NSObject

- (void)addMutationDelegate:(id<CoreDataMutationDelegate>)delegate;

/**
 It does same as method addMutationDelegate, but it returns flag set to yes if new database was created.
 */
- (BOOL)succeededStoreSetupWithFeedback:(BOOL *)storeCreated;

/**
 * @param entityClass class type to instantiate with fetch
 * @param predicate to fill the fetch request
 * @return constructed fetch request
 */
- (NSFetchRequest *)fetchRequestForEntityClass:(Class)entityClass
                                 withPredicate:(NSPredicate *)predicate;

/**
 * Error-guarded execution of fetch request
 */
- (NSArray *)resultsOfFetchWithErrorAlert:(NSFetchRequest *)request;

/**
 * Self contained deleting of elements from db. Calls deleteManagedObjects.
 */
- (void)deleteObjectsResultingFromFetch:(NSFetchRequest *)request;

/**
 * Does synchronize the db.
 */
- (void)deleteManagedObjects:(NSArray *)objectList;

- (void)deleteManagedObjects:(NSArray *)objectList saveContext:(BOOL)yesNo;

/**
 * Creates new object of given class type to be stored in the db
 */
- (id)insertNewObjectForEntityClass:(Class)entityClass;
/**
 * Error-guarded synchronization of db changes
 */
- (BOOL)saveContextWithErrorAlert;

/**
 * Fetch Extension object of given id string.
 */
- (Extension *)extensionObjectWithId:(NSString *)extensionId;

// Exposed for testing
- (NSURL *)storeURL;

@property (strong, nonatomic) NSManagedObjectContext *context; // public because of Swift bindings

@end
