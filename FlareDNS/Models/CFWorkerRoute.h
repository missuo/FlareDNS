//
//  CFWorkerRoute.h
//  FlareDNS
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFWorkerRoute : NSObject

@property (nonatomic, copy) NSString *routeID;
@property (nonatomic, copy) NSString *pattern;
@property (nonatomic, copy, nullable) NSString *scriptName;

+ (instancetype)routeFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
