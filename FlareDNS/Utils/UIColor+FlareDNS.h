//
//  UIColor+FlareDNS.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (FlareDNS)

// Background colors
+ (UIColor *)cf_primaryBackgroundColor;
+ (UIColor *)cf_secondaryBackgroundColor;
+ (UIColor *)cf_groupedBackgroundColor;

// Text colors
+ (UIColor *)cf_primaryTextColor;
+ (UIColor *)cf_secondaryTextColor;
+ (UIColor *)cf_tertiaryTextColor;

// Accent colors
+ (UIColor *)cf_accentColor;
+ (UIColor *)cf_orangeColor;
+ (UIColor *)cf_greenColor;
+ (UIColor *)cf_redColor;

// Chart colors
+ (UIColor *)cf_chartBlueColor;
+ (UIColor *)cf_chartGradientStartColor;
+ (UIColor *)cf_chartGradientEndColor;

@end

NS_ASSUME_NONNULL_END
