//
//  CFTrafficData.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFTrafficData : NSObject

@property (nonatomic, assign) NSInteger uniqueVisitors;
@property (nonatomic, assign) NSInteger totalRequests;
@property (nonatomic, assign) double cachedPercentage;
@property (nonatomic, assign) NSInteger totalDataServed;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *timeSeriesData;
@property (nonatomic, copy, nullable) NSDate *since;
@property (nonatomic, copy, nullable) NSDate *until;

+ (instancetype)trafficDataFromDictionary:(NSDictionary *)dict;
+ (instancetype)trafficDataFromGraphQLResponse:(NSArray *)httpRequestGroups;
- (NSString *)formattedDataServed;

@end

NS_ASSUME_NONNULL_END
