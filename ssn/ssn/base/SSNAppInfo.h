//
//  SSNAppInfo.h
//  ssn
//
//  Created by lingminjun on 15/5/24.
//  Copyright (c) 2015年 lingminjun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SSNAppInfo : NSObject

/**
 *  获取当前app名字
 *
 *  @return app名字
 */
+ (NSString *)appName;

/**
 *  获取当前app名字
 *
 *  @return app名字
 */
+ (NSString *)appLocalizedName;

/**
 *  返回app版本，如：1.0.0
 *
 *  @return app版本
 */
+ (NSString *)appVersion;

/**
 *  返回app辅助版本号，流水号
 *
 *  @return app的流水版本号
 */
+ (NSString *)appBuildNumber;

/**
 *  完整版本号 appVersion (appBuildNumber)
 *
 *  @return 完整版本号
 */
+ (NSString *)appFullVersion;


/**
 *  app的BundleId
 *
 *  @return app的BundleId
 */
+ (NSString *)appBundleId;

/**
 *  客户端型号
 *
 *  @return 客户端型号
 */
+ (NSString *)userAgent;

/**
 *  设备版本号
 *
 *  @return 设备版本号
 */
+ (NSString *)device;


@end
