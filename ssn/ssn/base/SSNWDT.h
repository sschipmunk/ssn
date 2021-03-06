//
//  SSNWDT.h
//  ssn
//
//  Created by lingminjun on 15/6/8.
//  Copyright (c) 2015年 lingminjun. All rights reserved.
//

#import <Foundation/Foundation.h>

//计时单位
typedef NS_ENUM(NSUInteger, SSNWDTIntervalUnit) {
    SSNWDTDailyUnit,//按天计算
    SSNWDTHourUnit, //按小时计算
    SSNWDTWeekUnit, //按周计算 
};

typedef BOOL SSNWDTTaskSuccess;//重试任务成功

@class SSNWDT;

/**
 *  任务触发
 */
@protocol SSNWDTTaskDelegate <NSObject>
@optional
/**
 *  任务触发回调
 *
 *  @param WDT    触发器
 *  @param result 通知触发器结果，务必回调，否则，重试失效
 */
- (void)scheduledTaskTriggerWDT:(SSNWDT *)WDT result:(void(^)(SSNWDTTaskSuccess success))result;
@end

/**
 *  长时间计时器
 */
@interface SSNWDT : NSObject

@property (nonatomic,copy,readonly) NSString *identify;//标记

@property (nonatomic,readonly) SSNWDTIntervalUnit unit;//计时单位

@property (nonatomic,readonly) NSUInteger interval;//触发间隔时间

@property (nonatomic) NSUInteger retry;//重试间隔时间，若任务没有成功，则会在retry秒后重试，[0,1800]，传入0时表示不重试

//block和委托，可同时使用，但是只要有一个成功，将不会重试
@property (nonatomic,copy) void (^scheduledTask)(SSNWDT *WDT,void(^result)(SSNWDTTaskSuccess success));//预设的任务，
@property (nonatomic,weak) id<SSNWDTTaskDelegate> delegate;//委托

/**
 *  唯一初始化
 *
 *  @param identify 标签
 *  @param uint     计时单位
 *  @param interval 触发间隔时间
 *
 *  @return wdt
 */
- (instancetype)initWithIdentify:(NSString *)identify unit:(SSNWDTIntervalUnit)uint interval:(NSUInteger)interval;

/**
 *  工厂方法
 *
 *  @param identify 标签
 *  @param uint     计时单位
 *  @param interval 触发间隔时间
 *
 *  @return wdt
 */
+ (instancetype)WDTWithIdentify:(NSString *)identify unit:(SSNWDTIntervalUnit)uint interval:(NSUInteger)interval;

/**
 *  启动，第一次启动会触发回调，启动成功后对象 自引用 （不会被释放），
 *
 *  @return 同一个identify 的 SSNWDT 已经启动过后忽略此方法，返回no，成功操作返回yes
 */
- (BOOL)launch;

@end
