//
//  ViewController.m
//  ssn
//
//  Created by lingminjun on 14-5-7.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import "ViewController.h"
#import "ssndb.h"
#import "TestModel.h"
#import "ssnbase.h"


@interface ViewController ()
{
    SSNDataBase *sharedb;
    SSNModelManager *manager;
}
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    
   
    
    SSNDataBase *db = [[SSNDataBase alloc] initWithPath:@"test/db.sqlite" version:1];
    [db open];
    [db createTable:@"TestModel" withDelegate:[TestModel class]];
    
    manager = [[SSNModelManager alloc] initWithDataBase:db];
    
    
    
    //[TestModel setManager:self];
    
	// Do any additional setup after loading the view, typically from a nib.
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //TestModel *m = [TestModel modelWithKeyPredicate:@"type = 0 AND uid = '3344422'"];
    
    TestModel *m = [manager modelWithClass:[TestModel class] keyPredicate:@"type = 0 AND uid = '3344422'"];
    
    NSLog(@"%@",m);
    
    NSLog(@"%@",m.name);
    NSLog(@"%@",m.uid);
    NSLog(@"%ld",m.age);
    NSLog(@"%f",m.hight);
    
    NSLog(@"%@",m);
}


//加载某类型实例的数据，keyPredicate意味着是主键，所以只返回一个对象
- (NSDictionary *)model:(SSNModel *)model loadDatasWithPredicate:(NSString *)keyPredicate {
    NSArray *ary = [sharedb queryObjects:nil sql:[NSString stringWithFormat:@"SELECT * FROM TestModel WHERE %@",keyPredicate],nil];
    return [ary lastObject];
}

//更新实例，不包含主键，存储成功请返回YES，否则返回失败
- (BOOL)model:(SSNModel *)model updateDatas:(NSDictionary *)valueKeys forPredicate:(NSString *)keyPredicate {
    
    NSString *setValuesString = [NSString predicateStringKeyAndValues:valueKeys componentsJoinedByString:@","];
    
    [sharedb queryObjects:nil sql:[NSString stringWithFormat:@"UPDATE TestModel SET %@ WHERE %@",setValuesString,keyPredicate],nil];
    
    return YES;
}

//插入实例，如果数据库中已经存在，可以使用replace，也可以返回NO，表示插入失败，根据使用者需要
- (BOOL)model:(SSNModel *)model insertDatas:(NSDictionary *)valueKeys forPredicate:(NSString *)keyPredicate {
    
    NSString *keysString = [[valueKeys allKeys] componentsJoinedByString:@","];
    NSMutableArray *vs = [NSMutableArray array];
    for (NSInteger index = 0; index < [valueKeys count]; index ++) {
        [vs addObject:@"?"];
    }
    NSString *valueString = [vs componentsJoinedByString:@","];
    NSArray *values = [valueKeys objectsForKeys:[valueKeys allKeys] notFoundMarker:[NSNull null]];
    
    [sharedb queryObjects:nil sql:[NSString stringWithFormat:@"INSERT INTO TestModel (%@) VALUES (%@)",keysString,valueString] arguments:values];
    
    return YES;
}

//删除实例
- (BOOL)model:(SSNModel *)model deleteForPredicate:(NSString *)keyPredicate {
    [sharedb queryObjects:nil sql:[NSString stringWithFormat:@"DELETE FROM TestModel WHERE %@",keyPredicate]];
    return YES;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
