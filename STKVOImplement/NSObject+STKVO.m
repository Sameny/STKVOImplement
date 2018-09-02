//
//  NSObject+STKVO.m
//  STKVOImplement
//
//  Created by 泽泰 舒 on 2018/8/27.
//  Copyright © 2018年 泽泰 舒. All rights reserved.
//

#import <objc/runtime.h>
#import <objc/message.h>

#import "NSObject+STKVO.h"

NSString *const kSTKVOClassPrefix = @"STKVOClass_";
NSString *const kSTKVOObservers = @"STKVOObservers";

@interface STObservedPiece : NSObject

@property (nonatomic, weak)     NSObject            *observer;
@property (nonatomic, copy)     NSString            *key;
@property (nonatomic, copy)     STObservingBlock    block;

@end

@implementation STObservedPiece

- (instancetype)initWithObserver:(NSObject *)observer key:(NSString *)key block:(STObservingBlock)block
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}

@end

// 构造setter的方法名
static NSString * getSetterSelector(NSString *key) {
    if (key.length <= 0) {
        return nil;
    }
    NSString *firstLetter = [[key substringToIndex:1] uppercaseString];
    NSString *restLetter = [key substringFromIndex:1];
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", firstLetter, restLetter];
    return setter;
}

static NSString * getGetterSelector(NSString *setter) {
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    return key;
}

// 构造setter方法
static void st_kvo_setter(id self, SEL _cmd, id newValue) {
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getGetterSelector(setterName);
    
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    id oldValue = [self valueForKey:getterName];
    
    // ** 获取父类，并通过objc_msgSendSuper调用父类的setter方法更新值
    struct objc_super superclass = {
        .receiver = self, // 这个self就是父类的实例，消息的接受者
        .super_class = class_getSuperclass(object_getClass(self))
    };
    // OBJC_EXPORT void objc_msgSendSuper(void /* struct objc_super *super, SEL op, ... */ )
    /*
     * These functions must be cast to an appropriate function pointer type
     * before being called.
     * 该函数需要映射到一个函数指针，而且其参数个数也是看需要而定，我们这里有3个参数，一个消息的接受者superclass，所调用的方法setter，参数是newValue
     */
    // 哈哈，这个像定义Block块一样，是不是？
    void(*st_objc_msgSendSuperCasted)(void*, SEL, id) = (void *)objc_msgSendSuper;
    // 调用执行父类setter方法，更新父类被监听对象的值
    st_objc_msgSendSuperCasted(&superclass, _cmd, newValue);
    
    // 执行完数值更新后，就该通知监听的观察者了
    NSMutableArray <STObservedPiece *>*observerPieces = objc_getAssociatedObject(self, (__bridge const void *)(kSTKVOObservers));
    [observerPieces enumerateObjectsUsingBlock:^(STObservedPiece * _Nonnull piece, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([piece.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                piece.block(self, getterName, oldValue, newValue);
            });
        }
    }];
}

static Class kvo_class_imp(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

@implementation NSObject (STKVO)

- (void)st_addObserver:(NSObject *)observer forKey:(NSString *)key withBlock:(STObservingBlock)block {
    SEL setterSelector = NSSelectorFromString(getSetterSelector(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for key %@", self, key];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        
        return;
    }
    
    Class class = object_getClass(self);
    NSString *className = NSStringFromClass(class);
    if (![className hasPrefix:kSTKVOClassPrefix]) {
        class = [self createKVOClassWithObserveredClassName:className];
        // 更改isa指针，将self的isa指针指向子类，这样当self的setter方法执行的时候，调用的是子类的setter，从而实现了在子类setter中进行通知的功能
        object_setClass(self, class);
    }
    // 判断子类（因为isa指针指向了子类）是否实现了setter方法
    if (![self hasSelector:setterSelector]) {
        const char * types = method_getTypeEncoding(setterMethod);
        class_addMethod(class, setterSelector, (IMP)st_kvo_setter, types);
    }
    
    // 存储通知的内容
    STObservedPiece *piece = [[STObservedPiece alloc] initWithObserver:observer key:key block:block];
    NSMutableArray <STObservedPiece *>*observerPieces = objc_getAssociatedObject(self, (__bridge const void *)(kSTKVOObservers));
    if (!observerPieces) {
        observerPieces = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, (__bridge const void *)(kSTKVOObservers), observerPieces, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observerPieces addObject:piece];
}

- (void)st_removeObserver:(NSObject *)observer forKey:(NSString *)key {
    NSMutableArray <STObservedPiece *>*observerPieces = objc_getAssociatedObject(self, (__bridge const void *)(kSTKVOObservers));
    if (observerPieces) {
        if (!observer) {
            [observerPieces removeAllObjects]; // 移除所有监听
        }
        else {
            __block NSMutableArray <STObservedPiece *>*removePieces = [[NSMutableArray alloc] init];
            [observerPieces enumerateObjectsUsingBlock:^(STObservedPiece * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.observer == observer) {
                    if (key.length > 0) {
                        if ([obj.key isEqualToString:key]) {
                            [removePieces addObject:obj];
                            *stop = YES;
                        }
                    }
                    else {
                        [removePieces addObject:obj];
                    }
                }
            }];
            [observerPieces removeObjectsInArray:removePieces];
        }
        
        // 销毁我们创建的STKVOClass_XXX类，并将self的isa指针重置为原来的类
        if (observerPieces.count == 0) {
            Class kvoClass = object_getClass(self);
            if ([NSStringFromClass(kvoClass) hasPrefix:kSTKVOClassPrefix]) { // 防止多次删除
                Class originalClass = class_getSuperclass(kvoClass);
                object_setClass(self, originalClass);
                objc_disposeClassPair(kvoClass);
            }
        }
    }
}

- (Class)createKVOClassWithObserveredClassName:(NSString *)observeredClassName {
    NSString *kvo_class_name = [kSTKVOClassPrefix stringByAppendingString:observeredClassName];
    Class kvo_class = NSClassFromString(kvo_class_name);
    if (kvo_class) {
        return kvo_class;
    }
    // 如果还没有构造过，就开始构造STKVOClass_XXX类
    // 我们使用构造observeredClass类的一个子类，该函数定义如下
    /*
     * Creates a new class and metaclass.
     * OBJC_EXPORT Class _Nullable
     * objc_allocateClassPair(Class _Nullable superclass, const char * _Nonnull name, size_t extraBytes)
     * 该函数是比较直观的，直接返回创建好的类
     */
    Class observeredClass = object_getClass(self);
    kvo_class = objc_allocateClassPair(observeredClass, kvo_class_name.UTF8String, 0);
    
    // 重写class方法实现，使其返回父类的Class
    Method classMethod = class_getInstanceMethod(kvo_class, @selector(class));
    const char * types = method_getTypeEncoding(classMethod);
    class_addMethod(kvo_class, @selector(class), (IMP)kvo_class_imp, types);
    
    // 创建类之后需要register类
    objc_registerClassPair(kvo_class);
    return kvo_class;
}

- (BOOL)hasSelector:(SEL)selector {
    Class class = object_getClass(self);
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(class, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL sel = method_getName(method);
        if (selector == sel) {
            free(methods);
            return YES;
        }
    }
    free(methods);
    return NO;
}

@end
