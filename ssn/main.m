//
//  main.m
//  ssn
//
//  Created by lingminjun on 14-5-7.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "SSNCrashReport.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        [SSNCrashReport launchExceptionHandler];
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
