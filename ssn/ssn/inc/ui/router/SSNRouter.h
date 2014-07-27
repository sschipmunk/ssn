//
//  SSNRouter.h
//  ssn
//
//  Created by lingminjun on 14-7-26.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SSNPage.h"

@protocol SSNRouterDelegate;

@interface SSNRouter : NSObject

@property (nonatomic,weak) id<SSNRouterDelegate> delegate;

@property (nonatomic,strong) UIWindow *window;//window的rootViewController将作为第一个目录

@property (nonatomic,strong) NSString *scheme;//app内部scheme

//open url接口，与app不符的scheme将提交给Application打开
- (BOOL)openURL:(NSURL*)url;//如果url query中没有animated，默认有动画
- (BOOL)openURL:(NSURL*)url query:(NSDictionary *)query animated:(BOOL)animated;

//返回
- (void)back;

/*url中path都已经被注册过且仅仅最后一个路径元素没有被找到实例的，都将返回yes*/
- (BOOL)canOpenURL:(NSURL *)url;
- (BOOL)canOpenURL:(NSURL *)url query:(NSDictionary *)query;

//返回对应的实例
- (id<SSNPage>)pageWithURL:(NSURL *)url query:(NSDictionary *)query;

@property (nonatomic,copy) NSDictionary *map;//页面与页面类之间映射

//添加页面对应的key(或者叫元组)
- (void)addComponent:(NSString *)component pageClass:(Class<SSNPage>)pageClass;

- (void)removeComponent:(NSString *)component;

@end



@interface NSObject (SSNRouter)//弱协议实现

- (SSNRouter *)router;

- (id<SSNParentPage>)parentPage;

- (NSURL *)currentURLPath;//当前url路径,注册进入的实例才会找到

@end


//事件响应类
typedef void (^SSNEventBlock)(NSURL *url,NSDictionary *query);
typedef BOOL (^SSNFilterBlock)(NSURL *url,NSDictionary *query);

@interface SSNEventHandler : NSObject <SSNPage>

- (id)initWithEventBlock:(SSNEventBlock)event;
- (id)initWithEventBlock:(SSNEventBlock)event filter:(SSNFilterBlock)filter;

+ (instancetype)eventBlock:(SSNEventBlock)event;
+ (instancetype)eventBlock:(SSNEventBlock)event filter:(SSNFilterBlock)filter;

@end

//open 流畅控制
@protocol SSNRouterDelegate <NSObject>

@optional
//重定向url,返回需要重定向的url，如果返回nil表示不跳转
- (NSURL *)router:(SSNRouter *)router redirectURL:(NSURL *)url query:(NSDictionary *)query;

//重定向url,返回需要重定向的url，如果返回nil表示不跳转
- (BOOL)router:(SSNRouter *)router canOpenURL:(NSURL *)url query:(NSDictionary *)query;

@end


