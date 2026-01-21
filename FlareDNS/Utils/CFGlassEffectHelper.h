//
//  CFGlassEffectHelper.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFGlassEffectHelper : NSObject

/// Creates a glass effect view (Liquid Glass on iOS 26+, blur on older versions)
+ (UIVisualEffectView *)glassEffectViewWithTintColor:(nullable UIColor *)tintColor;

/// Creates a glass effect view with custom corner radius
+ (UIVisualEffectView *)glassEffectViewWithTintColor:(nullable UIColor *)tintColor cornerRadius:(CGFloat)cornerRadius;

/// Checks if Liquid Glass is available
+ (BOOL)isLiquidGlassAvailable;

/// Applies glass background to a view
+ (void)applyGlassBackgroundToView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
