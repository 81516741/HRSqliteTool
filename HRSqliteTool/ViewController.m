//
//  ViewController.m
//  HRSqliteTool
//
//  Created by Mac on 2017/4/12.
//  Copyright © 2017年 Mac. All rights reserved.
//

#import "ViewController.h"
#import "HRSqliteTool.h"
#import "TestModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    for (int i = 0; i < 5; i++) {
        TestModel * model = [TestModel new];
        model.age = 13;
        model.name = @"fd";
        [HRSqliteTool hr_insert:model];
        
    }

    NSArray * aaa = [HRSqliteTool hr_query:[TestModel class] condition:nil];
}

@end
