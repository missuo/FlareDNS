//
//  CFSimpleChartView.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFSimpleChartView.h"
#import "UIColor+FlareDNS.h"

@implementation CFSimpleChartView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.lineColor = [UIColor cf_chartBlueColor];
        self.fillColor = [UIColor cf_chartGradientStartColor];
        self.dataPoints = @[];
    }
    return self;
}

- (void)setDataPoints:(NSArray<NSNumber *> *)dataPoints {
    _dataPoints = dataPoints;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    if (self.dataPoints.count < 2) return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    CGFloat padding = 4;
    
    // Find min and max values
    CGFloat minValue = CGFLOAT_MAX;
    CGFloat maxValue = CGFLOAT_MIN;
    
    for (NSNumber *num in self.dataPoints) {
        CGFloat value = num.floatValue;
        if (value < minValue) minValue = value;
        if (value > maxValue) maxValue = value;
    }
    
    CGFloat range = maxValue - minValue;
    if (range == 0) range = 1;
    
    // Calculate points
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    CGFloat stepX = (width - padding * 2) / (self.dataPoints.count - 1);
    
    for (NSInteger i = 0; i < self.dataPoints.count; i++) {
        CGFloat value = self.dataPoints[i].floatValue;
        CGFloat normalizedValue = (value - minValue) / range;
        CGFloat x = padding + i * stepX;
        CGFloat y = height - padding - (normalizedValue * (height - padding * 2));
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    }
    
    // Draw gradient fill
    UIBezierPath *fillPath = [UIBezierPath bezierPath];
    [fillPath moveToPoint:CGPointMake(padding, height)];
    
    for (NSValue *pointValue in points) {
        [fillPath addLineToPoint:pointValue.CGPointValue];
    }
    
    [fillPath addLineToPoint:CGPointMake(width - padding, height)];
    [fillPath closePath];
    
    CGContextSaveGState(context);
    [fillPath addClip];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)[UIColor cf_chartGradientStartColor].CGColor,
                        (__bridge id)[UIColor cf_chartGradientEndColor].CGColor];
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(context);
    
    // Draw line
    UIBezierPath *linePath = [UIBezierPath bezierPath];
    [linePath moveToPoint:points.firstObject.CGPointValue];
    
    for (NSInteger i = 1; i < points.count; i++) {
        [linePath addLineToPoint:points[i].CGPointValue];
    }
    
    linePath.lineWidth = 2.0;
    [self.lineColor setStroke];
    [linePath stroke];
}

@end
