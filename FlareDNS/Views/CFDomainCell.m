//
//  CFDomainCell.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFDomainCell.h"
#import "CFSimpleChartView.h"
#import "UIColor+FlareDNS.h"

@interface CFDomainCell ()

@property(nonatomic, strong, readwrite) UIImageView *globeImageView;
@property(nonatomic, strong, readwrite) UILabel *domainLabel;
@property(nonatomic, strong, readwrite) CFSimpleChartView *chartView;
@property(nonatomic, strong) UILabel *chartValueLabel;

@end

@implementation CFDomainCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  // Adapt colors based on iOS version
  if (@available(iOS 26.0, *)) {
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  } else {
    self.backgroundColor = [UIColor cf_secondaryBackgroundColor];
  }

  self.selectionStyle = UITableViewCellSelectionStyleDefault;
  self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

  // Globe icon
  self.globeImageView = [[UIImageView alloc] init];
  self.globeImageView.translatesAutoresizingMaskIntoConstraints = NO;
  self.globeImageView.image = [UIImage systemImageNamed:@"globe"];
  self.globeImageView.tintColor = [UIColor systemBlueColor];
  self.globeImageView.contentMode = UIViewContentModeScaleAspectFit;
  [self.contentView addSubview:self.globeImageView];

  // Domain label
  self.domainLabel = [[UILabel alloc] init];
  self.domainLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.domainLabel.font = [UIFont systemFontOfSize:17];
  if (@available(iOS 26.0, *)) {
    self.domainLabel.textColor = [UIColor labelColor];
  } else {
    self.domainLabel.textColor = [UIColor cf_primaryTextColor];
  }
  [self.contentView addSubview:self.domainLabel];

  // Chart value label — right side
  self.chartValueLabel = [[UILabel alloc] init];
  self.chartValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.chartValueLabel.font =
      [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
  self.chartValueLabel.textColor = [UIColor secondaryLabelColor];
  self.chartValueLabel.textAlignment = NSTextAlignmentRight;
  self.chartValueLabel.text = @"";
  [self.contentView addSubview:self.chartValueLabel];

  // Sparkline chart — compact, right side of the cell
  self.chartView = [[CFSimpleChartView alloc] init];
  self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
  self.chartView.dataPoints = @[];
  [self.contentView addSubview:self.chartView];

  [NSLayoutConstraint activateConstraints:@[
    [self.globeImageView.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor
                       constant:16],
    [self.globeImageView.centerYAnchor
        constraintEqualToAnchor:self.contentView.centerYAnchor],
    [self.globeImageView.widthAnchor constraintEqualToConstant:28],
    [self.globeImageView.heightAnchor constraintEqualToConstant:28],

    // Chart value label — right edge, fixed width
    [self.chartValueLabel.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:-8],
    [self.chartValueLabel.centerYAnchor
        constraintEqualToAnchor:self.contentView.centerYAnchor],
    [self.chartValueLabel.widthAnchor constraintEqualToConstant:36],

    // Sparkline chart — to the left of the value label with 0 spacing
    [self.chartView.trailingAnchor
        constraintEqualToAnchor:self.chartValueLabel.leadingAnchor
                       constant:0],
    [self.chartView.centerYAnchor
        constraintEqualToAnchor:self.contentView.centerYAnchor],
    [self.chartView.widthAnchor constraintEqualToConstant:80],
    [self.chartView.heightAnchor constraintEqualToConstant:32],

    [self.domainLabel.leadingAnchor
        constraintEqualToAnchor:self.globeImageView.trailingAnchor
                       constant:14],
    [self.domainLabel.centerYAnchor
        constraintEqualToAnchor:self.contentView.centerYAnchor],
    [self.domainLabel.trailingAnchor
        constraintLessThanOrEqualToAnchor:self.chartView.leadingAnchor
                                 constant:-8]
  ]];
}

- (void)configureWithZone:(CFZone *)zone {
  self.domainLabel.text = zone.name;
  // Reset chart until data loads
  self.chartView.dataPoints = @[];
  self.chartValueLabel.text = @"";
}

- (void)configureChartWithDataPoints:(NSArray<NSNumber *> *)dataPoints
                               value:(NSString *)value {
  self.chartView.dataPoints = dataPoints ?: @[];
  self.chartValueLabel.text = value ?: @"";
}

@end
