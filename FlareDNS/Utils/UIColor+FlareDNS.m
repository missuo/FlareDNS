//
//  UIColor+FlareDNS.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "UIColor+FlareDNS.h"

@implementation UIColor (FlareDNS)

+ (UIColor *)cf_primaryBackgroundColor {
    return [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0];
}

+ (UIColor *)cf_secondaryBackgroundColor {
    // Slightly lighter for better contrast with dark background
    return [UIColor colorWithRed:0.15 green:0.15 blue:0.16 alpha:1.0];
}

+ (UIColor *)cf_groupedBackgroundColor {
    return [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0];
}

+ (UIColor *)cf_primaryTextColor {
    return [UIColor whiteColor];
}

+ (UIColor *)cf_secondaryTextColor {
    return [UIColor colorWithRed:0.56 green:0.56 blue:0.58 alpha:1.0];
}

+ (UIColor *)cf_tertiaryTextColor {
    return [UIColor colorWithRed:0.40 green:0.40 blue:0.42 alpha:1.0];
}

+ (UIColor *)cf_accentColor {
    return [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
}

+ (UIColor *)cf_orangeColor {
    return [UIColor colorWithRed:0.96 green:0.65 blue:0.14 alpha:1.0];
}

+ (UIColor *)cf_greenColor {
    return [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0];
}

+ (UIColor *)cf_redColor {
    return [UIColor colorWithRed:1.0 green:0.27 blue:0.23 alpha:1.0];
}

+ (UIColor *)cf_chartBlueColor {
    return [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
}

+ (UIColor *)cf_chartGradientStartColor {
    return [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.3];
}

+ (UIColor *)cf_chartGradientEndColor {
    return [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.0];
}

@end
