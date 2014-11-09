//
//  NSObject+SSNTracking.m
//  ssn
//
//  Created by lingminjun on 14-10-11.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import "NSObject+SSNTracking.h"

#if TARGET_IPHONE_SIMULATOR
#import <objc/objc-runtime.h>
#else
#import <objc/runtime.h>
#import <objc/message.h>
#endif

#import <pthread.h>

#import "ssnbase.h"

#define ssn_alignof_type_size(t) (sizeof(int) * (int)((sizeof(t) + sizeof(int) - 1)/sizeof(int)))

//转发消息名
NSString *ssn_objc_forwarding_method_name(SEL selector)
{
    return [NSString stringWithFormat:@"ssn_forwarding_$%@", NSStringFromSelector(selector)];
}

//记录预置参数日志
NSString *ssn_get_save_preset(NSString *value, NSString *key) {
    static NSMutableDictionary *_ssn_track_values = nil;
    static dispatch_once_t onceToken;
    static pthread_mutex_t mutex;
    dispatch_once(&onceToken, ^{
        _ssn_track_values = [[NSMutableDictionary alloc] init];
        pthread_mutex_init(&mutex, NULL);
    });
    
    static NSString *log = nil;
    if (key) {
        @autoreleasepool {
            NSDictionary *dic = nil;
            
            @synchronized(_ssn_track_values) {
                [_ssn_track_values setValue:value forKey:key];
                dic = [NSDictionary dictionaryWithDictionary:_ssn_track_values];
            }
            
            NSArray *keys = [[dic allKeys] sortedArrayUsingSelector:@selector(compare:)];
            NSMutableString *rt = [NSMutableString string];
            for (NSString *key in keys) {
                NSString *value = [dic objectForKey:key];
                [rt appendFormat:@"%@=%@&",key,value];
            }
            pthread_mutex_lock(&mutex);
            log = [NSString stringWithString:rt];
            pthread_mutex_unlock(&mutex);
        }
    }
    
    pthread_mutex_lock(&mutex);
    NSString *rt = [log copy];
    pthread_mutex_unlock(&mutex);
    return rt;
}

//记录需要收集的属性列表
NSArray *ssn_get_save_class_method_collect_ivar(Class clazz, SEL sel, NSArray *ivar, BOOL get) {
    static dispatch_once_t onceToken;
    static NSCache *_ssn_track_ivar = nil;
    dispatch_once(&onceToken, ^{
        _ssn_track_ivar = [[NSCache alloc] init];
    });
    
    NSString *key = [NSString stringWithFormat:@"%@-%@",NSStringFromClass(clazz),NSStringFromSelector(sel)];
    if (get) {
        return [_ssn_track_ivar objectForKey:key];
    }
    else {
        if (ivar) {
            NSArray *ivar_cop = [ivar copy];
            [_ssn_track_ivar setObject:ivar_cop forKey:key];
        }
        else {
            [_ssn_track_ivar removeObjectForKey:key];
        }
    }
    return nil;
}


NSInvocation *ssn_objc_invocation_v1(id target, NSMethodSignature* signature, SEL selector, va_list argumentList, NSMutableString *log)
{
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation retainArguments];
    
    [invocation setTarget:target];
    [invocation setSelector:selector];
    
    for (int index = 2; index < [signature numberOfArguments]; index++) {
        const char *type = [signature getArgumentTypeAtIndex:index];
        
        //double和float需要特殊处理
        if (type[0] == _C_FLT || type[0] == _C_DBL) {
            double value = va_arg(argumentList, double);
            [invocation setArgument:&value atIndex:index];
        }
        else {
            NSUInteger size = 0;
            NSGetSizeAndAlignment(type, &size, NULL);
            NSUInteger alignof_size = ssn_alignof_type_size(size);
#if (__GNUC__ > 2)
            char *p_area = argumentList->reg_save_area;
            p_area += argumentList->gp_offset;
            
            [invocation setArgument:p_area atIndex:index];
            
            argumentList->gp_offset += alignof_size;
#else
            [invocation setArgument:args atIndex:index];
            args += alignof_size;
#endif
        }
    }
    
    return invocation;
}

/**
 *  参数解析并生产NSInvocation
 #define _C_ID       '@'
 #define _C_CLASS    '#'
 #define _C_SEL      ':'
 #define _C_CHR      'c'
 #define _C_UCHR     'C'
 #define _C_SHT      's'
 #define _C_USHT     'S'
 #define _C_INT      'i'
 #define _C_UINT     'I'
 #define _C_LNG      'l'
 #define _C_ULNG     'L'
 #define _C_LNG_LNG  'q'
 #define _C_ULNG_LNG 'Q'
 #define _C_FLT      'f'
 #define _C_DBL      'd'
 #define _C_BFLD     'b'
 #define _C_BOOL     'B'
 #define _C_VOID     'v'
 #define _C_UNDEF    '?'
 #define _C_PTR      '^'
 #define _C_CHARPTR  '*'
 #define _C_ATOM     '%'
 #define _C_ARY_B    '['
 #define _C_ARY_E    ']'
 #define _C_UNION_B  '('
 #define _C_UNION_E  ')'
 #define _C_STRUCT_B '{'
 #define _C_STRUCT_E '}'
 #define _C_VECTOR   '!'
 #define _C_CONST    'r'
 */
NSInvocation *ssn_objc_invocation_v2(id target, NSMethodSignature* signature, SEL selector, va_list argumentList, NSMutableString *log)
{
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation retainArguments];
    
    [invocation setTarget:target];
    [invocation setSelector:selector];
    
    NSInteger arg_index = 2;
    
    NSUInteger arg_num = [signature numberOfArguments];
    
    if (arg_num > arg_index) {//必须具备起始值
        
        while (arg_num > arg_index) {
            
            const char* argType = [signature getArgumentTypeAtIndex:arg_index];
            while(strchr("rnNoORV", argType[0]) != NULL) {
                argType += 1;
            }
            
            if((strlen(argType) > 1) && (strchr("{^", argType[0]) == NULL)) {
                [NSException raise:NSInvalidArgumentException format:@"Cannot handle argument type '%s'.", argType];
            }
            
            switch (argType[0]) {
                case _C_ID:
                case _C_CLASS:
                {
                    id obj = va_arg(argumentList, id);
                    [log appendFormat:@"%ld=%@%p&",arg_index,NSStringFromClass([obj class]),obj];
                    [invocation setArgument:&obj atIndex:arg_index];
                    break;
                }
                case _C_SEL:
                {
                    SEL s = va_arg(argumentList, SEL);
                    [log appendFormat:@"%ld=%@&",arg_index,NSStringFromSelector(s)];
                    [invocation setArgument:&s atIndex:arg_index];
                    break;
                }
                case _C_BOOL://bool size小于int的都用int取值
                case _C_SHT://shot size小于int的都用int取值
                case _C_USHT:
                case _C_CHR://char
                case _C_UCHR://unsigne char
                case _C_INT:
                {
                    int value = va_arg(argumentList, int);
                    [log appendFormat:@"%ld=%i&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_UINT:
                {
                    unsigned int value = va_arg(argumentList, unsigned int);
                    [log appendFormat:@"%ld=%u&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_LNG:
                {
                    long value = va_arg(argumentList, long);
                    [log appendFormat:@"%ld=%ld&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_ULNG:
                {
                    unsigned long value = va_arg(argumentList, unsigned long);
                    [log appendFormat:@"%ld=%lu&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_LNG_LNG:
                {
                    long long value = va_arg(argumentList, long long);
                    [log appendFormat:@"%ld=%lld&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_ULNG_LNG:
                {
                    unsigned long long value = va_arg(argumentList, unsigned long long);
                    [log appendFormat:@"%ld=%llu&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_FLT://浮点型都用double取值，__alignof__(float) == __alignof__(double) 不同操作系统可能存在影响
                case _C_DBL:
                {
                    double value = va_arg(argumentList, double);
                    [log appendFormat:@"%ld=%f&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_PTR:
                {
                    void *value = va_arg(argumentList, void *);
                    [log appendFormat:@"%ld=%p&",arg_index,value];
                    [invocation setArgument:&value atIndex:arg_index];
                    break;
                }
                case _C_STRUCT_B:
                {
                    NSUInteger size = 0;
                    NSGetSizeAndAlignment(argType, &size, NULL);
                    NSUInteger alignof_size = ssn_alignof_type_size(size);
                    char *point = NULL;
#if (__GNUC__ > 2)
                    char *p_area = argumentList->reg_save_area;
                    p_area += argumentList->gp_offset;
                    
                    point = p_area;
                    [invocation setArgument:p_area atIndex:arg_index];
                    
                    argumentList->gp_offset += alignof_size;
#else
                    point = argumentList;
                    [invocation setArgument:argumentList atIndex:arg_index];
                    argumentList += alignof_size;
#endif
                    char struct_name[250] = {'\0'};
                    char *name_point = struct_name;
                    const char *type_point = &(argType[1]);
                    while (*type_point != _C_STRUCT_E) {			// Skip "<name>=" stuff.
                        char c = *type_point++;
                        if (c == '=')
                        {
                            break;
                        }
                        
                        *name_point = c;
                        name_point++;
                    }
                    
                    [log appendFormat:@"%ld={%s:%p}&",arg_index,struct_name,point];
                    
                    break;
                }
                    
                case _C_UNION_B: {
                    NSUInteger size = 0;
                    NSGetSizeAndAlignment(argType, &size, NULL);
                    NSUInteger alignof_size = ssn_alignof_type_size(size);
                    
                    char *point = NULL;
#if (__GNUC__ > 2)
                    char *p_area = argumentList->reg_save_area;
                    p_area += argumentList->gp_offset;
                    
                    point = p_area;
                    [invocation setArgument:p_area atIndex:arg_index];
                    
                    argumentList->gp_offset += alignof_size;
#else
                    point = argumentList;
                    [invocation setArgument:argumentList atIndex:arg_index];
                    argumentList += alignof_size;
#endif
                    char struct_name[250] = {'\0'};
                    char *name_point = struct_name;
                    const char *type_point = &(argType[1]);
                    while (*type_point != _C_STRUCT_E) {			// Skip "<name>=" stuff.
                        char c = *type_point++;
                        if (c == '=')
                        {
                            break;
                        }
                        
                        //拷贝类型，用于日志
                        *name_point = c;
                        name_point++;
                    }
                    
                    [log appendFormat:@"%ld={%s:%p}&",arg_index,struct_name,point];
                    
                    break;
                }
                default:{
                    NSUInteger size = 0;
                    NSGetSizeAndAlignment(argType, &size, NULL);
                    NSUInteger alignof_size = ssn_alignof_type_size(size);
                    
                    char *point = NULL;
#if (__GNUC__ > 2)
                    char *p_area = argumentList->reg_save_area;
                    p_area += argumentList->gp_offset;
                    
                    point = p_area;
                    [invocation setArgument:p_area atIndex:arg_index];
                    
                    argumentList->gp_offset += alignof_size;
#else
                    point = argumentList;
                    [invocation setArgument:argumentList atIndex:arg_index];
                    argumentList += alignof_size;
                    
                    [log appendFormat:@"%ld={%p}&",arg_index,point];
#endif
                }break;
                    
            }
            
            arg_index++;
        }
    }
    
    return invocation;
}

//跟踪记录实现日志函数
void ssn_log_track_method(id self, SEL _cmd, const long long t_callat, const long long t_cost, NSString *param_log)
{
    static dispatch_queue_t log_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log_queue = dispatch_queue_create("ssn_log_queue", DISPATCH_QUEUE_SERIAL);
    });
    
    dispatch_async(log_queue, ^{
        @autoreleasepool {
            NSMutableString *logString = [NSMutableString string];
            //收集系统参数
            NSString *presetlog = ssn_get_save_preset(nil, nil);
            if (presetlog) {
                [logString appendString:presetlog];
            }
            
            //取参数
            NSArray *keys = ssn_get_save_class_method_collect_ivar([self class], _cmd, nil, YES);
            for (NSString *key in keys) {
                id v = [self valueForKey:key];
                [logString appendFormat:@"%@=%@&",key,v];
            }
            
            //参数直接key设定为index（解析分析时，只需要从后往前依次取数字key直到取到0为止）
            [logString appendFormat:@"0=%@:%p&1=%@&",NSStringFromClass([self class]),self,NSStringFromSelector(_cmd)];
            
            if ([param_log length]) {
                [logString appendString:param_log];
            }
            
            //call_at与call_cost对应的key被简写
            [logString appendFormat:@"c_a=%lld&c_c=%lld",t_callat,t_cost];
            
            ssn_log("\nssn_track_log【%s】\n",[logString UTF8String]);
        }
    });
}

//所有跟踪消息转发
id ssn_objc_forwarding_method_imp(id self,SEL _cmd, ...)
{
    NSString *rep_cmd = ssn_objc_forwarding_method_name(_cmd);
    SEL rep_sel = NSSelectorFromString(rep_cmd);
    
    NSMethodSignature *methodSignature = [[self class] instanceMethodSignatureForSelector:rep_sel];
    
    NSMutableString *paramlog = [NSMutableString string];
    
    va_list argumentList;
    va_start(argumentList, _cmd);
    NSInvocation *rep_invocation = ssn_objc_invocation_v2(self, methodSignature, rep_sel, argumentList, paramlog);
    va_end(argumentList);
    
    struct timeval t_b_tv,t_e_tv;
    gettimeofday(&t_b_tv, NULL);
    [rep_invocation invoke];
    gettimeofday(&t_e_tv, NULL);
    long long t_bengin = t_b_tv.tv_sec * 1000000ll + t_b_tv.tv_usec;
    long long t_cost = (t_e_tv.tv_sec - t_b_tv.tv_sec) * 1000000ll + (t_e_tv.tv_usec - t_b_tv.tv_usec);
    
    //返回值
    id ret_val  = nil;
    NSUInteger ret_size = [methodSignature methodReturnLength];
    if(ret_size > 0) {
        [rep_invocation getReturnValue:&ret_val];
        [paramlog appendFormat:@"result=%@&",ret_val];
    }
    
    //记录跟踪
    ssn_log_track_method(self,_cmd,t_bengin,t_cost,paramlog);
    
    return ret_val;
}

@implementation NSObject (SSNTracking)

/**
 *  设置需要采集的预置信息，将在每次打点发生时去用
 *
 *  @param  value       预置参数值
 *  @param  key         预置参数键值
 */
+ (void)ssn_savePresetValue:(NSString *)value forKey:(NSString *)key
{
    ssn_get_save_preset(value, key);
}


/**
 *  跟踪clazz类实例的selector方法，当这个方法被调用时将会被记录，记录会自动收集预置参数
 *
 *  @param  clazz       跟踪的类
 *  @param  selector    跟踪类实例的方法，方法返回值仅仅支持id，和void类型，其他类型还不支持，方法参数不支持可变参数和联合参数，
 *                      内部采用NSInvocation转发调用，所以自然依赖“NSInvocation does not support invocations of methods
 *                      with either variable numbers of arguments or union arguments.”
 */
+ (void)ssn_tracking_class:(Class)clazz selector:(SEL)selector
{
    [self ssn_tracking_class:clazz selector:selector collectIvarList:nil];
}


/**
 *  跟踪clazz类实例的selector方法，当这个方法被调用时将会被记录，记录会自动收集预置参数
 *
 *  @param  clazz       跟踪的类
 *  @param  selector    跟踪类实例的方法，方法返回值仅仅支持id，和void类型，其他类型还不支持，方法参数不支持可变参数和联合参数，
 *                      内部采用NSInvocation转发调用，所以自然依赖“NSInvocation does not support invocations of methods
 *                      with either variable numbers of arguments or union arguments.”
 *  @param  ivarList    需要采集的当前实例属性值（若实例找不到属性将异常）
 */
+ (void)ssn_tracking_class:(Class)clazz selector:(SEL)selector collectIvarList:(NSArray *)ivarList
{
    NSAssert(clazz && selector, @"请传入正确参数");
    
    //1、先检查当前类是否响应此方法
    Method method = class_getInstanceMethod(clazz, selector);
    NSAssert(method, @"请确保要跟踪的类能响应此方法");
    
    //2、记录需要采集的参数
    if (ivarList) {
        ssn_get_save_class_method_collect_ivar(clazz, selector, ivarList, NO);
    }
    
    ssn_log("\n ssn tracking class:%s selector:%s\n",[NSStringFromClass(clazz) UTF8String],[NSStringFromSelector(selector) UTF8String]);
    
    //3、再为此类添加转发方法
    SEL forwarding_sel = NSSelectorFromString(ssn_objc_forwarding_method_name(selector));
    const char *method_type = method_getTypeEncoding(method);
    if (class_addMethod(clazz, forwarding_sel, method_getImplementation(method), method_type))
    {
        //
    }
    
    //4、替换原来方法名字下的实现
    if (class_addMethod(clazz, selector, (IMP)ssn_objc_forwarding_method_imp, method_type))
    {
        ssn_log("\n ssn tracking add selector:%s\n",[NSStringFromSelector(selector) UTF8String]);
    }
    else
    {
        class_replaceMethod(clazz,selector,(IMP)ssn_objc_forwarding_method_imp, method_type);
        ssn_log("\n ssn tracking rewrite selector:%s\n",[NSStringFromSelector(selector) UTF8String]);
    }
    
}

@end