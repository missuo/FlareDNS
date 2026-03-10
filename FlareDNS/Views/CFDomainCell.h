//
//  CFDomainCell.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFZone.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CFSimpleChartView;

@interface CFDomainCell : UITableViewCell

@property(nonatomic, strong, readonly) UIImageView *globeImageView;
@property(nonatomic, strong, readonly) UILabel *domainLabel;
@property(nonatomic, strong, readonly) CFSimpleChartView *chartView;

- (void)configureWithZone:(CFZone *)zone;
- (void)configureChartWithDataPoints:(nullable NSArray<NSNumber *> *)dataPoints
                               value:(NSString *_Nullable)value;

@end

NS_ASSUME_NONNULL_END
