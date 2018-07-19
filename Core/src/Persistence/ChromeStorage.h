//
//  ChromeStorage.h
//  Kitt
//
//  Created by Pavel Zdenek on 22.10.13.
//  Copyright (c) 2013 Browser Technology s.r.o. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ChromeStorageMutationDelegate <NSObject>

-(NSString*)storageIdentifier;

-(void)storageDataChanged:(NSDictionary*)dataDictionary;

@end
