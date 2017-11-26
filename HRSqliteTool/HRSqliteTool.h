//
//  HRSqliteTool.h
//  HRSqliteTool
//
//  Created by Mac on 2017/4/12.
//  Copyright © 2017年 Mac. All rights reserved.
//

//
/*
 模型属性的数据类型符合：
 1.整型  2.浮点数（保留3位有效数字） 3.字符串  4.数组  5.字典  6.实现coding协议的对象
 才可以存储
 */

#import <UIKit/UIKit.h>

/// 数据库协议信息  存入数据可以的模型应该包含协议中的方法和属性
@protocol HRSqliteProtocol <NSObject>
@optional
+ (NSString *)hr_cacheVersion;
@property(nonatomic,copy) NSString * dataID;

@end

@interface HRSqliteTool : NSObject

+ (void)hr_deleteTable:(Class)objectClass;

/**
 模型插入数据可以
 
 @param object 对象
 @return 是否成功
 */
+ (BOOL)hr_insert:(id)object;

/**
 删除数据
 
 @param objectClass 模型类
 @param condition 删除条件
 @return 删除状态
 condition常用查询提示：1.WHERE age = '18'
 */
+ (BOOL)hr_delete:(Class)objectClass condition:(NSString *)condition;

/**
 更新数据库
 
 @param objectClass 模型类
 @param condition 更新条件
 @return 更新状态
 condition常用查询提示：1.把age = 74 的对对象 ok 设置为NO    @"ok = 'NO' WHERE age = '74'"
 */
+ (BOOL)hr_update:(Class)objectClass condition:(NSString *)condition;

/**
 查询数据库
 
 @param objectClass 模型类
 @param condition 查询条件
 @return 模型数组
 condition常用查询提示：1.单个条件查询
 @"WHERE age = '14'"
 2.多个条件查询
 @"WHERE age = '14' AND name = 'lingda'"
 3.查询的数据按照那个属性排序
 @"ORDER BY age DESC" 升序  或者  @"ORDER BY age ASC"降序
 4.结合
 @"WHERE age = '14' AND name = 'lingda' ORDER BY age DESC"
 */
+ (NSArray *)hr_query:(Class)objectClass condition:(NSString *)condition;

@end

