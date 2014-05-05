//
//  NSError+NTJsonStorePrivate.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 5/1/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <sqlite3.h>
#import <Foundation/Foundation.h>


@interface NSError (NTJsonStorePrivate)

+(instancetype)NSJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode;
+(instancetype)NSJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode message:(NSString *)message;
+(instancetype)NSJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode format:(NSString *)format, ...;

+(instancetype)NSJsonStore_errorWithSqlite3:(sqlite3 *)db;

@end
