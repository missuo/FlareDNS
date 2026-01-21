//
//  CFGlassEffectHelper.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFGlassEffectHelper.h"
#import "UIColor+FlareDNS.h"

@implementation CFGlassEffectHelper

+ (BOOL)isLiquidGlassAvailable {
    if (@available(iOS 26.0, *)) {
        return YES;
    }
    return NO;
}

+ (UIVisualEffectView *)glassEffectViewWithTintColor:(nullable UIColor *)tintColor {
    return [self glassEffectViewWithTintColor:tintColor cornerRadius:12.0];
}

+ (UIVisualEffectView *)glassEffectViewWithTintColor:(nullable UIColor *)tintColor cornerRadius:(CGFloat)cornerRadius {
    UIVisualEffectView *effectView;
    
    if (@available(iOS 26.0, *)) {
        // Use Liquid Glass on iOS 26+
        UIGlassEffect *glassEffect = [[UIGlassEffect alloc] init];
        if (tintColor) {
            glassEffect.tintColor = tintColor;
        }
        effectView = [[UIVisualEffectView alloc] initWithEffect:glassEffect];
        // Use layer corner radius as fallback - Liquid Glass handles its own corners
        effectView.layer.cornerRadius = cornerRadius;
        effectView.layer.masksToBounds = YES;
    } else {
        // Fallback to blur effect for older iOS versions
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
        effectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        effectView.layer.cornerRadius = cornerRadius;
        effectView.layer.masksToBounds = YES;
    }
    
    return effectView;
}

+ (void)applyGlassBackgroundToView:(UIView *)view {
    // Remove any existing glass background
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
            [subview removeFromSuperview];
            break;
        }
    }
    
    UIVisualEffectView *glassView = [self glassEffectViewWithTintColor:nil cornerRadius:0];
    glassView.tag = 999;
    glassView.translatesAutoresizingMaskIntoConstraints = NO;
    [view insertSubview:glassView atIndex:0];
    
    [NSLayoutConstraint activateConstraints:@[
        [glassView.topAnchor constraintEqualToAnchor:view.topAnchor],
        [glassView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [glassView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [glassView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];
}

@end
