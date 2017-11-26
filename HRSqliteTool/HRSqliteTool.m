//
//  HRSqliteTool.m
//  HRSqliteTool
//
//  Created by Mac on 2017/4/12.
//  Copyright © 2017年 Mac. All rights reserved.
//

#import "HRSqliteTool.h"

#import "FMDB.h"
#import <objc/runtime.h>
#import <objc/message.h>

typedef NS_ENUM(NSUInteger,HRSqliteToolPropertyType) {
    _Int,
    _Char,
    _Boolean,
    _Double,
    _Float,
    _String,
    _Model,
    _Data,
    _Array,
    _Dictionary
};

typedef NS_ENUM(NSUInteger,HRSqliteToolQueryMethod) {
    _Insert,
    _Delete,
    _Update,
    _Query
};

static NSString * hr_nilString = @"hr_nilString";

@interface HRPropertyModel : NSObject

@property (assign ,nonatomic) HRSqliteToolPropertyType propertyType;
@property (nonatomic,copy) NSString * propertyName;
///基本数据类型会转为string存取
@property (nonatomic,strong) id propertyValue;

@end

@implementation HRPropertyModel

@end

@interface HRSqliteTool()

@property (nonatomic, strong) dispatch_semaphore_t semaphore;//保证操作数据库安全的信号量
@property (nonatomic,strong) NSMutableDictionary * databaseDic;//存储数据库dataBase的字典

@end

@implementation HRSqliteTool

+ (instancetype)share
{
    static HRSqliteTool * _model = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _model = [[HRSqliteTool alloc]init];
        _model.databaseDic = [NSMutableDictionary dictionary];
        _model.semaphore = dispatch_semaphore_create(1);
    });
    return _model;
}

+ (void)hr_deleteTable:(Class)objectClass
{
    NSString * tablePath = [self tablePathOfClass:objectClass];
    [[NSFileManager defaultManager] removeItemAtPath:tablePath error:nil];
}

+ (BOOL)hr_insert:(id)object
{
    id state = [self operateObject:object method:_Insert condition:nil];
    return [state boolValue];
}
+ (BOOL)hr_delete:(Class)objectClass condition:(NSString *)condition
{
    id state = [self operateObject:[objectClass new] method:_Delete condition:condition];
    return [state boolValue];
}
+ (BOOL)hr_update:(Class)objectClass condition:(NSString *)condition
{
    id state = [self operateObject:[objectClass new] method:_Update condition:condition];
    return [state boolValue];
}
+ (NSArray *)hr_query:(Class)objectClass condition:(NSString *)condition
{
    return [self operateObject:[objectClass new] method:_Query condition:condition];
}



+ (id)operateObject:(id)object method:(HRSqliteToolQueryMethod)queryMethod condition:(NSString *)condition
{
    dispatch_semaphore_wait([HRSqliteTool share].semaphore, DISPATCH_TIME_FOREVER);
    id someObject;
    @autoreleasepool {
        //创建并保存数据库
        [self creatAndSaveDatabaseQueue:object];
        //获得目标类所有的属性的属性模型
        NSMutableDictionary * modelPropertyInfoDic = [self getPropertyModelInfoDicIn:object];
        //创建表
        [self creatTableByProperModelInfoDic:modelPropertyInfoDic object:object];
        if (condition == nil) {
            condition = @"";
        }
        switch (queryMethod) {
            case _Insert:
                someObject = [self insertObject:object modelPropertyInfoDic:modelPropertyInfoDic];
                break;
            case _Delete:
                someObject = [self delete:object condition:condition];
                break;
            case _Update:
                someObject = [self update:object condition:condition];
                break;
            case _Query:
                someObject = [self query:object condition:condition modelPropertyInfoDic:modelPropertyInfoDic];
                break;
            default:
                break;
        }
    }
    dispatch_semaphore_signal([HRSqliteTool share].semaphore);
    return someObject;
}

+ (id)insertObject:(id)object modelPropertyInfoDic:(NSDictionary *)modelPropertyInfoDic
{
    //插入数据
    NSString * tableName = [self tableNameByClass:[object class]];
    FMDatabaseQueue * databaseQueue = [[HRSqliteTool share].databaseDic objectForKey:tableName];
    NSMutableString * sqlit = [NSMutableString string];
    [sqlit appendFormat:@"INSERT INTO %@",tableName];
    [sqlit appendFormat:@"("];
    [modelPropertyInfoDic enumerateKeysAndObjectsUsingBlock:^(NSString * propertyName, HRPropertyModel * propertyModel, BOOL * stop) {
        [sqlit appendFormat:@"%@,",propertyName];
    }];
    [sqlit deleteCharactersInRange:NSMakeRange(sqlit.length - 1, 1)];
    [sqlit appendFormat:@")"];
    
    [sqlit appendFormat:@"values("];
    [modelPropertyInfoDic enumerateKeysAndObjectsUsingBlock:^(NSString * propertyName, HRPropertyModel * propertyModel, BOOL * stop) {
        switch (propertyModel.propertyType) {
            case _Array:
            case _Dictionary:
            case _Model:
            {
                NSData * valueData = [NSKeyedArchiver archivedDataWithRootObject:propertyModel.propertyValue];
                NSString * valueString = [valueData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
                [sqlit appendFormat:@"'%@',",valueString];
                break;
            }
            case _Data:
            {
                NSString * valueString = [propertyModel.propertyValue base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
                [sqlit appendFormat:@"'%@',",valueString];
                break;
            }
            case _Float:
            case _Double:
            {
                CGFloat value = [propertyModel.propertyValue floatValue];
                NSString * valueString = [NSString stringWithFormat:@"%d",(int)(value * 1000)];
                [sqlit appendFormat:@"'%@',",valueString];
                break;
            }
            case _Int:
            case _Char:
            case _Boolean:
            {
                [sqlit appendFormat:@"'%@',",propertyModel.propertyValue];
                break;
            }
            case _String:
            {
                NSString * value = propertyModel.propertyValue;
                if (value == nil) {
                    value = hr_nilString;
                }
                [sqlit appendFormat:@"'%@',",value];
                break;
            }
            default:
                break;
        }
    }];
    [sqlit deleteCharactersInRange:NSMakeRange(sqlit.length - 1, 1)];
    [sqlit appendFormat:@")"];
    NSLog(@"-----------插入数据:\n%@",sqlit);
    __block BOOL state = NO;
    [databaseQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            state = [db executeUpdate:sqlit];
            if (state) {
                NSLog(@"-----------插入数据成功(%@)",tableName);
            }
        }
    }];
    return @(state);
}

+ (id)delete:(NSObject *)object condition:(NSString *)condition
{
    NSString * tableName = [self tableNameByClass:[object class]];
    FMDatabaseQueue * databaseQueue = [[HRSqliteTool share].databaseDic objectForKey:tableName];
    NSMutableString * sqlit = [NSMutableString string];
    [sqlit appendFormat:@"DELETE FROM %@ %@",tableName,condition];
    NSLog(@"-----------删除数据:\n%@",sqlit);
    __block BOOL state = NO;
    [databaseQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            state = [db executeUpdate:sqlit];
            if (state) {
                [db executeUpdate:@"VACUUM"];
                NSLog(@"-----------删除数据成功(%@)",tableName);
            }
        }
    }];
    return @(state);
}

+ (id)update:(NSObject *)object condition:(NSString *)condition
{
    NSString * tableName = [self tableNameByClass:[object class]];
    FMDatabaseQueue * databaseQueue = [[HRSqliteTool share].databaseDic objectForKey:tableName];
    NSMutableString * sqlit = [NSMutableString string];
    [sqlit appendFormat:@"UPDATE %@ SET %@",tableName,condition];
    NSLog(@"-----------更新数据库:\n%@",sqlit);
    __block BOOL state = NO;
    [databaseQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            state = [db executeUpdate:sqlit];
            if (state) {
                NSLog(@"-----------更新数据成功(%@)",tableName);
            }
        }
    }];
    return @(state);
}
+ (id)query:(NSObject *)object condition:(NSString *)condition modelPropertyInfoDic:(NSDictionary *)modelPropertyInfoDic
{
    NSString * tableName = [self tableNameByClass:[object class]];
    FMDatabaseQueue * databaseQueue = [[HRSqliteTool share].databaseDic objectForKey:tableName];
    NSMutableString * sqlit = [NSMutableString string];
    [sqlit appendFormat:@"SELECT * FROM %@ %@",tableName,condition];
    NSLog(@"-----------查询数据库:\n%@",sqlit);
    NSMutableArray * modelArray = [NSMutableArray array];
    [databaseQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            FMResultSet * result = [db executeQuery:sqlit];
            while (result.next) {
                NSObject * model = [[object class] new];
                [modelPropertyInfoDic enumerateKeysAndObjectsUsingBlock:^(NSString * propertyName, HRPropertyModel * propertyModel, BOOL * stop) {
                    switch (propertyModel.propertyType) {
                        case _Int:
                        case _Char:
                        {
                            NSString * intString = [result stringForColumn:propertyName];
                            [model setValue:@([intString intValue]) forKey:propertyName];
                            break;
                        }
                        case _Boolean:
                        {
                            NSString * boolString = [result stringForColumn:propertyName];
                            [model setValue:@([boolString boolValue]) forKey:propertyName];
                            break;
                        }
                        case _Double:
                        {
                            NSString * valueString = [result stringForColumn:propertyName];
                            CGFloat value = [valueString intValue] * 0.001;
                            [model setValue:@(value) forKey:propertyName];
                            break;
                        }
                        case _Float:
                        {
                            NSString * floatString = [result stringForColumn:propertyName];
                            [model setValue:@([floatString intValue]) forKey:propertyName];
                            break;
                        }
                        case _String:
                        {
                            NSString * string = [result stringForColumn:propertyName];
                            if ([propertyName isEqualToString:@"dataID"]) {
                                NSString * dataID = [result stringForColumn:@"id"];
                                [model setValue:dataID forKey:propertyName];
                            }
                            if (![string isEqualToString:hr_nilString]) {
                                [model setValue:string forKey:propertyName];
                            }
                            break;
                        }
                        case _Data:
                        {
                            NSString * string = [result stringForColumn:propertyName];
                            NSData * data = [[NSData alloc]initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
                            [model setValue:data forKey:propertyName];
                            break;
                        }
                        case _Array:
                        {
                            NSString * string = [result stringForColumn:propertyName];
                            NSData * data = [[NSData alloc]initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
                            NSArray * array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                            [model setValue:array forKey:propertyName];
                            break;
                        }
                        case _Dictionary:
                        {
                            NSString * string = [result stringForColumn:propertyName];
                            NSData * data = [[NSData alloc]initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
                            NSArray * dic = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                            [model setValue:dic forKey:propertyName];
                            break;
                            
                        }
                        case _Model:
                        {
                            NSString * string = [result stringForColumn:propertyName];
                            NSData * data = [[NSData alloc]initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
                            NSObject * object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                            [model setValue:object forKey:propertyName];
                            break;
                        }
                        default:
                            
                            break;
                    }
                }];
                [modelArray addObject:model];
            }
            
        }
    }];
    return modelArray;
    
}

+ (NSMutableDictionary *)getPropertyModelInfoDicIn:(id)object
{
    Class objectClass = [object class];
    NSMutableDictionary * modelPropertyInfoDic = [NSMutableDictionary dictionary];
    Class superClass = class_getSuperclass(objectClass);
    if (superClass != nil &&
        superClass != [NSObject class]) {
        [modelPropertyInfoDic setValuesForKeysWithDictionary:[self getPropertyModelInfoDicIn:superClass]];
    }
    unsigned int propertyCount = 0;
    objc_property_t * propertys = class_copyPropertyList(objectClass, &propertyCount);
    for (int i = 0; i < propertyCount; i++) {
        objc_property_t property = propertys[i];
        const char * propertyName = property_getName(property);
        const char * propertyAttributes = property_getAttributes(property);
        NSString * propertyNameString = [NSString stringWithUTF8String:propertyName];
        NSString * propertyAttributesString = [NSString stringWithUTF8String:propertyAttributes];
        NSArray * propertyAttributesList = [propertyAttributesString componentsSeparatedByString:@"\""];
#define HRCREATMODELANDSAVE(type)\
HRPropertyModel * propertyModel = [[HRPropertyModel alloc] init];\
propertyModel.propertyName = propertyNameString;\
propertyModel.propertyValue = [object valueForKey:propertyNameString];\
propertyModel.propertyType = type;\
[modelPropertyInfoDic setObject:propertyModel forKey:propertyNameString];
        if (propertyAttributesList.count == 1) {
            // 基本数据类型
            HRSqliteToolPropertyType propertyType = [self parserPropertyTypeWithAttr:propertyAttributesList[0]];
            HRCREATMODELANDSAVE(propertyType)
        }else {
            // 非基本数据类型
            Class class_type = NSClassFromString(propertyAttributesList[1]);
            if (class_type == [NSString class]) {
                HRCREATMODELANDSAVE(_String)
            }else if (class_type == [NSData class]) {
                HRCREATMODELANDSAVE(_Data)
            }else if (class_type == [NSArray class]) {
                HRCREATMODELANDSAVE(_Array)
            }else if (class_type == [NSDictionary class]) {
                HRCREATMODELANDSAVE(_Dictionary)
            }else if (class_type == [NSSet class] ||
                      class_type == [NSValue class] ||
                      class_type == [NSError class] ||
                      class_type == [NSURL class] ||
                      class_type == [NSStream class] ||
                      class_type == [NSScanner class] ||
                      class_type == [NSException class]||
                      class_type == [NSNumber class]||
                      class_type == [NSDate class]) {
                NSAssert(NO, @"检查模型类异常数据类型");
            }else {
                HRCREATMODELANDSAVE(_Model)
            }
        }
    }
    free(propertys);
    return modelPropertyInfoDic;
}

+ (HRSqliteToolPropertyType)parserPropertyTypeWithAttr:(NSString *)attr {
    NSArray * subAttrs = [attr componentsSeparatedByString:@","];
    NSString * firstSubAttr = subAttrs.firstObject;
    firstSubAttr = [firstSubAttr substringFromIndex:1];
    HRSqliteToolPropertyType propertyType = _String;
    const char type = *[firstSubAttr UTF8String];
    switch (type) {
        case 'B':
            propertyType = _Boolean;
            break;
        case 'c':
        case 'C':
            propertyType = _Char;
            break;
        case 's':
        case 'S':
        case 'i':
        case 'I':
        case 'l':
        case 'L':
        case 'q':
        case 'Q':
            propertyType = _Int;
            break;
        case 'f':
            propertyType = _Float;
            break;
        case 'd':
        case 'D':
            propertyType = _Double;
            break;
        default:
            break;
    }
    return propertyType;
}

+ (NSString *)tablePathOfClass:(Class)objectClass
{
    NSString * cachesDirectory = [self createHRSqliteToolCachesDirectory];
    NSString * tableName = [self tableNameByClass:objectClass];
    //加.sqlite方便用SQLite可视化工具查看，不加也可以的
    NSString * tablePath = [NSString stringWithFormat:@"%@%@%@",cachesDirectory,tableName,@".sqlite"];
    return tablePath;
}

+ (NSString *)createHRSqliteToolCachesDirectory
{
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSString * cachesDirectory = [NSString stringWithFormat:@"%@/Library/Caches/HRSqlite/",NSHomeDirectory()];
    NSLog(@"\nHRSqliteTool缓存路径:\n%@",cachesDirectory);
    if (![fileManager fileExistsAtPath:cachesDirectory isDirectory:nil]) {
        [fileManager createDirectoryAtPath:cachesDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return cachesDirectory;
}

+ (NSString *)tableNameByClass:(Class)objectClass
{
    NSString * version = @"v100";
    if ([objectClass respondsToSelector:@selector(hr_cacheVersion)]) {
        version = [self executeNoParameterAndReturnStringSelector:@selector(hr_cacheVersion) objectClass:objectClass];
    }
    NSString * fileName = [NSStringFromClass(objectClass) stringByAppendingString:version];
    return fileName;
    
}

//执行一个无参返回值为NSString的类方法
+ (NSString *)executeNoParameterAndReturnStringSelector:(SEL)selector objectClass:(Class)objectClass
{
    if ([objectClass respondsToSelector:selector]) {
        IMP funcIMP = [objectClass methodForSelector:selector];
        NSString * (*func)(id, SEL) = (void *)funcIMP;
        return func(objectClass, selector);
    }
    return nil;
}

+ (FMDatabaseQueue *)creatAndSaveDatabaseQueue:(id)object
{
    NSString * dataPathString = [self tablePathOfClass:[object class]];
    NSString * tableName = [self tableNameByClass:[object class]];
    FMDatabaseQueue * databaseQueue = [[HRSqliteTool share].databaseDic objectForKey:tableName];
    if (databaseQueue == nil) {
        databaseQueue = [FMDatabaseQueue databaseQueueWithPath:dataPathString];
        [[HRSqliteTool share].databaseDic setObject:databaseQueue forKey:tableName];
    }
    return databaseQueue;
}

+ (void)creatTableByProperModelInfoDic:(NSDictionary *)propertyModelInfoDic object:(id)object
{
    NSString * tableName = [self tableNameByClass:[object class]];
    FMDatabaseQueue * databaseQueue = [[HRSqliteTool share].databaseDic objectForKey:tableName];
    NSMutableString * sqlit = [NSMutableString string];
    [sqlit appendFormat:@"CREATE TABLE IF NOT EXISTS %@(",tableName];
    [sqlit appendFormat:@"id INTEGER PRIMARY KEY AUTOINCREMENT,"];
    [propertyModelInfoDic enumerateKeysAndObjectsUsingBlock:^(NSString * propertyName, HRPropertyModel * propertyModel, BOOL * stop) {
        [sqlit appendFormat:@"%@ TEXT,",propertyName];
    }];
    [sqlit deleteCharactersInRange:NSMakeRange(sqlit.length - 1, 1)];
    [sqlit appendFormat:@")"];
    [databaseQueue inDatabase:^(FMDatabase *db) {
        if ([db open]) {
            BOOL state = [db executeUpdate:sqlit];
            if (state) {
                NSLog(@"创建表格成功(%@)",tableName);
            }
        }
    }];
}

@end
