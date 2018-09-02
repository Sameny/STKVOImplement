//
//  ViewController.m
//  STKVOImplement
//
//  Created by 泽泰 舒 on 2018/8/27.
//  Copyright © 2018年 泽泰 舒. All rights reserved.
//

#import "NSObject+STKVO.h"
#import "ViewController.h"

@interface Person : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSMutableArray <NSString *>*nicks;
@property (nonatomic, assign) NSInteger age;

@end

@implementation Person
+ (instancetype)personWithName:(NSString *)name age:(NSInteger)age {
    Person *person = [[Person alloc] init];
    person.name = name;
    person.age = age;
    return person;
}

- (NSMutableArray<NSString *> *)nicks {
    if (!_nicks) {
        _nicks = [[NSMutableArray alloc] init];
    }
    return _nicks;
}

@end

@interface ViewController ()
@property (nonatomic, strong) Person *person;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.person st_addObserver:self forKey:@"name" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"name = %@", newValue);
    }];
    [self.person st_addObserver:self forKey:@"nicks" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"nicks = %@", newValue);
        NSLog(@"***********************");
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(personGrown)];
    [self.view addGestureRecognizer:tap];
}

- (void)dealloc {
    [self.person st_removeObserver:self forKey:nil];
}

- (void)personGrown {
    NSLog(@"***********************");
    self.person.age++;
    NSArray *names = @[@"shuzt", @"laoniu", @"atai", @"sameny"];
    self.person.name = names[self.person.age%4];
    [[self.person mutableArrayValueForKey:@"nicks"] addObject:self.person.name];
    if (self.person.age > 33) {
        NSLog(@"remove observers");
        [self.person st_removeObserver:self forKey:nil];
    }
}

- (Person *)person {
    if (!_person) {
        _person = [Person personWithName:@"sameny" age:27];
    }
    return _person;
}

@end
