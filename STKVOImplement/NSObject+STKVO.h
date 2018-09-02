//
//  NSObject+STKVO.h
//  STKVOImplement
//
//  Created by 泽泰 舒 on 2018/8/27.
//  Copyright © 2018年 泽泰 舒. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^STObservingBlock)(id observedObject, NSString *observedKey, id oldValue, id newValue);

@interface NSObject (STKVO)

- (void)st_addObserver:(NSObject *)observer forKey:(NSString *)key withBlock:(STObservingBlock)block;
- (void)st_removeObserver:(NSObject *)observer forKey:(NSString *)key;

@end
