//
//  MUBeanSerializer.m
//  MyUtil
//
//  Created by  on 12-4-28.
//  Copyright (c) 2012年 doublesix All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "MUSerializer.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"

#define kMUBeanSerializerDatabaseTimeIntervalTableCreate @"CREATE TABLE OBJECT_TIMEINTERVAL_TABLE (ObjectKey text PRIMARY KEY, TimeInterval real)"

#define kMUBeanSerializerDatabaseDataTableCreate @"CREATE TABLE OBJECT_DATA_TABLE (DataKey text PRIMARY KEY, data blob)"

#define kMUBeanSerializerDatabaseFetchTimeIntervalQuery @"SELECT TimeInterval FROM OBJECT_TIMEINTERVAL_TABLE WHERE ObjectKey = ?"

#define kMUBeanSerializerDatabaseFetchAllTimeIntervalsQuery @"SELECT * FROM OBJECT_TIMEINTERVAL_TABLE"

#define kMUBeanSerializerDatabaseFetchAllDataKeyQuery @"SELECT DataKey FROM OBJECT_DATA_TABLE"

#define kMUBeanSerializerDatabaseFetchDataByKeyQuery @"SELECT data FROM OBJECT_DATA_TABLE WHERE DataKey = ?"

#define kMUBeanSerializerDatabaseFetchKeyByKeyQuery @"SELECT DataKey FROM OBJECT_DATA_TABLE WHERE DataKey = ?"

#define kMUBeanSerializerDatabaseSetTimeIntervalForKeyUpdate @"REPLACE INTO OBJECT_TIMEINTERVAL_TABLE VALUES (?, ?)"

#define kMUBeanSerializerDatabaseSetDataForKeyUpdate @"REPLACE INTO OBJECT_DATA_TABLE VALUES (?, ?)"

#define kMUBeanSerializerDatabaseDeleteDataForKeyUpdate @"DELETE FROM OBJECT_DATA_TABLE WHERE DataKey = ?"

#define kMUBeanSerializerDatabaseCleanOverDueUpdate @"DELETE FROM OBJECT_TIMEINTERVAL_TABLE WHERE TimeInterval < ?"

static MUSerializer* __instance;

static NSString* _serializeDirectory;

static inline NSString* MUBeanSerializerDirectory() {
	if(!_serializeDirectory) {
		NSString* cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		_serializeDirectory = [[[cachesDirectory stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]] stringByAppendingPathComponent:@"MUBeanSerializer"] copy];
	}
    
	return _serializeDirectory;
}

static inline NSString* pathForKey(NSString* aKey) {
	return [MUBeanSerializerDirectory() stringByAppendingPathComponent:aKey];
}

@interface MUSerializer(private)

- (BOOL)insertDataToDatabase:(NSData*) data forKey:(NSString*) aKey;
- (BOOL)deleteDataForKey:(NSString *) aKey;

//database
- (BOOL)setupDataBase;
- (FMDatabase*)builtDataBase;
- (BOOL)setupDataKeyQuickTable;
- (NSTimeInterval) timeIntervalForKey:(NSString*) aKeyString;
- (BOOL) setTimeIntervalForKey:(NSString*) aKeyString timeInterval:(NSTimeInterval) timeInterval;
- (NSString*) lastErrorInformation:(FMDatabase*) database;
- (void) cleanOverdueObject;

//operation

- (void)performDiskWriteOperation:(NSInvocation *)invoction;

@end

@implementation MUSerializer

+ (NSString*)MUBeanSerializerDirectory
{
    return MUBeanSerializerDirectory();
}

+ (MUSerializer*)shareInstance {
    
    if (!__instance) {
        @synchronized(self) {
            if(!__instance) {
                __instance = [[MUSerializer alloc] init];
            }
        }
    }
    
	return __instance;
}

- (id) init{
    self = [super init];
    if (self) {
        [[NSFileManager defaultManager] createDirectoryAtPath:MUBeanSerializerDirectory() 
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:NULL];
        
        _diskOperationQueue = [[NSOperationQueue alloc] init];
        [_diskOperationQueue setMaxConcurrentOperationCount:10];
        
        _cache = [[NSCache alloc] init];
        
        _checkExistLock = [[NSLock alloc] init];
        _dataKeyQuickTable = [[NSMutableDictionary alloc] init];
        
        [self setupDataKeyQuickTable];
        
        [self setupDataBase];
        
        [self cleanOverdueObject];
    }
    return self;
}

#pragma mark - database

- (BOOL)setupDataBase
{
    FMDatabase* aDatabase = [self builtDataBase];
    if (![aDatabase tableExists:@"OBJECT_TIMEINTERVAL_TABLE"]) {
        if ([aDatabase executeUpdate:kMUBeanSerializerDatabaseTimeIntervalTableCreate]) {
            NSLog(@"creat table:OBJECT_TIMEINTERVAL_TABLE.");
            
            //dont return YES here
        }else {
            NSLog(@"creat table:OBJECT_TIMEINTERVAL_TABLE falid!");
            return NO;
        };
    }
    if (![aDatabase tableExists:@"OBJECT_DATA_TABLE"]) {
        if ([aDatabase executeUpdate:kMUBeanSerializerDatabaseDataTableCreate]) {
            NSLog(@"creat table:OBJECT_DATA_TABLE.");
            
            return YES;
        }else {
            NSLog(@"creat table:OBJECT_DATA_TABLE falid!");
            return NO;
        };
    }
    
    return YES;
}

- (FMDatabase*)builtDataBase
{
    
    FMDatabase *aDatabase = [FMDatabase databaseWithPath:pathForKey(@"sodb.db")];
    
    if (![aDatabase open]) {
        NSLog(@"open database faild.");
        
        return nil;
    }
    
    return aDatabase;
}

- (BOOL)setupDataKeyQuickTable
{
    FMDatabase* aDatabase = [self builtDataBase];
    FMResultSet* result = [aDatabase executeQuery:kMUBeanSerializerDatabaseFetchAllDataKeyQuery];

    if (result == nil) {
        NSLog(@"no content for DataKeyQuickTable");
        return NO;
    }
    
    while ([result next]) {
        [_dataKeyQuickTable setObject:[NSNumber numberWithBool:YES] forKey:[result stringForColumnIndex:0]];
    }
    return YES;
}

- (NSTimeInterval) timeIntervalForKey:(NSString*) aKeyString
{
    if (aKeyString == nil) {
        return -1;
    }
    
    FMDatabase* aDatabase = [self builtDataBase];
    
    return [aDatabase doubleForQuery:kMUBeanSerializerDatabaseFetchTimeIntervalQuery, aKeyString];
}

- (BOOL) setTimeIntervalForKey:(NSString*) aKeyString timeInterval:(NSTimeInterval) timeInterval
{
    if (aKeyString == nil) {
        return NO;
    }
    
    FMDatabase* aDatabase = [self builtDataBase];
    
    BOOL success = [aDatabase executeUpdate:kMUBeanSerializerDatabaseSetTimeIntervalForKeyUpdate, aKeyString, [NSNumber numberWithDouble:timeInterval]];
    if (!success) {
        NSLog(@"setTimeIntervalForKey error:%@", [self lastErrorInformation:aDatabase]);
        
        return NO;
    }
    
    return YES;
}

- (void) cleanOverdueObject
{
    FMDatabase* aDatabase = [self builtDataBase];
    
    FMResultSet *result = [aDatabase executeQuery:kMUBeanSerializerDatabaseFetchAllTimeIntervalsQuery];
    
    if (result == nil) {
        NSLog(@"cleanOverdueObject error:%@", [self lastErrorInformation:aDatabase]);
        return;
    }
    
    NSMutableArray* removeKeyArray = [[NSMutableArray alloc] init];
    double aTime = [[NSDate date] timeIntervalSince1970];
    while ([result next]) {
        NSTimeInterval time = [result doubleForColumnIndex:1];
        if (aTime > time) {
            [removeKeyArray addObject:[result stringForColumnIndex:0]];
        }
    }
    
    if ([removeKeyArray count] != 0) {
        [self removeSerializeDataForKeyArray:removeKeyArray];
        
        BOOL success = [aDatabase executeUpdate:kMUBeanSerializerDatabaseCleanOverDueUpdate, [NSNumber numberWithDouble:aTime]];
        if (!success) {
            NSLog(@"cleanOverdueObject error:%@", [self lastErrorInformation:aDatabase]);
        }
    }
}

#pragma mark - last error

- (NSString*) lastErrorInformation:(FMDatabase*) database
{
    NSError* error = [database lastError];
    if (error != nil) {
        return [NSString stringWithFormat:@"error code:%d, info:%@", [database lastErrorCode], [database lastErrorMessage]];
    }
    return nil;
}

#pragma mark - methods

- (BOOL)hasSerializeKey:(NSString*)aKey {
	if (aKey == nil) {
        NSLog(@"SEL:%@ info:nil key.", NSStringFromSelector(_cmd));
        return NO;
    }
    
    if ([_dataKeyQuickTable objectForKey:aKey]) {
        return YES;
    }else {
        return NO;
    }
}

- (void)cleanSerializeData
{
    [_diskOperationQueue cancelAllOperations];
    _diskOperationQueue = nil;
    
    BOOL isSucceed = [[NSFileManager defaultManager] removeItemAtPath:MUBeanSerializerDirectory() error:nil];
    if (!isSucceed) {
        NSLog(@"clean MUBeanSerializerDirectory faild.");
    }
    [_checkExistLock lock];
    [_dataKeyQuickTable removeAllObjects];
    _dataKeyQuickTable = nil;
    [_checkExistLock unlock];
//    [_cacheLock lock];
//    [_cacheDictionary removeAllObjects];
//    _cacheDictionary = nil;
//    [_cacheLock unlock];
    [_cache removeAllObjects];
    
    __instance = nil;
}
- (void) cleanCache
{
//    [_cacheLock lock];
//    [_cacheDictionary removeAllObjects];
//    [_cacheLock unlock];
    [_cache removeAllObjects];
}

- (void) removeSerializeDataForKey:(id) aKey
{
    if([self hasSerializeKey:aKey]) {
        [self deleteDataForKey:aKey];
	} else {
		return;
	}
}
- (void) removeSerializeDataForKeyArray:(NSArray*) keyArray
{
    if (keyArray == nil || [keyArray count] == 0) {
        return;
    }
    
    FMDatabaseQueue *aQueue = [FMDatabaseQueue databaseQueueWithPath:pathForKey(@"sodb.db")];
    
    [aQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        for (NSString* key in keyArray) {
            BOOL success = [db executeUpdate:kMUBeanSerializerDatabaseDeleteDataForKeyUpdate, key];
            if (!success) {
                NSLog(@"removeSerializeDataForKeyArray error:%@", [self lastErrorInformation:db]);
                continue;
            }
            
            [_checkExistLock lock];
            [_dataKeyQuickTable removeObjectForKey:key];
            [_checkExistLock unlock];
        }
    }];
    
    [aQueue close];
}

#pragma mark - data methods

- (void)serializeData:(NSData*)data forKey:(NSString*)aKey {
    
    NSString* path = aKey;
    NSMethodSignature* sign = [self methodSignatureForSelector:@selector(insertDataToDatabase:forKey:)];
	NSInvocation* writeInvocation = [NSInvocation invocationWithMethodSignature:sign];
	[writeInvocation setTarget:self];
	[writeInvocation setSelector:@selector(insertDataToDatabase:forKey:)];
	[writeInvocation setArgument:&data atIndex:2];
	[writeInvocation setArgument:&path atIndex:3];
	
	[self performDiskWriteOperation:writeInvocation];
}

- (NSData*)deserializeDataFromDatabaseForKey:(NSString*)aKey {
    
    if (aKey == nil) {
        NSLog(@"SEL:%@ info:nil key.", NSStringFromSelector(_cmd));
        return nil;
    }
    
    FMDatabase* aDatabase = [self builtDataBase];
    NSData* resultData = [aDatabase dataForQuery:kMUBeanSerializerDatabaseFetchDataByKeyQuery, aKey];
    
	if(resultData) {
		return resultData;
	} else {
		return nil;
	}
}

#pragma mark - private

- (BOOL)insertDataToDatabase:(NSData*) data forKey:(NSString*) aKey
{
    if (aKey == nil) {
        NSLog(@"SEL:%@ info:nil key.", NSStringFromSelector(_cmd));
        return NO;
    }
    
    FMDatabase* aDatabase = [self builtDataBase];
    
    BOOL success = [aDatabase executeUpdate:kMUBeanSerializerDatabaseSetDataForKeyUpdate, aKey, data];
    if (!success) {
        NSLog(@"insertDataToDatabase error:%@", [self lastErrorInformation:aDatabase]);
        
        return NO;
    }
    
    [_checkExistLock lock];
    [_dataKeyQuickTable setObject:[NSNumber numberWithBool:YES] forKey:aKey];
    [_checkExistLock unlock];
    
    return YES;
}

- (BOOL)deleteDataForKey:(NSString *) aKey {
	if (aKey == nil) {
        NSLog(@"SEL:%@ info:nil key.", NSStringFromSelector(_cmd));
        return NO;
    }
    
    FMDatabase* aDatabase = [self builtDataBase];
    
    BOOL success = [aDatabase executeUpdate:kMUBeanSerializerDatabaseDeleteDataForKeyUpdate, aKey];
    if (!success) {
        NSLog(@"deleteDataForKey error:%@", [self lastErrorInformation:aDatabase]);
        
        return NO;
    }
    
    [_checkExistLock lock];
    [_dataKeyQuickTable removeObjectForKey:aKey];
    [_checkExistLock unlock];
    
    return YES;
}

- (void)performDiskWriteOperation:(NSInvocation *)invoction {
	NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithInvocation:invoction];
	[_diskOperationQueue addOperation:operation];
}

#pragma mark - object methods

- (void) serializeObject:(id<NSCoding>) object forKey:(id) aKey
{
    NSData* objectData = [NSKeyedArchiver archivedDataWithRootObject:object];
    [self serializeData:objectData forKey:aKey];
}

- (id) deserializeObjectforKey:(id) aKey useCache:(BOOL)isUseCache
{
    if (isUseCache) {
        id object = [_cache objectForKey:aKey];
        if (object != nil) {
            return object;
        }
    }
    if ([self hasSerializeKey:aKey]) {
        id anObject = [NSKeyedUnarchiver unarchiveObjectWithData:[self deserializeDataFromDatabaseForKey:aKey]];
        if (isUseCache) {
            [_cache setObject:anObject forKey:aKey];
        }
        return anObject;
    }
    return nil;
}

- (void) serializeObject:(id<NSCoding>) object forKey:(id) aKey timeInterval:(NSTimeInterval) timeInterval
{
    NSTimeInterval targetTimeIntv = [[NSDate date] timeIntervalSince1970] + timeInterval;
    
    [self setTimeIntervalForKey:aKey timeInterval:targetTimeIntv];
    [self serializeObject:object forKey:aKey];
}

- (id) deserializeTimeIntervalObjectforKey:(id) aKey useCache:(BOOL) isUseCache
{
    if (![self hasSerializeKey:aKey]) {
        return nil;
    }
    
    NSTimeInterval aTimeIntv = [self timeIntervalForKey:aKey];
    if ([[NSDate date] timeIntervalSince1970] > aTimeIntv) {
        return nil;
    }
    
    return [self deserializeObjectforKey:aKey useCache:isUseCache];
}

#pragma mark - image methods

- (void) serializeImage:(UIImage*) anImage forKey:(id) aKey
{
//    [self serializeData:UIImagePNGRepresentation(anImage) forKey:aKey];
    [self serializeData:UIImageJPEGRepresentation(anImage, 1) forKey:aKey];
}
- (UIImage*) deserializeImageforKey:(id) aKey
{
    NSData* imageData = [self deserializeDataFromDatabaseForKey:aKey];
    return [UIImage imageWithData:imageData];
}


@end
