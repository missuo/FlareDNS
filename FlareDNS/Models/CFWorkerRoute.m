//
//  CFWorkerRoute.m
//  FlareDNS
//

#import "CFWorkerRoute.h"

@implementation CFWorkerRoute

+ (instancetype)routeFromDictionary:(NSDictionary *)dict {
    CFWorkerRoute *route = [[CFWorkerRoute alloc] init];
    route.routeID = dict[@"id"] ?: @"";
    route.pattern = dict[@"pattern"] ?: @"";
    route.scriptName = [dict[@"script"] isKindOfClass:[NSString class]] ? dict[@"script"] : nil;
    return route;
}

@end
