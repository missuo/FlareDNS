//
//  CFKVNamespace.m
//  FlareDNS
//

#import "CFKVNamespace.h"

@implementation CFKVNamespace

+ (instancetype)namespaceFromDictionary:(NSDictionary *)dict {
    CFKVNamespace *namespace = [[CFKVNamespace alloc] init];
    namespace.namespaceID = dict[@"id"] ?: @"";
    namespace.title = dict[@"title"] ?: @"";
    return namespace;
}

@end
