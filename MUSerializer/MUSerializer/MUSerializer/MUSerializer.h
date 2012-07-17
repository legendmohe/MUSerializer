//
//  MUBeanSerializer.h
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

#import <Foundation/Foundation.h>
#import "FMDatabase.h"

@interface MUSerializer : NSObject{
    NSOperationQueue* _diskOperationQueue;
    
    NSMutableDictionary* _cacheDictionary;
    
    NSMutableDictionary* _dataKeyQuickTable;
}

+ (MUSerializer*)shareInstance;

+ (NSString*)MUBeanSerializerDirectory;

- (void) removeSerializeDataForKey:(id) aKey;
- (void) removeSerializeDataForKeyArray:(NSArray*) keyArray;
- (BOOL)hasSerializeKey:(NSString*)aKey;
- (void)cleanSerializeData;
- (void)cleanCache;

//object methods
- (NSData*)deserializeDataFromDatabaseForKey:(NSString*)aKey;
- (void) serializeObject:(id<NSCoding>) object forKey:(id) aKey;
- (void) serializeObject:(id<NSCoding>) object forKey:(id) aKey timeInterval:(NSTimeInterval) timeInterval;
- (id) deserializeObjectforKey:(id) aKey useCache:(BOOL) isUseCache;
- (id) deserializeTimeIntervalObjectforKey:(id) aKey useCache:(BOOL) isUseCache;

//image methods

- (void) serializeImage:(UIImage*) anImage forKey:(id) aKey;
- (UIImage*) deserializeImageforKey:(id) aKey;

@end
