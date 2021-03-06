//
//  SSNSectionModel.m
//  ssn
//
//  Created by lingminjun on 15/2/23.
//  Copyright (c) 2015年 lingminjun. All rights reserved.
//

#import "SSNSectionModel.h"

@interface SSNSectionModel ()
@property (nonatomic,copy) NSString *identify;
@end

@implementation SSNSectionModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.headerHeight = SSN_VM_SECTION_INFO_DEFAULT_HEIGHT;
        self.footerHeight = SSN_VM_SECTION_INFO_DEFAULT_HEIGHT;
        self.hiddenFooter = YES;
    }
    return self;
}

@synthesize identify = _identify;
- (NSString *)identify {
    if (_identify) {
        return _identify;
    }
    
    _identify = [[NSString alloc] initWithFormat:@"%p",self];
    return _identify;
}

@synthesize userInfo = _userInfo;
- (NSMutableDictionary *)userInfo {
    if (_userInfo) {
        return _userInfo;
    }
    
    _userInfo = [[NSMutableDictionary alloc] initWithCapacity:1];
    return _userInfo;
}

@synthesize objects = _objects;
- (NSMutableArray *)objects {
    if (_objects) {
        return _objects;
    }
    
    _objects = [[NSMutableArray alloc] initWithCapacity:1];
    return _objects;
}


- (NSUInteger)count {
    return [self.objects count];
}


- (id)objectAtIndex:(NSUInteger)index {
    if (index >= [self count]) {
        return nil;
    }
    
    return [self.objects objectAtIndex:index];
}

- (NSUInteger)indexOfObject:(id)object {
    return [self.objects indexOfObject:object];
}

- (NSComparisonResult)compare:(SSNSectionModel *)info {
    if (self == info) {
        return NSOrderedSame;
    }
    
    if (![info isKindOfClass:[SSNSectionModel class]]) {
        return NSOrderedAscending;
    }
    
    if (self.sortIndex > info.sortIndex) {
        return NSOrderedDescending;
    }
    else if (self.sortIndex < info.sortIndex) {
        return NSOrderedAscending;
    }
    else {
        return NSOrderedSame;
    }
}

+ (instancetype)sectionInfoWithIdentify:(NSString *)identify title:(NSString *)title {
    SSNSectionModel *info = [[SSNSectionModel alloc] init];
    info.identify = identify;
    info.headerTitle = title;
    return info;
}

#pragma mark over write
- (NSUInteger)hash {
    return [self.identify hash];
}

- (BOOL)isEqual:(SSNSectionModel *)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[SSNSectionModel class]]) {
        return NO;
    }
    
    if (self.identify == object.identify) {//效率更高
        return YES;
    }
    
    return [self.identify isEqualToString:object.identify];
}

#pragma mark copy
- (id)copyWithZone:(NSZone *)zone {
    SSNSectionModel *copy = [[[self class] alloc] init];
    
    copy.headerTitle = self.headerTitle;
    copy.headerHeight = self.headerHeight;
    copy.hiddenHeader = self.hiddenHeader;
    copy.customHeaderView = self.customHeaderView;
    
    copy.footerTitle = self.footerTitle;
    copy.footerHeight = self.footerHeight;
    copy.hiddenFooter = self.hiddenFooter;
    copy.customFooterView = self.customFooterView;
    
    copy.identify = self.identify;
    copy.sortIndex = self.sortIndex;
    
    [copy.userInfo setDictionary:self.userInfo];
    
    [copy.objects setArray:self.objects];
    return copy;
}
@end


@implementation NSArray (SSNSectionModels)

//越界返回nil
- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section >= [self count]) {
        return nil;
    }
    
    SSNSectionModel *section = [self objectAtIndex:indexPath.section];
    if (![section isKindOfClass:[SSNSectionModel class]]) {
        return nil;
    }
    
    return [section objectAtIndex:indexPath.row];
}

@end

