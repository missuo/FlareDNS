//
//  CFWorkerScript.m
//  FlareDNS
//

#import "CFWorkerScript.h"

@implementation CFWorkerScript

+ (instancetype)scriptFromDictionary:(NSDictionary *)dict {
    CFWorkerScript *script = [[CFWorkerScript alloc] init];
    NSString *name = dict[@"id"] ?: dict[@"script_name"] ?: dict[@"name"] ?: @"";
    script.scriptID = name;
    script.name = name;
    script.createdOn = [dict[@"created_on"] isKindOfClass:[NSString class]] ? dict[@"created_on"] : nil;
    script.modifiedOn = [dict[@"modified_on"] isKindOfClass:[NSString class]] ? dict[@"modified_on"] : nil;
    return script;
}

@end
