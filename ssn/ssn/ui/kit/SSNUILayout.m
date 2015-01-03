//
//  SSNUILayout.m
//  ssn
//
//  Created by lingminjun on 14/12/30.
//  Copyright (c) 2014年 lingminjun. All rights reserved.
//

#import "SSNUILayout.h"
#import "UIView+SSNUIFrame.h"
#import "SSNPanel.h"

#if TARGET_IPHONE_SIMULATOR
#import <objc/objc-runtime.h>
#else
#import <objc/runtime.h>
#import <objc/message.h>
#endif

/**
 *  所有被布局的子view都需要反过来引用layout，这样就能清楚的看到他正处在什么布局中
 */
@interface SSNUILayoutWeakBox : NSObject
@property (nonatomic,weak) SSNUILayout *layout;
+ (instancetype)boxWithLayout:(SSNUILayout *)layout;
@end

@implementation SSNUILayoutWeakBox
+ (instancetype)boxWithLayout:(SSNUILayout *)layout {
    SSNUILayoutWeakBox *box = [[[self class] alloc] init];
    box.layout = layout;
    return box;
}
@end

/**
 *  子view关联布局对象
 */
@interface UIView (SSNUILayoutInner)
@end

@implementation UIView (SSNUILayoutInner)

static char *ssn_dependent_layout_key = NULL;
- (SSNUILayoutWeakBox *)ssn_dependent_layout {
    return objc_getAssociatedObject(self, &ssn_dependent_layout_key);
}

- (void)setSsn_dependent_layout:(SSNUILayoutWeakBox *)layout {
    objc_setAssociatedObject(self, &ssn_dependent_layout_key, layout, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


@implementation SSNUILayout
{
    NSString *_layoutID;
    NSMutableArray *_subviews;
    __weak UIView *_panel;
}

//唯一初始化函数
- (instancetype)initWithPanel:(UIView *)panel {
    self = [super init];
    if (self) {
        _layoutID = [NSString stringWithFormat:@"%p",self];
        _subviews = [[NSMutableArray alloc] initWithCapacity:1];
        _panel = panel;
    }
    return self;
}

- (instancetype)init {
    [[NSException exceptionWithName:@"SSNUILayout" reason:@"不允许独自创建SSNUILayout实例" userInfo:nil] raise];
    return nil;
}

- (void)removeSubview:(UIView *)subview {
    NSLog(@"layout remove subview %@",subview);
    
    [subview setSsn_dependent_layout:nil];//移除弱引用
    
    [_subviews removeObject:subview];
    return ;
}

/**
 *  返回当前layout的id
 *
 *  @return 返回layoutid
 */
- (NSString *)layoutID {
    return _layoutID;
}

/**
 *  一个布局只能应用于一个view上面
 *
 *  @return 返回作用的view上面
 */
- (UIView *)panel {
    return _panel;
}

/**
 *  所有参与此类布局的子view
 *
 *  @return 所有参与此类布局的子view @see UIView
 */
- (NSArray *)subviews {
    return _subviews;
}

/**
 *  获取view所在的布局对象
 *
 *  @param view 一个子view
 *
 *  @return 返回view所在的布局对象
 */
+ (SSNUILayout *)dependentLayoutWithView:(UIView *)view {
    SSNUILayoutWeakBox *box = [view ssn_dependent_layout];
    return box.layout;
}

/**
 *  添加子view到此布局中，并且加入到UIView上面，已经在UIView上的子view，仅仅添加到布局，不改变它在原来UIView中的层级
 *
 *  @param view 添加子view
 *  @param key  子view对应key
 */
- (void)addSubview:(UIView *)view forKey:(NSString *)key {
    [_subviews removeObject:view];
    [_subviews addObject:view];
    
    //关联子view
    SSNUILayoutWeakBox *box = [SSNUILayoutWeakBox boxWithLayout:self];
    [view setSsn_dependent_layout:box];
    
    UIView *superview = [self panel];
    if (![superview ssn_subviewForKey:key]) {
        [superview ssn_addSubview:view forKey:key];
    }
}

/**
 *  增加一个子view到对应的位置上，只是布局位置上的插入，与view层级没关系
 *  已经在UIView上的子view，仅仅添加到布局，不改变它在原来UIView中的层级
 *
 *  @param view 添加子view
 *  @param index 位置，此布局中所包含的所有子view组中的位置，越界认定为最后
 *  @param key  子view对应key
 */
- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index forKey:(NSString *)key {
    [_subviews removeObject:view];
    if (index > [_subviews count]) {
        [_subviews addObject:view];
    }
    else {
        [_subviews insertObject:view atIndex:index];
    }
    
    //关联子view
    SSNUILayoutWeakBox *box = [SSNUILayoutWeakBox boxWithLayout:self];
    [view setSsn_dependent_layout:box];
    
    UIView *superview = [self panel];
    if (![superview ssn_subviewForKey:key]) {
        [superview ssn_insertSubview:view atIndex:index forKey:key];
    }
}

/**
 *  移动一个字view到某个位置上，只是布局位置上的移动，与view层级没关系
 *
 *  @param index 位置，此布局中所包含的所有子view组中的位置，越界认定为最后
 *  @param key   子view对应key，找不到view忽略
 */
- (void)moveSubviewToIndex:(NSInteger)index forKey:(NSString *)key {
    UIView *superview = [self panel];
    UIView *subview = [superview ssn_subviewForKey:key];
    
    if (!subview) {
        return ;
    }
    
    [_subviews removeObject:subview];
    [_subviews insertObject:subview atIndex:index];
}

/**
 *  将一个子view移除此类布局且从panel中移除
 *
 *  @param key 需要移除的key
 */
- (void)removeSubviewForKey:(NSString *)key {
    UIView *superview = [self panel];
    UIView *subview = [superview ssn_subviewForKey:key];
    [subview removeFromSuperview];
}

/**
 *  将一个子view移除此布局，不从panel中移除
 *
 *  @param key 需要移除的key
 */
- (void)moveOutSubviewForKey:(NSString *)key {
    UIView *superview = [self panel];
    UIView *subview = [superview ssn_subviewForKey:key];
    [subview setSsn_dependent_layout:nil];
    [_subviews removeObject:subview];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    _contentInset.top = contentInset.top > 0 ? contentInset.top : 0;
    _contentInset.bottom = contentInset.bottom > 0 ? contentInset.bottom : 0;
    _contentInset.left = contentInset.left > 0 ? contentInset.left : 0;
    _contentInset.right = contentInset.right > 0 ? contentInset.right : 0;
    
}

/**
 *  布局所有子view
 */
- (void)layoutSubviews {
    //NSLog(@"nothing to do")
}

/**
 *  在一固定的rect中布局一个元素
 *
 *  @param view        需要布局的元素
 *  @param rect        行尺寸
 *  @param contentMode 数据依靠点
 */
- (void)layoutSubview:(UIView *)view inRect:(CGRect)rect contentMode:(SSNUIContentMode)contentMode {
    switch (contentMode) {
        case SSNUIContentModeTopLeft: {
            view.ssn_top_left_corner = ssn_top_left_corner(rect);
        } break;
        case SSNUIContentModeTopRight: {
            view.ssn_top_right_corner = ssn_top_right_corner(rect);
        } break;
        case SSNUIContentModeBottomLeft: {
            view.ssn_bottom_left_corner = ssn_bottom_left_corner(rect);
        } break;
        case SSNUIContentModeBottomRight: {
            view.ssn_bottom_right_corner = ssn_bottom_right_corner(rect);
        } break;
        case SSNUIContentModeScaleToFill: {
            view.ssn_center = ssn_center(rect);//后期根据需要优化
        } break;
        case SSNUIContentModeCenter: {
            view.ssn_center = ssn_center(rect);
        } break;
        case SSNUIContentModeTop: {
            view.ssn_top_center = ssn_top_center(rect);
        } break;
        case SSNUIContentModeBottom: {
            view.ssn_bottom_center = ssn_bottom_center(rect);
        } break;
        case SSNUIContentModeLeft: {
            view.ssn_left_center = ssn_left_center(rect);
        } break;
        case SSNUIContentModeRight: {
            view.ssn_right_center = ssn_right_center(rect);
        } break;
        default:
            break;
    }
}

/**
 *  是否按照水平方向计算行
 *
 *  @return 如果x方向是行的话返回YES，否则返回NO
 */
- (BOOL)isHOR {
    if (self.orientation == SSNUILayoutOrientationLandscapeLeft
        || self.orientation == SSNUILayoutOrientationLandscapeRight) {
        return NO;
    }
    return YES;
}

/**
 *  行方向上是否递增
 *
 *  @return 行是否递增排列
 */
- (BOOL)isRowASC {
    switch (_orientation) {
        case SSNUILayoutOrientationPortrait:
            return YES;
            break;
        case SSNUILayoutOrientationPortraitUpsideDown:
            return NO;
            break;
        case SSNUILayoutOrientationLandscapeLeft:
            return NO;
            break;
        case SSNUILayoutOrientationLandscapeRight:
            return YES;
            break;
        default:
            break;
    }
    return NO;
}

/**
 *  列方向上是否为递增
 *
 *  @return 列方是否为递增
 */
- (BOOL)isColumnASC {
    switch (_orientation) {
        case SSNUILayoutOrientationPortrait:
            return !_isXReverse;
            break;
        case SSNUILayoutOrientationPortraitUpsideDown:
            return _isXReverse;
            break;
        case SSNUILayoutOrientationLandscapeLeft:
            return !_isXReverse;
            break;
        case SSNUILayoutOrientationLandscapeRight:
            return _isXReverse;
            break;
        default:
            break;
    }
    return NO;
}

/**
 *  返回第一行的rect坐标
 *
 *  @return 返回第一行的rect坐标
 */
- (CGRect)firstRowRectWithRowHeight:(NSUInteger)rowHeight {
    UIView *superview = [self panel];
    
    CGRect rect = CGRectZero;
    
    switch (_orientation) {
        case SSNUILayoutOrientationPortrait: {
            
            rect.size.height = rowHeight;
            
            if (_contentInset.left + _contentInset.right < superview.ssn_width) {//超出就为0
                rect.size.width = superview.ssn_width - (_contentInset.left + _contentInset.right);
            }
            
            rect.origin.x = _contentInset.left;//不论是否inset是否超出宽度，都取left
            rect.origin.y = _contentInset.top;
        } break;
        case SSNUILayoutOrientationPortraitUpsideDown: {
            rect.size.height = rowHeight;

            if (_contentInset.left + _contentInset.right < superview.ssn_width) {
                rect.size.width = superview.ssn_width - (_contentInset.left + _contentInset.right);
            }
            
            rect.origin.x = _contentInset.left;
            rect.origin.y = superview.ssn_height - _contentInset.bottom - rect.size.height;

        } break;
        case SSNUILayoutOrientationLandscapeLeft: {
            rect.size.width = rowHeight;
            
            if (_contentInset.top + _contentInset.bottom < superview.ssn_height) {
                rect.size.height = superview.ssn_height - (_contentInset.top + _contentInset.bottom);
            }
            
            rect.origin.x = superview.ssn_width - _contentInset.right - rect.size.width;
            rect.origin.y = _contentInset.top;
        } break;
        case SSNUILayoutOrientationLandscapeRight: {
            rect.size.width = rowHeight;
            
            if (_contentInset.top + _contentInset.bottom < superview.ssn_height) {
                rect.size.height = superview.ssn_height - (_contentInset.top + _contentInset.bottom);
            }
            
            rect.origin.x = _contentInset.left;
            rect.origin.y = _contentInset.top;
        } break;
        default:
            break;
    }
    return rect;
}

/**
 *  返回行款
 *
 *  @return 返回行款
 */
- (NSInteger)row_width {
    UIView *superview = [self panel];
    
    CGSize size = superview.ssn_size;
    if ([superview isKindOfClass:[UIScrollView class]]) {//UIScrollView需要单独处理
        CGSize t_size = [(UIScrollView *)superview contentSize];
        size.width = MAX(size.width, t_size.width);
        size.height = MAX(size.height, t_size.height);
    }
    
    NSInteger max_width = size.width - (self.contentInset.left + self.contentInset.right);
    if (self.orientation == SSNUILayoutOrientationLandscapeLeft
        || self.orientation == SSNUILayoutOrientationLandscapeRight) {
        max_width = size.height - (self.contentInset.top + self.contentInset.bottom);
    }
    
    if (max_width < 0) {
        max_width = 0;
    }
    
    return max_width;
}

@end

@implementation SSNUISiteLayout

@end


@implementation SSNUIFlowLayout

- (void)layoutRowviews:(NSArray *)subviews inRow:(CGRect)rect sumViewWidth:(CGFloat)sumViewWidth isHOR:(BOOL)isHOR {
    __block CGRect row_rect = rect;
    
    NSInteger view_count = [subviews count];
    
    BOOL isReverse = YES;//是否需要反向排列
    SSNUIContentMode contentMode = _contentMode;
    switch (_contentMode) {
        case SSNUIContentModeTopLeft: {
            isReverse = NO;
        } break;
        case SSNUIContentModeTopRight: {
            if (isHOR) {
                isReverse = YES;
            }else {
                isReverse = NO;
            }
        } break;
        case SSNUIContentModeBottomLeft: {
            if (isHOR) {
                isReverse = NO;
            }else {
                isReverse = YES;
            }
        } break;
        case SSNUIContentModeBottomRight: {
            if (isHOR) {
                isReverse = YES;
            }else {
                isReverse = YES;
            }
        } break;
        case SSNUIContentModeScaleToFill:
        case SSNUIContentModeCenter: {//需要转换成依赖左边布局
            if (isHOR) {
                isReverse = NO;
                
                contentMode = SSNUIContentModeLeft;
                
                if (row_rect.size.width >= sumViewWidth + ((view_count - 1)*_spacing)) {
                    row_rect.origin.x += (row_rect.size.width - (sumViewWidth + (view_count - 1)*_spacing))/2;
                    row_rect.size.width = sumViewWidth + ((view_count - 1)*_spacing);
                }
                else {//肯定只有一个元素的情况
                    row_rect.origin.x -= ((sumViewWidth + (view_count - 1)*_spacing) - row_rect.size.width)/2;
                }
            }
            else {
                isReverse = NO;
                
                contentMode = SSNUIContentModeTop;
                
                if (row_rect.size.height >= sumViewWidth + ((view_count - 1)*_spacing)) {
                    row_rect.origin.y += (row_rect.size.height - (sumViewWidth + (view_count - 1)*_spacing))/2;
                    row_rect.size.height = sumViewWidth + ((view_count - 1)*_spacing);
                }
                else {//肯定只有一个元素的情况
                    row_rect.origin.y -= ((sumViewWidth + (view_count - 1)*_spacing) - row_rect.size.height)/2;
                }
            }
        } break;
        case SSNUIContentModeTop: {
            if (isHOR) {
                isReverse = NO;
                
                contentMode = SSNUIContentModeTopLeft;
                
                if (row_rect.size.width >= sumViewWidth + ((view_count - 1)*_spacing)) {
                    row_rect.origin.x += (row_rect.size.width - (sumViewWidth + (view_count - 1)*_spacing))/2;
                    row_rect.size.width = sumViewWidth + ((view_count - 1)*_spacing);
                }
                else {//肯定只有一个元素的情况
                    row_rect.origin.x -= ((sumViewWidth + (view_count - 1)*_spacing) - row_rect.size.width)/2;
                }
            }
            else {
                isReverse = NO;
            }
        } break;
        case SSNUIContentModeBottom: {
            if (isHOR) {
                isReverse = NO;
                
                contentMode = SSNUIContentModeBottomLeft;
                
                if (row_rect.size.width >= sumViewWidth + ((view_count - 1)*_spacing)) {
                    row_rect.origin.x += (row_rect.size.width - (sumViewWidth + (view_count - 1)*_spacing))/2;
                    row_rect.size.width = sumViewWidth + ((view_count - 1)*_spacing);
                }
                else {//肯定只有一个元素的情况
                    row_rect.origin.x -= ((sumViewWidth + (view_count - 1)*_spacing) - row_rect.size.width)/2;
                }
            }
            else {
                isReverse = YES;
            }
        } break;
        case SSNUIContentModeLeft: {
            if (isHOR) {
                isReverse = NO;
            }
            else {
                isReverse = NO;
                
                contentMode = SSNUIContentModeTopLeft;
                
                if (row_rect.size.height >= sumViewWidth + ((view_count - 1)*_spacing)) {
                    row_rect.origin.y += (row_rect.size.height - (sumViewWidth + (view_count - 1)*_spacing))/2;
                    row_rect.size.height = sumViewWidth + ((view_count - 1)*_spacing);
                }
                else {//肯定只有一个元素的情况
                    row_rect.origin.y -= ((sumViewWidth + (view_count - 1)*_spacing) - row_rect.size.height)/2;
                }
            }
        } break;
        case SSNUIContentModeRight: {
            if (isHOR) {
                isReverse = YES;
            }
            else {
                isReverse = NO;
                
                contentMode = SSNUIContentModeTopRight;
                
                if (row_rect.size.height >= sumViewWidth + ((view_count - 1)*_spacing)) {
                    row_rect.origin.y += (row_rect.size.height - (sumViewWidth + (view_count - 1)*_spacing))/2;
                    row_rect.size.height = sumViewWidth + ((view_count - 1)*_spacing);
                }
                else {//肯定只有一个元素的情况
                    row_rect.origin.y -= ((sumViewWidth + (view_count - 1)*_spacing) - row_rect.size.height)/2;
                }
            }
        } break;
        default:
            break;
    }
    
    NSArray *rowviews = subviews;
    if (self.isXReverse) {
        rowviews = [[subviews reverseObjectEnumerator] allObjects];
    }
    
    void (^block)(UIView *view, NSUInteger idx, BOOL *stop) = ^(UIView *view, NSUInteger idx, BOOL *stop) {
        [self layoutSubview:view inRect:row_rect contentMode:contentMode];
        
        if (isHOR) {
            row_rect.size.width -= view.ssn_width + _spacing;
        }
        else {
            row_rect.size.height -= view.ssn_height + _spacing;
        }
        
        if (!isReverse) {
            if (isHOR) {
                row_rect.origin.x += view.ssn_width + _spacing;
            }
            else {
                row_rect.origin.y += view.ssn_height + _spacing;
            }
        }
    };
    
    if (isReverse) {
        [rowviews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:block];
    }
    else {
        [rowviews enumerateObjectsUsingBlock:block];
    }
}

#define SSNUILayoutRowRectNext(rect,hor,asc,height) do{\
if (hor)    { if (asc) { rect.origin.y += height; } else { rect.origin.y -= height; } }\
else        { if (asc) { rect.origin.x += height; } else { rect.origin.x -= height; } }\
}while(0)

/**
 *  布局所有子view，overwite
 */
- (void)layoutSubviews {
    
    UIView *superview = [self panel];
    if (!superview) {
        return ;
    }
    
    NSInteger row_width = [self row_width];
    
    //布局
    CGRect rect = [self firstRowRectWithRowHeight:_rowHeight];
    BOOL isHOR = [self isHOR];
    BOOL isRowASC = [self isRowASC];

    //布局所有的子view
    NSArray *subviews = [self subviews];
    
    NSInteger cost_width = 0;
    
    NSMutableArray *rowviews = [NSMutableArray array];//用于存放一行的数据
    NSInteger sum_view_width = 0;
    
    for (UIView *view in subviews) {

    SSN_GOTO_FLAG:
        
        cost_width += isHOR ? view.ssn_width : view.ssn_height;
        
        if (cost_width >= row_width) {//换行
            
            BOOL reCheck = YES;
            if (cost_width == row_width || [rowviews count] == 0) {
                sum_view_width += isHOR ? view.ssn_width : view.ssn_height;
                [rowviews addObject:view];
                
                reCheck = NO;
            }
            
            //处理当前行
            [self layoutRowviews:rowviews inRow:rect sumViewWidth:sum_view_width isHOR:isHOR];
            
            //换行处理
            SSNUILayoutRowRectNext(rect, isHOR, isRowASC, _rowHeight);
            cost_width = 0;
            sum_view_width = 0;
            [rowviews removeAllObjects];
            
            if (reCheck) {//直接到下一行处理
                goto SSN_GOTO_FLAG;
            }
        }
        else {//不换行
            cost_width += _spacing;//加上间距
            sum_view_width += isHOR ? view.ssn_width : view.ssn_height;
            [rowviews addObject:view];
        }
    }
    
    //处理最后剩余部分
    if ([rowviews count]) {
        [self layoutRowviews:rowviews inRow:rect sumViewWidth:sum_view_width isHOR:isHOR];
    }
}
@end


@implementation SSNUITableLayout {
    NSMutableDictionary *_columnInfos;
}

- (NSMutableDictionary *)columnInfos {
    if (_columnInfos) {
        return _columnInfos;
    }
    _columnInfos = [[NSMutableDictionary alloc] initWithCapacity:1];
    return _columnInfos;
}

/**
 *  元素布局模型，依赖方向，默认值是SSNUIContentModeTopLeft
 *
 *  @param column 列数，取值[0～(columnCount-1)]
 *
 *  @return 第column列的布局模型，
 */
- (SSNUITableColumnInfo *)columnInfoAtColumn:(NSUInteger)column {
    return [[_columnInfos objectForKey:@(column)] copyWithZone:NULL];
}

/**
 *  设置每一列中布局模型
 *
 *  @param contentMode 设置的布局模型
 *  @param column      列数取值[0～(columnCount-1)]
 */
- (void)setColumnInfo:(SSNUITableColumnInfo *)columnInfo atColumn:(NSUInteger)column {
    [[self columnInfos] setObject:[columnInfo copy] forKey:@(column)];
}

/**
 *  布局所有子view，overwite
 */
- (void)layoutSubviews {
    //NSLog(@"nothing to do")
}
@end


@implementation SSNUITableColumnInfo

- (instancetype)copyWithZone:(NSZone *)zone {
    SSNUITableColumnInfo *cp = [[[SSNUITableColumnInfo class] alloc] init];
    cp.width = self.width;
    cp.contentInset = self.contentInset;
    cp.contentMode = self.contentMode;
    return cp;
}

@end
