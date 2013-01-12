//
//  MUAutoEncodeDecodeObject.h
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

#import "MUAutoEncodeDecodeObject.h"
#import <objc/runtime.h>

@interface MUAutoEncodeDecodeObject(private)

- (NSDictionary*) getPropertiesList;

- (id) getProperiesValue:(NSString*) name;

- (void) setProperies:(NSString*) name value:(id) value;

@end

@implementation MUAutoEncodeDecodeObject

- (void)encodeWithCoder:(NSCoder *)encoder {
    NSDictionary* pDictionary = [self getPropertiesList];
    for (NSString* key in [pDictionary allKeys]) {
        NSString* type = [[pDictionary objectForKey:key] substringWithRange:NSMakeRange(1, 1)];
        
        if ([type isEqualToString:@"@"]) {
            id object = [self getProperiesValue:key];
            if (object != nil 
                && ([object isKindOfClass:[MUAutoEncodeDecodeObject class]] 
                    || [object conformsToProtocol:@protocol(NSCoding)])) {
                    [encoder encodeObject:object forKey:key];
            }
        }
    }
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    
    if (self) {
        NSDictionary* pDictionary = [self getPropertiesList];
        for (NSString* key in [pDictionary allKeys]) {
            NSString* type = [[pDictionary objectForKey:key] substringWithRange:NSMakeRange(1, 1)];
            
            if ([type isEqualToString:@"@"]) {
                id object = [decoder decodeObjectForKey:key];
                if (object != nil) {
                    [self setProperies:key value:object];
                }
            }
        }
    }
    
    return self;
}

#pragma mark - private

- (NSDictionary*) getPropertiesList
{
    unsigned int pCount;
    unsigned int  i;
    Class testClass = [self class];
    objc_property_t *properties = class_copyPropertyList(testClass, &pCount);
    
    NSMutableDictionary* pDictionary = [NSMutableDictionary dictionaryWithCapacity:pCount];
    
    for (i = 0; i < pCount; i++){
        objc_property_t property = properties[i];
        const char* name = property_getName(property);
        const char* attri = property_getAttributes(property);
        [pDictionary setObject:[NSString stringWithUTF8String:attri] 
                        forKey:[NSString stringWithUTF8String:name] ];
    }
    
    free(properties);
    return pDictionary;
}

- (id) getProperiesValue:(NSString*) name
{
    SEL aSelector = NSSelectorFromString(name);
    
    NSMethodSignature *sig= [[self class] instanceMethodSignatureForSelector:aSelector];
    if (sig == nil) {
        return nil;
    }
    
    NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:sig];
    [invocation setTarget:self];
    [invocation setSelector:aSelector];
    [invocation invoke];
    
    const char *returnType = sig.methodReturnType;
    id __unsafe_unretained returnValue = nil;
    
    if( !strcmp(returnType, @encode(id)) ){
        [invocation getReturnValue:&returnValue];
    }
    
    return returnValue;
}

- (void) setProperies:(NSString*) name value:(id) value
{
    NSMutableString* selString = [NSMutableString stringWithString:name];
    [selString replaceCharactersInRange:NSMakeRange(0, 1) 
                             withString:[[selString substringToIndex:1] uppercaseString]];
    [selString appendString:@":"];
    [selString insertString:@"set" atIndex:0];
    
    SEL pSelector = NSSelectorFromString(selString);
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:pSelector withObject:value];
    #pragma clang diagnostic pop
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    id newObject = [[[self class] allocWithZone:zone] init];
    NSDictionary* pDictionary = [self getPropertiesList];
    for (NSString* key in [pDictionary allKeys]) {
        NSString* type = [[pDictionary objectForKey:key] substringWithRange:NSMakeRange(1, 1)];
        
        if ([type isEqualToString:@"@"]) {
            id object = [self getProperiesValue:key];
            if (object != nil
                    && [object conformsToProtocol:@protocol(NSCopying)]) {
                //
                NSMutableString* selString = [NSMutableString stringWithString:key];
                [selString replaceCharactersInRange:NSMakeRange(0, 1)
                                         withString:[[selString substringToIndex:1] uppercaseString]];
                [selString appendString:@":"];
                [selString insertString:@"set" atIndex:0];
                
                SEL pSelector = NSSelectorFromString(selString);
                
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [newObject performSelector:pSelector withObject:[object copy]];
                #pragma clang diagnostic pop
                //
                }
        }
    }
    return newObject;
}

@end
