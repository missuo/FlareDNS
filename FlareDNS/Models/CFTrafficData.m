//
//  CFTrafficData.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFTrafficData.h"

@implementation CFTrafficData

+ (instancetype)trafficDataFromDictionary:(NSDictionary *)dict {
    CFTrafficData *data = [[CFTrafficData alloc] init];
    
    NSDictionary *totals = dict[@"totals"];
    if (totals) {
        data.uniqueVisitors = [totals[@"uniques"][@"all"] integerValue];
        data.totalRequests = [totals[@"requests"][@"all"] integerValue];
        
        NSInteger cachedRequests = [totals[@"requests"][@"cached"] integerValue];
        if (data.totalRequests > 0) {
            data.cachedPercentage = (double)cachedRequests / (double)data.totalRequests * 100.0;
        }
        
        data.totalDataServed = [totals[@"bandwidth"][@"all"] integerValue];
    }
    
    data.timeSeriesData = dict[@"timeseries"];
    
    return data;
}

// Helper to safely get integer value from potentially null objects
static NSInteger safeIntegerValue(id obj) {
    if (obj == nil || obj == [NSNull null]) {
        return 0;
    }
    if ([obj respondsToSelector:@selector(integerValue)]) {
        return [obj integerValue];
    }
    return 0;
}

+ (instancetype)trafficDataFromGraphQLResponse:(NSArray *)httpRequestGroups {
    CFTrafficData *data = [[CFTrafficData alloc] init];
    
    // Handle nil or empty array
    if (!httpRequestGroups || ![httpRequestGroups isKindOfClass:[NSArray class]] || httpRequestGroups.count == 0) {
        data.totalRequests = 0;
        data.uniqueVisitors = 0;
        data.totalDataServed = 0;
        data.cachedPercentage = 0;
        data.timeSeriesData = @[
            @{@"type": @"requests", @"data": @[]},
            @{@"type": @"cached", @"data": @[]},
            @{@"type": @"bytes", @"data": @[]},
            @{@"type": @"uniques", @"data": @[]}
        ];
        return data;
    }
    
    NSInteger totalRequests = 0;
    NSInteger totalCachedRequests = 0;
    NSInteger totalBytes = 0;
    NSInteger totalUniques = 0;
    
    NSMutableArray *timeSeriesRequests = [NSMutableArray array];
    NSMutableArray *timeSeriesCached = [NSMutableArray array];
    NSMutableArray *timeSeriesBytes = [NSMutableArray array];
    NSMutableArray *timeSeriesUniques = [NSMutableArray array];
    
    for (id groupObj in httpRequestGroups) {
        // Skip if group is not a dictionary
        if (![groupObj isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *group = (NSDictionary *)groupObj;
        
        id sumDataObj = group[@"sum"];
        id uniqDataObj = group[@"uniq"];
        
        NSDictionary *sumData = (sumDataObj && [sumDataObj isKindOfClass:[NSDictionary class]]) ? sumDataObj : @{};
        NSDictionary *uniqData = (uniqDataObj && [uniqDataObj isKindOfClass:[NSDictionary class]]) ? uniqDataObj : @{};
        
        NSInteger requests = safeIntegerValue(sumData[@"requests"]);
        NSInteger cachedRequests = safeIntegerValue(sumData[@"cachedRequests"]);
        NSInteger bytes = safeIntegerValue(sumData[@"bytes"]);
        NSInteger uniques = safeIntegerValue(uniqData[@"uniques"]);
        
        totalRequests += requests;
        totalCachedRequests += cachedRequests;
        totalBytes += bytes;
        totalUniques += uniques;
        
        [timeSeriesRequests addObject:@(requests)];
        [timeSeriesCached addObject:@(cachedRequests)];
        [timeSeriesBytes addObject:@(bytes)];
        [timeSeriesUniques addObject:@(uniques)];
    }
    
    data.totalRequests = totalRequests;
    data.uniqueVisitors = totalUniques;
    data.totalDataServed = totalBytes;
    
    if (totalRequests > 0) {
        data.cachedPercentage = (double)totalCachedRequests / (double)totalRequests * 100.0;
    }
    
    // Store time series data for charts
    data.timeSeriesData = @[
        @{@"type": @"requests", @"data": timeSeriesRequests},
        @{@"type": @"cached", @"data": timeSeriesCached},
        @{@"type": @"bytes", @"data": timeSeriesBytes},
        @{@"type": @"uniques", @"data": timeSeriesUniques}
    ];
    
    return data;
}

- (NSString *)formattedDataServed {
    if (self.totalDataServed < 1024) {
        return [NSString stringWithFormat:@"%ld B", (long)self.totalDataServed];
    } else if (self.totalDataServed < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f KB", self.totalDataServed / 1024.0];
    } else if (self.totalDataServed < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.2f MB", self.totalDataServed / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", self.totalDataServed / (1024.0 * 1024.0 * 1024.0)];
    }
}

@end
