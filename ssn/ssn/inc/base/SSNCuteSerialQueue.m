//
//  SSNCuteSerialQueue.m
//  ssn
//
//  Created by lingminjun on 14-8-12.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import "SSNCuteSerialQueue.h"
#import <pthread.h>

// static NSMutableArray *_asyncBlocks;
// static dispatch_queue_t _queue;
// static pthread_mutex_t _mutex;
// static BOOL _hasAsynBlocks;

@interface SSNCuteSerialQueue ()
{
    NSString *_name;
    NSMutableArray *_asyncBlocks;
    dispatch_queue_t _queue;
    pthread_mutex_t _mutex;
    BOOL _hasAsynBlocks;
}

@end

@implementation SSNCuteSerialQueue

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        _name = [name copy];

        pthread_mutex_init(&_mutex, NULL);

        _queue = dispatch_queue_create([_name UTF8String], DISPATCH_QUEUE_SERIAL);

        //        dispatch_queue_t high = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        //        dispatch_set_target_queue(_queue, high);

        dispatch_queue_set_specific(_queue, (__bridge const void *)_name, (__bridge void *)_name, NULL);
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
#if !OS_OBJECT_USE_OBJC
    if (_queue)
    {
        dispatch_release(_queue);
    }
#endif
}

- (void)async:(dispatch_block_t)block
{
    [self addBlock:block sync:NO];
}

- (void)sync:(dispatch_block_t)block
{
    [self addBlock:block sync:YES];
}

- (void)addBlock:(dispatch_block_t)block sync:(BOOL)isSync
{

    if (!block)
    {
        return;
    }

    if (isSync)
    {
        if (dispatch_get_specific((__bridge const void *)_name))
        {

            if (block)
            {
                block();
            }
        }
        else
        {

            //断开asyn_block的继续提交，导致此次同步一直等待
            if (_hasAsynBlocks)
            {
                pthread_mutex_lock(&_mutex);
                _hasAsynBlocks = NO; //不清除 _asyncBlocks
                pthread_mutex_unlock(&_mutex);
            }

            dispatch_sync(_queue, block);
        }
    }
    else
    {

        __block NSMutableArray *t_lists = nil; //生产临时变量

        dispatch_block_t a_block = ^{ // aysn_blocks的数组 处理 的block
            NSArray *s_ary = nil;

            pthread_mutex_lock(&_mutex);
            s_ary = t_lists;
            _asyncBlocks = nil;
            _hasAsynBlocks = NO;
            pthread_mutex_unlock(&_mutex);

            //执行所有block
            for (dispatch_block_t ablock in s_ary)
            {
                ablock();
            }
        };

        NSMutableArray *t_new = [NSMutableArray arrayWithCapacity:60]; //先产生实例，避免在锁内操作，以空间换时间

        pthread_mutex_lock(&_mutex);
        if (!_hasAsynBlocks)
        {
            _asyncBlocks = t_new;
            _hasAsynBlocks = YES;
            dispatch_async(_queue, a_block);
        }
        t_lists = _asyncBlocks;
        [t_lists addObject:block]; //加入block到处理数组

        pthread_mutex_unlock(&_mutex);
    }
}

@end
