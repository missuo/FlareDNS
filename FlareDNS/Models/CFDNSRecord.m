//
//  CFDNSRecord.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFDNSRecord.h"

@implementation CFDNSRecord

+ (instancetype)recordFromDictionary:(NSDictionary *)dict {
    CFDNSRecord *record = [[CFDNSRecord alloc] init];
    record.recordID = dict[@"id"] ?: @"";
    record.zoneID = dict[@"zone_id"] ?: @"";
    record.zoneName = dict[@"zone_name"] ?: @"";
    record.name = dict[@"name"] ?: @"";
    record.type = [self typeFromString:dict[@"type"]];
    record.content = dict[@"content"] ?: @"";
    record.proxied = [dict[@"proxied"] boolValue];
    record.proxiable = [dict[@"proxiable"] boolValue];
    record.ttl = [dict[@"ttl"] integerValue];
    record.priority = [dict[@"priority"] integerValue];
    record.comment = dict[@"comment"];
    record.tags = dict[@"tags"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    NSString *createdStr = dict[@"created_on"];
    NSString *modifiedStr = dict[@"modified_on"];
    
    if (createdStr) {
        record.createdOn = [formatter dateFromString:createdStr];
    }
    if (modifiedStr) {
        record.modifiedOn = [formatter dateFromString:modifiedStr];
    }
    
    return record;
}

+ (NSString *)stringFromType:(CFDNSRecordType)type {
    switch (type) {
        case CFDNSRecordTypeA: return @"A";
        case CFDNSRecordTypeAAAA: return @"AAAA";
        case CFDNSRecordTypeCNAME: return @"CNAME";
        case CFDNSRecordTypeTXT: return @"TXT";
        case CFDNSRecordTypeMX: return @"MX";
        case CFDNSRecordTypeNS: return @"NS";
        case CFDNSRecordTypeSRV: return @"SRV";
        case CFDNSRecordTypeCAA: return @"CAA";
        case CFDNSRecordTypePTR: return @"PTR";
        case CFDNSRecordTypeHTTPS: return @"HTTPS";
        case CFDNSRecordTypeSVCB: return @"SVCB";
    }
}

+ (CFDNSRecordType)typeFromString:(NSString *)string {
    if ([string isEqualToString:@"A"]) return CFDNSRecordTypeA;
    if ([string isEqualToString:@"AAAA"]) return CFDNSRecordTypeAAAA;
    if ([string isEqualToString:@"CNAME"]) return CFDNSRecordTypeCNAME;
    if ([string isEqualToString:@"TXT"]) return CFDNSRecordTypeTXT;
    if ([string isEqualToString:@"MX"]) return CFDNSRecordTypeMX;
    if ([string isEqualToString:@"NS"]) return CFDNSRecordTypeNS;
    if ([string isEqualToString:@"SRV"]) return CFDNSRecordTypeSRV;
    if ([string isEqualToString:@"CAA"]) return CFDNSRecordTypeCAA;
    if ([string isEqualToString:@"PTR"]) return CFDNSRecordTypePTR;
    if ([string isEqualToString:@"HTTPS"]) return CFDNSRecordTypeHTTPS;
    if ([string isEqualToString:@"SVCB"]) return CFDNSRecordTypeSVCB;
    return CFDNSRecordTypeA;
}

+ (NSArray<NSString *> *)allRecordTypeStrings {
    return @[@"A", @"AAAA", @"CNAME", @"TXT", @"MX", @"NS", @"SRV", @"CAA", @"PTR", @"HTTPS", @"SVCB"];
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"type"] = [CFDNSRecord stringFromType:self.type];
    dict[@"name"] = self.name;
    dict[@"content"] = self.content;
    dict[@"ttl"] = @(self.ttl);
    dict[@"proxied"] = @(self.proxied);
    
    if (self.priority > 0) {
        dict[@"priority"] = @(self.priority);
    }
    if (self.comment) {
        dict[@"comment"] = self.comment;
    }
    
    return [dict copy];
}

@end
