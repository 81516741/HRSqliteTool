//
//  TestModel.h
//  HRSqliteModel
//
//  Created by ld on 17/3/10.
//  Copyright © 2017年 ld. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TestModel : NSObject

@property(nonatomic,assign)char charr;
@property(nonatomic,assign)BOOL ok;
@property (nonatomic,assign) CGFloat  height;
@property (nonatomic,assign) NSInteger  age;
@property (nonatomic,copy) NSString * name;
@property (nonatomic,strong) NSArray * array;
@property (nonatomic,strong) NSData * data;
@property (nonatomic,strong) TestModel * model;
@property(nonatomic,copy) NSString * dataID;



@property(nonatomic,strong) NSString * emtyString;
@property(nonatomic,assign) NSInteger emtyInteger;
@property(nonatomic,strong) TestModel * emtyModel;

@end
