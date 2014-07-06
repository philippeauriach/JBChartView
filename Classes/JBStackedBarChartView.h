//
//  JBStackedBarChartView.h
//  JBChartViewDemo
//
//  Created by Philippe Auriach on 06/07/2014.
//  Copyright (c) 2014 Jawbone. All rights reserved.
//

#import "JBChartView.h"

@protocol JBStackedBarChartViewDelegate;
@protocol JBStackedBarChartViewDataSource;

@interface JBStackedBarChartView : JBChartView

@property (nonatomic, weak) id<JBStackedBarChartViewDelegate> delegate;
@property (nonatomic, weak) id<JBStackedBarChartViewDataSource> dataSource;

/**
 *  Vertical highlight overlayed on bar during touch events.
 *
 *  Default: YES.
 */
@property (nonatomic, assign) BOOL showsVerticalSelection;

@end

@protocol JBStackedBarChartViewDelegate <NSObject>

@required

/**
 *  Height for a bar at a given index (left to right) and a dataIndex (index of stacked inside the bar, bottom to top). 
 *  There is no ceiling on the the height; the chart will automatically normalize all values between the overal min and max heights.
 *
 *  @param barChartView     The bar chart object requesting this information.
 *  @param index            The 0-based index of a given bar (left to right, x-axis).
 *
 *  @return The y-axis height of the supplied bar index (x-axis)
 */
- (CGFloat)barChartView:(JBStackedBarChartView *)barChartView heightForBarViewAtAtIndex:(NSUInteger)index forDataIndexInsideBar:(NSUInteger)dataIndex;

@optional

/**
 *  Occurs when a touch gesture event occurs on a given bar (chart must be expanded).
 *  and the selection must occur within the bounds of the chart.
 *
 *  @param barChartView     A bar chart object informing the delegate about the new selection.
 *  @param index            The 0-based index of a given bar (left to right, x-axis).
 *  @param touchPoint       The touch point in relation to the chart's bounds (excludes footer and header).
 */
- (void)barChartView:(JBStackedBarChartView *)barChartView didSelectBarAtIndex:(NSUInteger)index touchPoint:(CGPoint)touchPoint;
- (void)barChartView:(JBStackedBarChartView *)barChartView didSelectBarAtIndex:(NSUInteger)index;

/**
 *  Occurs when selection ends by either ending a touch event or selecting an area that is outside the view's bounds.
 *  For selection start events, see: didSelectBarAtIndex...
 *
 *  @param barChartView     A bar chart object informing the delegate about the unselection.
 */
- (void)didUnselectBarChartView:(JBStackedBarChartView *)barChartView;

@end

@protocol JBStackedBarChartViewDataSource <NSObject>

@required

/**
 *  The number of bars in a given bar chart is the number of vertical views shown along the x-axis.
 *
 *  @param barChartView     The bar chart object requesting this information.
 *
 *  @return Number of bars in the given chart, displayed horizontally along the chart's x-axis.
 */
- (NSUInteger)numberOfBarsInBarChartView:(JBStackedBarChartView *)barChartView;

/**
 *
 *
 *  @param barChartView     The bar chart object requesting this information.
 *
 *  @return The number of stackedBar in each bar
 */
- (NSUInteger)numberOfStackedBarsInBarChartView:(JBStackedBarChartView *)barChartView forIndex:(NSUInteger)index;

@optional

/**
 *  Horizontal padding between bars.
 *
 *  Default: 'best-guess' algorithm based on the the total number of bars and width of the chart.
 *
 *  @param barChartView     The bar chart object requesting this information.
 *
 *  @return Horizontal width (in pixels) between each bar.
 */
- (NSUInteger)barPaddingForBarChartView:(JBStackedBarChartView *)barChartView;

/**
 *  A UIView subclass representing the bar at a particular index.
 *
 *  Default: solid black UIView.
 *
 *  @param barChartView     The bar chart object requesting this information.
 *  @param index            The 0-based index of a given bar (left to right, x-axis).
 *
 *  @return A UIView subclass. The view will automatically be resized by the chart during creation (ie. no need to set the frame).
 */
- (UIView *)barChartView:(JBStackedBarChartView *)barChartView barViewAtIndex:(NSUInteger)index;

/**
 *  If you already implement barChartView:barViewAtIndex: delegate - this method has no effect.
 *  If a custom UIView isn't supplied, a flat bar will be made automatically (default color black).
 *
 *  Default: if none specified - calls barChartView:barViewAtIndex:.
 *
 *  @param barChartView     The bar chart object requesting this information.
 *  @param index            The 0-based index of a given bar (left to right, x-axis).
 *
 *  @return The color to be used to color a bar in the chart.
 */
- (UIColor *)barChartView:(JBStackedBarChartView *)barChartView colorForBarViewAtIndex:(NSUInteger)index forDataIndexInsideBar:(NSUInteger)dataIndex;

/**
 *  The selection color to be overlayed on a bar during touch events.
 *  The color is automatically faded to transparent (vertically). The property showsVerticalSelection
 *  must be YES for the color to apply.
 *
 *  Default: white color (faded to transparent).
 *
 *  @param barChartView     The bar chart object requesting this information.
 *
 *  @return The color to be used on each bar selection.
 */
- (UIColor *)barSelectionColorForBarChartView:(JBStackedBarChartView *)barChartView;

@end
