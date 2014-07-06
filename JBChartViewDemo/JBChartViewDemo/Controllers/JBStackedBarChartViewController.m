//
//  JBStackedBarChartViewController.m
//  JBChartViewDemo
//
//  Created by Philippe Auriach on 06/07/2014.
//  Copyright (c) 2014 Jawbone. All rights reserved.
//

#import "JBStackedBarChartViewController.h"

// Views
#import "JBStackedBarChartView.h"
#import "JBChartHeaderView.h"
#import "JBBarChartFooterView.h"
#import "JBChartInformationView.h"

// Numerics
CGFloat const kJBStackedBarChartViewControllerChartHeight = 250.0f;
CGFloat const kJBStackedBarChartViewControllerChartPadding = 10.0f;
CGFloat const kJBStackedBarChartViewControllerChartHeaderHeight = 80.0f;
CGFloat const kJBStackedBarChartViewControllerChartHeaderPadding = 10.0f;
CGFloat const kJBStackedBarChartViewControllerChartFooterHeight = 25.0f;
CGFloat const kJBStackedBarChartViewControllerChartFooterPadding = 5.0f;
NSUInteger kJBStackedBarChartViewControllerBarPadding = 1;
NSInteger const kJBStackedBarChartViewControllerNumBars = 5;
NSInteger const kJBStackedBarChartViewControllerMaxBarHeight = 10;
NSInteger const kJBStackedBarChartViewControllerMinBarHeight = 5;

// Strings
NSString * const kJBStackedBarChartViewControllerNavButtonViewKey = @"view";

@interface JBStackedBarChartViewController () <JBStackedBarChartViewDelegate, JBStackedBarChartViewDataSource>

@property (nonatomic, strong) JBStackedBarChartView *barChartView;
@property (nonatomic, strong) JBChartInformationView *informationView;
@property (nonatomic, strong) NSArray *chartData;
@property (nonatomic, strong) NSArray *monthlySymbols;

// Buttons
- (void)chartToggleButtonPressed:(id)sender;

// Data
- (void)initFakeData;

@end

@implementation JBStackedBarChartViewController

#pragma mark - Alloc/Init

- (id)init
{
    self = [super init];
    if (self)
    {
        [self initFakeData];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initFakeData];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [self initFakeData];
    }
    return self;
}

#pragma mark - Date

- (void)initFakeData
{
    NSMutableArray *mutableChartData = [NSMutableArray array];
    for (int i=0; i<kJBStackedBarChartViewControllerNumBars; i++)
    {
        NSInteger delta = (kJBStackedBarChartViewControllerNumBars - abs((kJBStackedBarChartViewControllerNumBars - i) - i)) + 2;
        [mutableChartData addObject:[NSNumber numberWithFloat:MAX((delta * kJBStackedBarChartViewControllerMinBarHeight), arc4random() % (delta * kJBStackedBarChartViewControllerMaxBarHeight))]];
        
    }
    _chartData = [NSArray arrayWithArray:mutableChartData];
    _monthlySymbols = [[[NSDateFormatter alloc] init] shortMonthSymbols];
}

#pragma mark - View Lifecycle

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = kJBColorBarChartControllerBackground;
    self.navigationItem.rightBarButtonItem = [self chartToggleButtonWithTarget:self action:@selector(chartToggleButtonPressed:)];
    
    self.barChartView = [[JBStackedBarChartView alloc] init];
    self.barChartView.frame = CGRectMake(kJBStackedBarChartViewControllerChartPadding, kJBStackedBarChartViewControllerChartPadding, self.view.bounds.size.width - (kJBStackedBarChartViewControllerChartPadding * 2), kJBStackedBarChartViewControllerChartHeight);
    self.barChartView.delegate = self;
    self.barChartView.dataSource = self;
    self.barChartView.headerPadding = kJBStackedBarChartViewControllerChartHeaderPadding;
    self.barChartView.minimumValue = 0.0f;
    self.barChartView.backgroundColor = kJBColorBarChartBackground;
    
    JBChartHeaderView *headerView = [[JBChartHeaderView alloc] initWithFrame:CGRectMake(kJBStackedBarChartViewControllerChartPadding, ceil(self.view.bounds.size.height * 0.5) - ceil(kJBStackedBarChartViewControllerChartHeaderHeight * 0.5), self.view.bounds.size.width - (kJBStackedBarChartViewControllerChartPadding * 2), kJBStackedBarChartViewControllerChartHeaderHeight)];
    headerView.titleLabel.text = [kJBStringLabelAverageMonthlyTemperature uppercaseString];
    headerView.subtitleLabel.text = kJBStringLabel2012;
    headerView.separatorColor = kJBColorBarChartHeaderSeparatorColor;
    self.barChartView.headerView = headerView;
    
    JBBarChartFooterView *footerView = [[JBBarChartFooterView alloc] initWithFrame:CGRectMake(kJBStackedBarChartViewControllerChartPadding, ceil(self.view.bounds.size.height * 0.5) - ceil(kJBStackedBarChartViewControllerChartFooterHeight * 0.5), self.view.bounds.size.width - (kJBStackedBarChartViewControllerChartPadding * 2), kJBStackedBarChartViewControllerChartFooterHeight)];
    footerView.padding = kJBStackedBarChartViewControllerChartFooterPadding;
    footerView.leftLabel.text = [[self.monthlySymbols firstObject] uppercaseString];
    footerView.leftLabel.textColor = [UIColor whiteColor];
    footerView.rightLabel.text = [[self.monthlySymbols lastObject] uppercaseString];
    footerView.rightLabel.textColor = [UIColor whiteColor];
    self.barChartView.footerView = footerView;
    
    self.informationView = [[JBChartInformationView alloc] initWithFrame:CGRectMake(self.view.bounds.origin.x, CGRectGetMaxY(self.barChartView.frame), self.view.bounds.size.width, self.view.bounds.size.height - CGRectGetMaxY(self.barChartView.frame) - CGRectGetMaxY(self.navigationController.navigationBar.frame))];
    [self.view addSubview:self.informationView];
    
    [self.view addSubview:self.barChartView];
    [self.barChartView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.barChartView setState:JBChartViewStateExpanded];
}

#pragma mark - PAStackedBarChartViewDelegate

- (CGFloat)barChartView:(JBStackedBarChartView *)barChartView heightForBarViewAtAtIndex:(NSUInteger)index forDataIndexInsideBar:(NSUInteger)dataIndex
{
    if(index == 0){
        return dataIndex*100;
    }else if(index == 1){
        switch (dataIndex) {
            case 0:
                return 300;
            case 1:
                return 120;
            case 2:
                return 180;
        }
    }else if(index == 2){
        return 715;
    }
    return arc4random()%321;
}

#pragma mark - PAStackedBarChartViewDataSource

- (NSUInteger)numberOfStackedBarsInBarChartView:(JBStackedBarChartView *)barChartView forIndex:(NSUInteger)index{
    if(index == 0){
        return 5;
    }else if(index == 1){
        return 3;
    }else if(index == 2){
        return 1;
    }else{
        return arc4random()%5+1;
    }
}

- (NSUInteger)numberOfBarsInBarChartView:(JBStackedBarChartView *)barChartView
{
    return kJBStackedBarChartViewControllerNumBars;
}

- (NSUInteger)barPaddingForBarChartView:(JBStackedBarChartView *)barChartView
{
    return kJBStackedBarChartViewControllerBarPadding;
}

- (UIColor *)barChartView:(JBStackedBarChartView *)barChartView colorForBarViewAtIndex:(NSUInteger)index forDataIndexInsideBar:(NSUInteger)dataIndex
{
    return (dataIndex % 2 == 0) ? kJBColorBarChartBarBlue : kJBColorBarChartBarGreen;
}

- (UIColor *)barSelectionColorForBarChartView:(JBStackedBarChartView *)barChartView
{
    return [UIColor whiteColor];
}

- (void)barChartView:(JBStackedBarChartView *)barChartView didSelectBarAtIndex:(NSUInteger)index touchPoint:(CGPoint)touchPoint
{
    NSNumber *valueNumber = [self.chartData objectAtIndex:index];
    [self.informationView setValueText:[NSString stringWithFormat:kJBStringLabelDegreesFahrenheit, [valueNumber intValue], kJBStringLabelDegreeSymbol] unitText:nil];
    [self.informationView setTitleText:kJBStringLabelWorldwideAverage];
    [self.informationView setHidden:NO animated:YES];
    [self setTooltipVisible:YES animated:YES atTouchPoint:touchPoint];
    [self.tooltipView setText:[[self.monthlySymbols objectAtIndex:index] uppercaseString]];
}

- (void)didUnselectBarChartView:(JBStackedBarChartView *)barChartView
{
    [self.informationView setHidden:YES animated:YES];
    [self setTooltipVisible:NO animated:YES];
}

#pragma mark - Buttons

- (void)chartToggleButtonPressed:(id)sender
{
    UIView *buttonImageView = [self.navigationItem.rightBarButtonItem valueForKey:kJBStackedBarChartViewControllerNavButtonViewKey];
    buttonImageView.userInteractionEnabled = NO;
    
    CGAffineTransform transform = self.barChartView.state == JBChartViewStateExpanded ? CGAffineTransformMakeRotation(M_PI) : CGAffineTransformMakeRotation(0);
    buttonImageView.transform = transform;
    
    [self.barChartView setState:self.barChartView.state == JBChartViewStateExpanded ? JBChartViewStateCollapsed : JBChartViewStateExpanded animated:YES callback:^{
        buttonImageView.userInteractionEnabled = YES;
    }];
}

#pragma mark - Overrides

- (JBChartView *)chartView
{
    return self.barChartView;
}

@end
