//
//  CFSimpleChartView.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFSimpleChartView : UIView

@property (nonatomic, strong) UIColor *lineColor;
@property (nonatomic, strong) UIColor *fillColor;
@property (nonatomic, strong) NSArray<NSNumber *> *dataPoints;

@end

NS_ASSUME_NONNULL_END
