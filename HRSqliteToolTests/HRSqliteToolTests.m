//
//  HRSqliteToolTests.m
//  HRSqliteToolTests
//
//  Created by Mac on 2017/4/12.
//  Copyright © 2017年 Mac. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TestModel.h"
#import "HRSqliteTool.h"

@interface HRSqliteToolTests : XCTestCase

@end

@implementation HRSqliteToolTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)testInsert
{
    TestModel * model = [TestModel new];
    model.name = @"fasd";
    model.age = arc4random() % 100;
    model.height = (arc4random() % 100) * 0.01;
    model.array = @[@"fda"];
    model.data = [[NSString stringWithFormat:@"%ld",model.age] dataUsingEncoding:NSUTF8StringEncoding];
    model.ok = NO;
    model.model = model;
    BOOL ok = [HRSqliteTool hr_insert:model];
    
    NSAssert(ok, @"insert错误");
}

- (void)testInsertTime
{
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 200; i ++) {
            TestModel * model = [TestModel new];
            model.name = @"fasd";
            model.age = arc4random() % 100;
            model.height = (arc4random() % 100) * 0.01;
            model.array = @[@"fda"];
            model.data = [[NSString stringWithFormat:@"%ld",model.age] dataUsingEncoding:NSUTF8StringEncoding];
            model.ok = NO;
            model.model = model;
            [HRSqliteTool hr_insert:model];
        }
    }];
    
}

- (void)testDelete
{
    BOOL ok =[HRSqliteTool hr_delete:[TestModel class] condition:nil];
    NSAssert(ok, @"delete错误");
}
- (void)testDeleteTime
{
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        [HRSqliteTool hr_delete:[TestModel class] condition:nil];
    }];
    
}
- (void)testUpdate
{
    BOOL ok = [HRSqliteTool hr_update:[TestModel class] condition:@"ok = 'YES'"];
    NSAssert(ok, @"update错误");
}
- (void)testUpdateTime
{
    [self measureBlock:^{
        [HRSqliteTool hr_update:[TestModel class] condition:@"ok = 'YES'"];
    }];
    
}
- (void)testQuery
{
    NSArray * array = [HRSqliteTool hr_query:[TestModel class] condition:nil];
    NSAssert(array.count > 0, @"update错误");
}
- (void)testQueryTime
{
    [self measureBlock:^{
        [HRSqliteTool hr_query:[TestModel class] condition:nil];
    }];
    
}

@end
