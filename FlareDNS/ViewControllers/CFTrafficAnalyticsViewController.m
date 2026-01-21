//
//  CFTrafficAnalyticsViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFTrafficAnalyticsViewController.h"
#import "CFSimpleChartView.h"
#import "CFAPIService.h"
#import "CFTrafficData.h"
#import "UIColor+FlareDNS.h"

typedef NS_ENUM(NSInteger, CFTimePeriod) {
    CFTimePeriod24h,
    CFTimePeriod7d,
    CFTimePeriod30d
};

@interface CFTrafficAnalyticsViewController ()

@property (nonatomic, strong) CFZone *zone;
@property (nonatomic, strong) UISegmentedControl *periodSelector;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *trafficCard;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) CFTrafficData *trafficData;
@property (nonatomic, assign) CFTimePeriod selectedPeriod;

// Metric views
@property (nonatomic, strong) UILabel *visitorsValueLabel;
@property (nonatomic, strong) CFSimpleChartView *visitorsChart;
@property (nonatomic, strong) UILabel *requestsValueLabel;
@property (nonatomic, strong) CFSimpleChartView *requestsChart;
@property (nonatomic, strong) UILabel *cachedValueLabel;
@property (nonatomic, strong) CFSimpleChartView *cachedChart;
@property (nonatomic, strong) UILabel *dataServedValueLabel;
@property (nonatomic, strong) CFSimpleChartView *dataServedChart;

@end

@implementation CFTrafficAnalyticsViewController

- (instancetype)initWithZone:(CFZone *)zone {
    self = [super init];
    if (self) {
        _zone = zone;
        _selectedPeriod = CFTimePeriod24h;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupUI];
    [self loadData];
}

- (void)setupNavigationBar {
    // Use standard navigation bar (gets Liquid Glass on iOS 26+)
    self.title = @"Traffic Analytics";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}

- (void)setupUI {
    // Adapt background color based on iOS version
    if (@available(iOS 26.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor cf_primaryBackgroundColor];
    }
    
    // Determine colors based on iOS version
    UIColor *secondaryBackground;
    UIColor *primaryText;
    UIColor *secondaryText;
    
    if (@available(iOS 26.0, *)) {
        secondaryBackground = [UIColor secondarySystemBackgroundColor];
        primaryText = [UIColor labelColor];
        secondaryText = [UIColor secondaryLabelColor];
    } else {
        secondaryBackground = [UIColor cf_secondaryBackgroundColor];
        primaryText = [UIColor cf_primaryTextColor];
        secondaryText = [UIColor cf_secondaryTextColor];
    }
    
    // Period selector
    self.periodSelector = [[UISegmentedControl alloc] initWithItems:@[@"24h", @"7d", @"30d"]];
    self.periodSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.periodSelector.selectedSegmentIndex = 0;
    [self.periodSelector addTarget:self action:@selector(periodChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.periodSelector];
    
    // Scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];
    
    // Traffic card
    self.trafficCard = [[UIView alloc] init];
    self.trafficCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.trafficCard.backgroundColor = secondaryBackground;
    self.trafficCard.layer.cornerRadius = 12;
    [self.scrollView addSubview:self.trafficCard];
    
    // Traffic header
    UILabel *trafficHeader = [[UILabel alloc] init];
    trafficHeader.translatesAutoresizingMaskIntoConstraints = NO;
    trafficHeader.text = @"TRAFFIC";
    trafficHeader.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    trafficHeader.textColor = secondaryText;
    [self.scrollView addSubview:trafficHeader];
    
    // Card title
    UIImageView *chartIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chart.xyaxis.line"]];
    chartIcon.translatesAutoresizingMaskIntoConstraints = NO;
    chartIcon.tintColor = [UIColor systemBlueColor];
    [self.trafficCard addSubview:chartIcon];
    
    UILabel *trafficTitle = [[UILabel alloc] init];
    trafficTitle.translatesAutoresizingMaskIntoConstraints = NO;
    trafficTitle.text = @"Traffic";
    trafficTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    trafficTitle.textColor = primaryText;
    [self.trafficCard addSubview:trafficTitle];
    
    UILabel *periodLabel = [[UILabel alloc] init];
    periodLabel.translatesAutoresizingMaskIntoConstraints = NO;
    periodLabel.text = @"24h";
    periodLabel.font = [UIFont systemFontOfSize:13];
    periodLabel.textColor = secondaryText;
    periodLabel.tag = 200;
    [self.trafficCard addSubview:periodLabel];
    
    // Create metric rows
    [self createVisitorsMetricRowWithYOffset:60];
    [self createRequestsMetricRowWithYOffset:140];
    [self createCachedMetricRowWithYOffset:220];
    [self createDataServedMetricRowWithYOffset:300];
    
    // Activity indicator
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.periodSelector.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.periodSelector.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.periodSelector.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.periodSelector.heightAnchor constraintEqualToConstant:32],
        
        [self.scrollView.topAnchor constraintEqualToAnchor:self.periodSelector.bottomAnchor constant:16],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [trafficHeader.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:8],
        [trafficHeader.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        
        [self.trafficCard.topAnchor constraintEqualToAnchor:trafficHeader.bottomAnchor constant:8],
        [self.trafficCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.trafficCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.trafficCard.heightAnchor constraintEqualToConstant:380],
        [self.trafficCard.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-20],
        
        [chartIcon.topAnchor constraintEqualToAnchor:self.trafficCard.topAnchor constant:16],
        [chartIcon.leadingAnchor constraintEqualToAnchor:self.trafficCard.leadingAnchor constant:16],
        [chartIcon.widthAnchor constraintEqualToConstant:20],
        [chartIcon.heightAnchor constraintEqualToConstant:20],
        
        [trafficTitle.centerYAnchor constraintEqualToAnchor:chartIcon.centerYAnchor],
        [trafficTitle.leadingAnchor constraintEqualToAnchor:chartIcon.trailingAnchor constant:8],
        
        [periodLabel.centerYAnchor constraintEqualToAnchor:chartIcon.centerYAnchor],
        [periodLabel.trailingAnchor constraintEqualToAnchor:self.trafficCard.trailingAnchor constant:-16],
        
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)createMetricRowWithTitle:(NSString *)title valueLabel:(UILabel *)valueLabel chart:(CFSimpleChartView *)chart yOffset:(CGFloat)yOffset {
    // Determine colors based on iOS version
    UIColor *titleColor;
    UIColor *valueColor;
    UIColor *separatorColor;
    
    if (@available(iOS 26.0, *)) {
        titleColor = [UIColor secondaryLabelColor];
        valueColor = [UIColor labelColor];
        separatorColor = [UIColor separatorColor];
    } else {
        titleColor = [UIColor cf_secondaryTextColor];
        valueColor = [UIColor cf_primaryTextColor];
        separatorColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    }
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:15];
    titleLabel.textColor = titleColor;
    [self.trafficCard addSubview:titleLabel];
    
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.text = @"--";
    valueLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    valueLabel.textColor = valueColor;
    valueLabel.textAlignment = NSTextAlignmentRight;
    [self.trafficCard addSubview:valueLabel];
    
    chart.translatesAutoresizingMaskIntoConstraints = NO;
    [self.trafficCard addSubview:chart];
    
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = separatorColor;
    [self.trafficCard addSubview:separator];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.trafficCard.topAnchor constant:yOffset],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.trafficCard.leadingAnchor constant:16],
        
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.topAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:self.trafficCard.trailingAnchor constant:-16],
        
        [chart.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [chart.leadingAnchor constraintEqualToAnchor:self.trafficCard.leadingAnchor constant:16],
        [chart.trailingAnchor constraintEqualToAnchor:self.trafficCard.trailingAnchor constant:-16],
        [chart.heightAnchor constraintEqualToConstant:40],
        
        [separator.topAnchor constraintEqualToAnchor:chart.bottomAnchor constant:8],
        [separator.leadingAnchor constraintEqualToAnchor:self.trafficCard.leadingAnchor constant:16],
        [separator.trailingAnchor constraintEqualToAnchor:self.trafficCard.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:0.5]
    ]];
}

- (void)createVisitorsMetricRowWithYOffset:(CGFloat)yOffset {
    self.visitorsValueLabel = [[UILabel alloc] init];
    self.visitorsChart = [[CFSimpleChartView alloc] init];
    [self createMetricRowWithTitle:@"Unique Visitors" valueLabel:self.visitorsValueLabel chart:self.visitorsChart yOffset:yOffset];
}

- (void)createRequestsMetricRowWithYOffset:(CGFloat)yOffset {
    self.requestsValueLabel = [[UILabel alloc] init];
    self.requestsChart = [[CFSimpleChartView alloc] init];
    [self createMetricRowWithTitle:@"Total Requests" valueLabel:self.requestsValueLabel chart:self.requestsChart yOffset:yOffset];
}

- (void)createCachedMetricRowWithYOffset:(CGFloat)yOffset {
    self.cachedValueLabel = [[UILabel alloc] init];
    self.cachedChart = [[CFSimpleChartView alloc] init];
    [self createMetricRowWithTitle:@"Percent Cached" valueLabel:self.cachedValueLabel chart:self.cachedChart yOffset:yOffset];
}

- (void)createDataServedMetricRowWithYOffset:(CGFloat)yOffset {
    self.dataServedValueLabel = [[UILabel alloc] init];
    self.dataServedChart = [[CFSimpleChartView alloc] init];
    [self createMetricRowWithTitle:@"Total Data Served" valueLabel:self.dataServedValueLabel chart:self.dataServedChart yOffset:yOffset];
}

- (void)loadData {
    [self.activityIndicator startAnimating];
    
    NSDate *until = [NSDate date];
    NSDate *since;
    NSString *periodText;
    
    switch (self.selectedPeriod) {
        case CFTimePeriod24h:
            since = [until dateByAddingTimeInterval:-24 * 60 * 60];
            periodText = @"24h";
            break;
        case CFTimePeriod7d:
            since = [until dateByAddingTimeInterval:-7 * 24 * 60 * 60];
            periodText = @"7d";
            break;
        case CFTimePeriod30d:
            since = [until dateByAddingTimeInterval:-30 * 24 * 60 * 60];
            periodText = @"30d";
            break;
    }
    
    UILabel *periodLabel = [self.trafficCard viewWithTag:200];
    periodLabel.text = periodText;
    
    [[CFAPIService shared] fetchTrafficAnalyticsForZoneID:self.zone.zoneID since:since until:until completion:^(CFTrafficData * _Nullable data, NSError * _Nullable error) {
        [self.activityIndicator stopAnimating];
        
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            return;
        }
        
        self.trafficData = data;
        [self updateUI];
    }];
}

- (void)updateUI {
    // Check if there's no data available
    BOOL hasNoData = (self.trafficData.totalRequests == 0 && 
                      self.trafficData.uniqueVisitors == 0 && 
                      self.trafficData.totalDataServed == 0);
    
    if (hasNoData) {
        self.visitorsValueLabel.text = @"--";
        self.requestsValueLabel.text = @"--";
        self.cachedValueLabel.text = @"--";
        self.dataServedValueLabel.text = @"--";
        
        // Clear charts
        self.visitorsChart.dataPoints = @[];
        self.requestsChart.dataPoints = @[];
        self.cachedChart.dataPoints = @[];
        self.dataServedChart.dataPoints = @[];
        
        // Show info alert
        [self showAlertWithTitle:@"No Data Available" message:@"No traffic data is available for this time period. This could be because the domain has no traffic during this period or analytics data is not yet available."];
        return;
    }
    
    self.visitorsValueLabel.text = [NSString stringWithFormat:@"%ld", (long)self.trafficData.uniqueVisitors];
    self.requestsValueLabel.text = [NSString stringWithFormat:@"%ld", (long)self.trafficData.totalRequests];
    self.cachedValueLabel.text = [NSString stringWithFormat:@"%.1f%%", self.trafficData.cachedPercentage];
    self.dataServedValueLabel.text = [self.trafficData formattedDataServed];
    
    // Extract time series data from the GraphQL response
    NSArray *timeSeriesData = self.trafficData.timeSeriesData;
    
    NSArray *visitorsData = nil;
    NSArray *requestsData = nil;
    NSArray *cachedData = nil;
    NSArray *dataServedData = nil;
    
    for (NSDictionary *series in timeSeriesData) {
        NSString *type = series[@"type"];
        NSArray *data = series[@"data"];
        
        if ([type isEqualToString:@"uniques"]) {
            visitorsData = data;
        } else if ([type isEqualToString:@"requests"]) {
            requestsData = data;
        } else if ([type isEqualToString:@"cached"]) {
            cachedData = data;
        } else if ([type isEqualToString:@"bytes"]) {
            dataServedData = data;
        }
    }
    
    // Use extracted data or fallback to empty arrays
    self.visitorsChart.dataPoints = visitorsData ?: @[];
    self.requestsChart.dataPoints = requestsData ?: @[];
    self.cachedChart.dataPoints = cachedData ?: @[];
    self.dataServedChart.dataPoints = dataServedData ?: @[];
}

- (void)backButtonTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)periodChanged:(UISegmentedControl *)sender {
    self.selectedPeriod = (CFTimePeriod)sender.selectedSegmentIndex;
    [self loadData];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
