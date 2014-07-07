//
//  JBStackedBarChartView.m
//  JBChartViewDemo
//
//  Created by Philippe Auriach on 06/07/2014.
//  Copyright (c) 2014 Jawbone. All rights reserved.
//

#import "JBStackedBarChartView.h"

// Numerics
CGFloat static const kJBBarChartViewBarBasePaddingMutliplier = 50.0f;
CGFloat static const kJBBarChartViewUndefinedCachedHeight = -1.0f;
CGFloat static const kJBBarChartViewStateAnimationDuration = 0.05f;
CGFloat static const kJBBarChartViewPopOffset = 10.0f; // used to offset bars for 'pop' animations
NSInteger static const kJBBarChartViewUndefinedBarIndex = -1;

// Colors (JBChartView)
static UIColor *kJBBarChartViewDefaultBarColor = nil;

@interface JBChartView (Private)

- (BOOL)hasMaximumValue;
- (BOOL)hasMinimumValue;

@end

@interface JBStackedBarChartView ()

@property (nonatomic, strong) NSDictionary *chartTotalDataDictionary; // key = column, value = height of the entire column
@property (nonatomic, strong) NSDictionary *chartStackedHeightDataDictionary; // key = column_dataIndex, value = height of the stack
@property (nonatomic, strong) NSDictionary *chartNumberOfStacksDataDictionary; // key = column, value = number of stack
@property (nonatomic, strong) NSArray *barViews;
@property (nonatomic, assign) CGFloat barPadding;
@property (nonatomic, assign) CGFloat cachedMaxHeight;
@property (nonatomic, assign) CGFloat cachedMinHeight;
@property (nonatomic, strong) JBChartVerticalSelectionView *verticalSelectionView;
@property (nonatomic, assign) BOOL verticalSelectionViewVisible;

// Initialization
- (void)construct;

// View quick accessors
- (CGFloat)availableHeight;
- (CGFloat)normalizedHeightForRawHeight:(NSNumber*)rawHeight;
- (CGFloat)barWidth;
- (CGFloat)popOffset;

// Touch helpers
- (NSInteger)barViewIndexForPoint:(CGPoint)point;
- (UIView *)barViewForForPoint:(CGPoint)point;
- (void)touchesBeganOrMovedWithTouches:(NSSet *)touches;
- (void)touchesEndedOrCancelledWithTouches:(NSSet *)touches;

// Setters
- (void)setVerticalSelectionViewVisible:(BOOL)verticalSelectionViewVisible animated:(BOOL)animated;

@end

@implementation JBStackedBarChartView

#pragma mark - Alloc/Init

+ (void)initialize
{
    if (self == [JBStackedBarChartView class])
    {
        kJBBarChartViewDefaultBarColor = [UIColor blackColor];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self construct];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self construct];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [self construct];
    }
    return self;
}

- (void)construct
{
    _showsVerticalSelection = YES;
    _cachedMinHeight = kJBBarChartViewUndefinedCachedHeight;
    _cachedMaxHeight = kJBBarChartViewUndefinedCachedHeight;
}

#pragma mark - Memory Management

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - Data

- (void)reloadData
{
    // reset cached max height
    self.cachedMinHeight = kJBBarChartViewUndefinedCachedHeight;
    self.cachedMaxHeight = kJBBarChartViewUndefinedCachedHeight;
    
    /*
     * The data collection holds all position information:
     * constructed via datasource and delegate functions
     */
    dispatch_block_t createDataDictionaries = ^{
        
        // Grab the count
        NSAssert([self.dataSource respondsToSelector:@selector(numberOfBarsInBarChartView:)], @"JBBarChartView // datasource must implement - (NSUInteger)numberOfBarsInBarChartView:(JBBarChartView *)barChartView");
        NSUInteger dataCount = [self.dataSource numberOfBarsInBarChartView:self];
        
        NSAssert([self.dataSource respondsToSelector:@selector(numberOfStackedBarsInBarChartView:forIndex:)], @"JBBarChartView // datasource must implement - (NSUInteger)numberOfStackedBarsInBarChartView:(JBBarChartView *)barChartView forIndex:(NSUInteger)index");
        
        // Build up the data collection
        NSAssert([self.delegate respondsToSelector:@selector(barChartView:heightForBarViewAtAtIndex:forDataIndexInsideBar:)], @"JBBarChartView // delegate must implement - (CGFloat)barChartView:(JBBarChartView *)barChartView heightForBarViewAtAtIndex:(NSUInteger)index");
        NSMutableDictionary *totalDatasDictionary = [NSMutableDictionary dictionary];
        NSMutableDictionary *stackedHeightsDictionary = [NSMutableDictionary dictionary];
        NSMutableDictionary *nbOfStackDictionary = [NSMutableDictionary dictionary];
        for (NSUInteger index=0; index<dataCount; index++)
        {
            //grab the number of stacked bar
            NSUInteger nbOfStackedBar = [self.dataSource numberOfStackedBarsInBarChartView:self forIndex:index];
            [nbOfStackDictionary setObject:[NSNumber numberWithLong:nbOfStackedBar] forKey:[NSNumber numberWithInt:(int)index]];
            CGFloat totalHeight = 0;
            for(int dataIndex=0; dataIndex<nbOfStackedBar; dataIndex++){
                CGFloat oneStackHeight = [self.delegate barChartView:self heightForBarViewAtAtIndex:index forDataIndexInsideBar:dataIndex];
                totalHeight += oneStackHeight;
                //grab the height of each stacked
                NSString *stackedHeightKey = [NSString stringWithFormat:@"%d_%d", (int)index, (int)dataIndex];
                [stackedHeightsDictionary setObject:[NSNumber numberWithFloat:oneStackHeight] forKey:stackedHeightKey];
            }
            NSAssert(totalHeight >= 0, @"JBBarChartView // datasource function - (CGFloat)barChartView:(JBBarChartView *)barChartView heightForBarViewAtAtIndex:(NSUInteger)index must return a CGFloat >= 0");
            [totalDatasDictionary setObject:[NSNumber numberWithFloat:totalHeight] forKey:[NSNumber numberWithInt:(int)index]];
        }
        self.chartTotalDataDictionary = [NSDictionary dictionaryWithDictionary:totalDatasDictionary];
        self.chartNumberOfStacksDataDictionary = [NSDictionary dictionaryWithDictionary:nbOfStackDictionary];
        self.chartStackedHeightDataDictionary = [NSDictionary dictionaryWithDictionary:stackedHeightsDictionary];
    };
    
    /*
     * Determines the padding between bars as a function of # of bars
     */
    dispatch_block_t createBarPadding = ^{
        if ([self.dataSource respondsToSelector:@selector(barPaddingForBarChartView:)])
        {
            self.barPadding = [self.dataSource barPaddingForBarChartView:self];
        }
        else
        {
            NSUInteger totalBars = [[self.chartTotalDataDictionary allKeys] count];
            self.barPadding = (1/(float)totalBars) * kJBBarChartViewBarBasePaddingMutliplier;
        }
    };
    
    /*
     * Creates a new bar graph view using the previously calculated data model
     */
    dispatch_block_t createBars = ^{
        
        // Remove old bars
        for (UIView *barView in self.barViews)
        {
            [barView removeFromSuperview];
        }
        
        CGFloat xOffset = 0;
        NSUInteger index = 0;
        NSMutableArray *mutableBarViews = [NSMutableArray array];
        for (NSNumber *key in [[self.chartTotalDataDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)])
        {
            UIView *barView = nil; // since all bars are visible at once, no need to cache this view
            if ([self.dataSource respondsToSelector:@selector(barChartView:barViewAtIndex:)])
            {
                barView = [self.dataSource barChartView:self barViewAtIndex:index];
                NSAssert(barView != nil, @"JBBarChartView // datasource function - (UIView *)barChartView:(JBBarChartView *)barChartView barViewAtIndex:(NSUInteger)index must return a non-nil UIView subclass");
            }
            else
            {
                barView = [[UIView alloc] init];
                if ([self.dataSource respondsToSelector:@selector(barChartView:colorForBarViewAtIndex:forDataIndexInsideBar:)])
                {
                    CGFloat totalHeight = [(NSNumber*)[self.chartTotalDataDictionary objectForKey:key] floatValue];
                    int nbOfStacked = [(NSNumber*)[self.chartNumberOfStacksDataDictionary objectForKey:key] intValue];
                    
                    UIView *lastStacked = nil;
                    for(int dataIndex = 0; dataIndex < nbOfStacked; dataIndex++){
                        UIView *stacked = [[UIView alloc] initWithFrame:CGRectZero];
                        stacked.translatesAutoresizingMaskIntoConstraints = NO;
                        stacked.backgroundColor = [self.dataSource barChartView:self colorForBarViewAtIndex:index forDataIndexInsideBar:dataIndex];
                        [barView addSubview:stacked];
                        
                        if(dataIndex == 0){
                            //the first stacked bar is aligned to the bottom of the view
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:stacked attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                                   toItem:barView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0]];
                        }else{
                            //if it's not the first stackedBar we are adding on this index, we add a refview that will be helpful when calculating the height of the singla stack
                            UIView *refView = [[UIView alloc] init];
                            refView.translatesAutoresizingMaskIntoConstraints = NO;
                            refView.backgroundColor = [UIColor clearColor];
                            [barView addSubview:refView];
                            //refview has the same height of the barView, minus the padding (used for animation)
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:refView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-kJBBarChartViewPopOffset]];
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:refView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0]];
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:refView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0]];
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:refView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0]];
                            
                            //Calculate the percentage of height the stacked should take, and apply it as a constraint related to the height of the ref view (that's the only reason we have a ref view) (this is actually where everything is happening !)
                            CGFloat stackHeight = [(NSNumber*)[self.chartStackedHeightDataDictionary objectForKey:[NSString stringWithFormat:@"%d_%d", [key intValue], dataIndex]] floatValue];
                            CGFloat percent = totalHeight <= 0 ? 0 : stackHeight / totalHeight;
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:stacked attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:refView attribute:NSLayoutAttributeHeight multiplier:percent constant:0]];
                            
                            //align bottom of the stacked with the bottom of the previous tsacked
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:stacked attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:lastStacked attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0]];
                        }
                        
                        //let the stacked view has the same width of the barview
                        [barView addConstraint:[NSLayoutConstraint constraintWithItem:stacked attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0]];
                        [barView addConstraint:[NSLayoutConstraint constraintWithItem:stacked attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0]];
                        
                        if(dataIndex == nbOfStacked-1){
                            //the last stack should have its top sticking to the barview's top
                            [barView addConstraint:[NSLayoutConstraint constraintWithItem:stacked attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:barView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0]];
                        }
                        
                        lastStacked = stacked;
                    }
                }
                else
                {
                    barView.backgroundColor = kJBBarChartViewDefaultBarColor;
                }
            }
            
            CGFloat height = [self normalizedHeightForRawHeight:[self.chartTotalDataDictionary objectForKey:key]];
            CGFloat extensionHeight = height > 0.0 ? kJBBarChartViewPopOffset : 0.0;
            barView.frame = CGRectMake(xOffset, self.bounds.size.height - height - self.footerView.frame.size.height, [self barWidth], height + extensionHeight);
            [mutableBarViews addObject:barView];
            
            // Add new bar
            if (self.footerView)
            {
                [self insertSubview:barView belowSubview:self.footerView];
            }
            else
            {
                [self addSubview:barView];
            }
            
            xOffset += ([self barWidth] + self.barPadding);
            index++;
        }
        self.barViews = [NSArray arrayWithArray:mutableBarViews];
    };
    
    /*
     * Creates a vertical selection view for touch events
     */
    dispatch_block_t createSelectionView = ^{
        
        // Remove old selection bar
        if (self.verticalSelectionView)
        {
            [self.verticalSelectionView removeFromSuperview];
            self.verticalSelectionView = nil;
        }
        
        self.verticalSelectionView = [[JBChartVerticalSelectionView alloc] initWithFrame:CGRectMake(0, 0, [self barWidth], self.bounds.size.height - self.footerView.frame.size.height)];
        self.verticalSelectionView.alpha = 0.0;
        self.verticalSelectionView.hidden = !self.showsVerticalSelection;
        if ([self.dataSource respondsToSelector:@selector(barSelectionColorForBarChartView:)])
        {
            self.verticalSelectionView.bgColor = [self.dataSource barSelectionColorForBarChartView:self];
        }
        
        // Add new selection bar
        if (self.footerView)
        {
            [self insertSubview:self.verticalSelectionView belowSubview:self.footerView];
        }
        else
        {
            [self addSubview:self.verticalSelectionView];
        }
    };
    
    createDataDictionaries();
    createBarPadding();
    createBars();
    createSelectionView();
    
    // Position header and footer
    self.headerView.frame = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, self.headerView.frame.size.height);
    self.footerView.frame = CGRectMake(self.bounds.origin.x, self.bounds.size.height - self.footerView.frame.size.height, self.bounds.size.width, self.footerView.frame.size.height);
    
    // Refresh state
    [self setState:self.state animated:NO callback:nil force:YES];
}

#pragma mark - View Quick Accessors

- (CGFloat)availableHeight
{
    return self.bounds.size.height - self.headerView.frame.size.height - self.footerView.frame.size.height - self.headerPadding;
}

- (CGFloat)normalizedHeightForRawHeight:(NSNumber*)rawHeight
{
    CGFloat minHeight = [self minimumValue];
    CGFloat maxHeight = [self maximumValue];
    CGFloat value = [rawHeight floatValue];
    
    if ((maxHeight - minHeight) <= 0)
    {
        return 0;
    }
    
    return ((value - minHeight) / (maxHeight - minHeight)) * [self availableHeight];
}

- (CGFloat)barWidth
{
    NSUInteger barCount = [[self.chartTotalDataDictionary allKeys] count];
    if (barCount > 0)
    {
        CGFloat totalPadding = (barCount - 1) * self.barPadding;
        CGFloat availableWidth = self.bounds.size.width - totalPadding;
        return availableWidth / barCount;
    }
    return 0;
}

- (CGFloat)popOffset
{
    return self.bounds.size.height - self.footerView.frame.size.height;
}

#pragma mark - Setters

- (void)setState:(JBChartViewState)state animated:(BOOL)animated callback:(void (^)())callback force:(BOOL)force
{
    [super setState:state animated:animated callback:callback force:force];
    
    dispatch_block_t callbackCopy = [callback copy];
    
    if ([self.barViews count] > 0)
    {
        if (animated)
        {
            CGFloat popOffset = [self popOffset];
            
            NSUInteger index = 0;
            for (UIView *barView in self.barViews)
            {
                [UIView animateWithDuration:kJBBarChartViewStateAnimationDuration delay:(kJBBarChartViewStateAnimationDuration * 0.5) * index options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    barView.frame = CGRectMake(barView.frame.origin.x, popOffset - barView.frame.size.height, barView.frame.size.width, barView.frame.size.height);
                } completion:^(BOOL finished) {
                    [UIView animateWithDuration:kJBBarChartViewStateAnimationDuration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                        if (state == JBChartViewStateExpanded)
                        {
                            barView.frame = CGRectMake(barView.frame.origin.x, popOffset - barView.frame.size.height + kJBBarChartViewPopOffset, barView.frame.size.width, barView.frame.size.height);
                        }
                        else if (state == JBChartViewStateCollapsed)
                        {
                            barView.frame = CGRectMake(barView.frame.origin.x, self.bounds.size.height, barView.frame.size.width, barView.frame.size.height);
                        }
                    } completion:^(BOOL lastBarFinished) {
                        if (index == [self.barViews count] - 1)
                        {
                            if (callbackCopy)
                            {
                                callbackCopy();
                            }
                        }
                    }];
                }];
                index++;
            }
        }
        else
        {
            for (UIView *barView in self.barViews)
            {
                if (state == JBChartViewStateExpanded)
                {
                    barView.frame = CGRectMake(barView.frame.origin.x, (self.bounds.size.height + kJBBarChartViewPopOffset) - (barView.frame.size.height + self.footerView.frame.size.height), barView.frame.size.width, barView.frame.size.height);
                }
                else if (state == JBChartViewStateCollapsed)
                {
                    barView.frame = CGRectMake(barView.frame.origin.x, self.bounds.size.height, barView.frame.size.width, barView.frame.size.height);
                }
            }
            if (callbackCopy)
            {
                callbackCopy();
            }
        }
    }
    else
    {
        if (callbackCopy)
        {
            callbackCopy();
        }
    }
}

- (void)setState:(JBChartViewState)state animated:(BOOL)animated callback:(void (^)())callback
{
    [self setState:state animated:animated callback:callback force:NO];
}

#pragma mark - Getters

- (CGFloat)cachedMinHeight
{
    if(_cachedMinHeight == kJBBarChartViewUndefinedCachedHeight)
    {
        NSArray *chartValues = [[NSMutableArray arrayWithArray:[self.chartTotalDataDictionary allValues]] sortedArrayUsingSelector:@selector(compare:)];
        _cachedMinHeight =  [[chartValues firstObject] floatValue];
    }
    return _cachedMinHeight;
}

- (CGFloat)cachedMaxHeight
{
    if (_cachedMaxHeight == kJBBarChartViewUndefinedCachedHeight)
    {
        NSArray *chartValues = [[NSMutableArray arrayWithArray:[self.chartTotalDataDictionary allValues]] sortedArrayUsingSelector:@selector(compare:)];
        _cachedMaxHeight =  [[chartValues lastObject] floatValue];
    }
    return _cachedMaxHeight;
}

- (CGFloat)minimumValue
{
    if ([self hasMinimumValue])
    {
        return fminf(self.cachedMinHeight, [super minimumValue]);
    }
    return self.cachedMinHeight;
}

- (CGFloat)maximumValue
{
    if ([self hasMaximumValue])
    {
        return fmaxf(self.cachedMaxHeight, [super maximumValue]);
    }
    return self.cachedMaxHeight;
}

#pragma mark - Touch Helpers

- (NSInteger)barViewIndexForPoint:(CGPoint)point
{
    NSUInteger index = 0;
    NSUInteger selectedIndex = kJBBarChartViewUndefinedBarIndex;
    
    if (point.x < 0 || point.x > self.bounds.size.width)
    {
        return selectedIndex;
    }
    
    CGFloat padding = ceil(self.barPadding * 0.5);
    for (UIView *barView in self.barViews)
    {
        CGFloat minX = CGRectGetMinX(barView.frame) - padding;
        CGFloat maxX = CGRectGetMaxX(barView.frame) + padding;
        if ((point.x >= minX) && (point.x <= maxX))
        {
            selectedIndex = index;
            break;
        }
        index++;
    }
    return selectedIndex;
}

- (UIView *)barViewForForPoint:(CGPoint)point
{
    UIView *barView = nil;
    NSInteger selectedIndex = [self barViewIndexForPoint:point];
    if (selectedIndex >= 0)
    {
        return [self.barViews objectAtIndex:[self barViewIndexForPoint:point]];
    }
    return barView;
}

- (void)touchesBeganOrMovedWithTouches:(NSSet *)touches
{
    if (self.state == JBChartViewStateCollapsed || [[self.chartTotalDataDictionary allKeys] count] <= 0)
    {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    UIView *barView = [self barViewForForPoint:touchPoint];
    if (barView == nil)
    {
        [self setVerticalSelectionViewVisible:NO animated:YES];
        return;
    }
    CGRect barViewFrame = barView.frame;
    CGRect selectionViewFrame = self.verticalSelectionView.frame;
    selectionViewFrame.origin.x = barViewFrame.origin.x;
    self.verticalSelectionView.frame = selectionViewFrame;
    [self setVerticalSelectionViewVisible:YES animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(barChartView:didSelectBarAtIndex:touchPoint:)])
    {
        [self.delegate barChartView:self didSelectBarAtIndex:[self barViewIndexForPoint:touchPoint] touchPoint:touchPoint];
    }
    
    if ([self.delegate respondsToSelector:@selector(barChartView:didSelectBarAtIndex:)])
    {
        [self.delegate barChartView:self didSelectBarAtIndex:[self barViewIndexForPoint:touchPoint]];
    }
}

- (void)touchesEndedOrCancelledWithTouches:(NSSet *)touches
{
    if (self.state == JBChartViewStateCollapsed || [[self.chartTotalDataDictionary allKeys] count] <= 0)
    {
        return;
    }
    
    [self setVerticalSelectionViewVisible:NO animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(didUnselectBarChartView:)])
    {
        [self.delegate didUnselectBarChartView:self];
    }
}

#pragma mark - Setters

- (void)setVerticalSelectionViewVisible:(BOOL)verticalSelectionViewVisible animated:(BOOL)animated
{
    _verticalSelectionViewVisible = verticalSelectionViewVisible;
    
    if (animated)
    {
        [UIView animateWithDuration:kJBChartViewDefaultAnimationDuration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.verticalSelectionView.alpha = self.verticalSelectionViewVisible ? 1.0 : 0.0;
        } completion:nil];
    }
    else
    {
        self.verticalSelectionView.alpha = _verticalSelectionViewVisible ? 1.0 : 0.0;
    }
}

- (void)setVerticalSelectionViewVisible:(BOOL)verticalSelectionViewVisible
{
    [self setVerticalSelectionViewVisible:verticalSelectionViewVisible animated:NO];
}

- (void)setShowsVerticalSelection:(BOOL)showsVerticalSelection
{
    _showsVerticalSelection = showsVerticalSelection;
    self.verticalSelectionView.hidden = _showsVerticalSelection ? NO : YES;
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesBeganOrMovedWithTouches:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesBeganOrMovedWithTouches:touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEndedOrCancelledWithTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEndedOrCancelledWithTouches:touches];
}

@end
