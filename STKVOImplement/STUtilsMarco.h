//
//  STUtilsMarco.h
//  st_MarcoAddProtpertyToCategory
//
//  Created by 泽泰 舒 on 2018/8/22.
//  Copyright © 2018年 泽泰 舒. All rights reserved.
//

#ifndef STUtilsMarco_h
#define STUtilsMarco_h


// ********* 自动添加类别的属性方法
#import <objc/runtime.h>
#define st_metamacro_concat(A, B) st_metamacro_concat_(A, B)
#define st_metamacro_concat_(A, B) A##B

#define __st_BOOL_value(__number) [__number boolValue]
#define __st_int_value(__number) [__number intValue]
#define __st_NSInteger_value(__number) [__number integerValue]
#define __st_NSUInteger_value(__number) [__number unsignedIntegerValue]
#define __st_float_value(__number) [__number floatValue]
#define __st_CGFloat_value(__number) [__number floatValue]
#define __st_double_value(__number) [__number doubleValue]

#define st_property_basicDataType(__type, __name) \
property (nonatomic, assign, setter=set__##__name:, getter=__##__name) __type __name;

#define st_property_basicDataType_method(__type, __name) \
- (__type)__##__name \
{\
NSNumber *number = objc_getAssociatedObject(self, #__name);\
return st_metamacro_concat(st_metamacro_concat(__st_, __type), _value)(number);\
}\
\
- (void)set__##__name:(__type)__##__name \
{\
objc_setAssociatedObject(self, #__name, @(__##__name), OBJC_ASSOCIATION_RETAIN_NONATOMIC);\
}

#define st_property_object(__type, __name) \
property (nonatomic, strong, setter=set__##__name:, getter=__##__name) __type* __name;

#define st_property_object_method(__type, __name) \
- (__type *)__##__name \
{\
return objc_getAssociatedObject(self, #__name);\
}\
\
- (void)set__##__name:(__type *)__##__name \
{\
objc_setAssociatedObject(self, #__name, __##__name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);\
}


#endif /* STUtilsMarco_h */
