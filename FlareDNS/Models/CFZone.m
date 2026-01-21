//
//  CFZone.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFZone.h"

@implementation CFZone

+ (instancetype)zoneFromDictionary:(NSDictionary *)dict {
    CFZone *zone = [[CFZone alloc] init];
    zone.zoneID = dict[@"id"] ?: @"";
    zone.name = dict[@"name"] ?: @"";
    zone.nameServers = dict[@"name_servers"] ?: @[];
    zone.originalNameServers = dict[@"original_name_servers"];
    
    NSString *statusStr = dict[@"status"];
    if ([statusStr isEqualToString:@"active"]) {
        zone.status = CFZoneStatusActive;
    } else if ([statusStr isEqualToString:@"pending"]) {
        zone.status = CFZoneStatusPending;
    } else if ([statusStr isEqualToString:@"initializing"]) {
        zone.status = CFZoneStatusInitializing;
    } else if ([statusStr isEqualToString:@"moved"]) {
        zone.status = CFZoneStatusMoved;
    } else if ([statusStr isEqualToString:@"deleted"]) {
        zone.status = CFZoneStatusDeleted;
    } else if ([statusStr isEqualToString:@"deactivated"]) {
        zone.status = CFZoneStatusDeactivated;
    }
    
    NSDictionary *account = dict[@"account"];
    if (account) {
        zone.accountID = account[@"id"];
        zone.accountName = account[@"name"];
    }
    
    NSString *createdStr = dict[@"created_on"];
    NSString *modifiedStr = dict[@"modified_on"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    if (createdStr) {
        zone.createdOn = [formatter dateFromString:createdStr];
    }
    if (modifiedStr) {
        zone.modifiedOn = [formatter dateFromString:modifiedStr];
    }
    
    return zone;
}

+ (NSString *)stringFromStatus:(CFZoneStatus)status {
    switch (status) {
        case CFZoneStatusActive: return @"Active";
        case CFZoneStatusPending: return @"Pending";
        case CFZoneStatusInitializing: return @"Initializing";
        case CFZoneStatusMoved: return @"Moved";
        case CFZoneStatusDeleted: return @"Deleted";
        case CFZoneStatusDeactivated: return @"Deactivated";
    }
}

+ (NSString *)stringFromSSLMode:(CFSSLMode)mode {
    switch (mode) {
        case CFSSLModeOff: return @"Off (not secure)";
        case CFSSLModeFlexible: return @"Flexible";
        case CFSSLModeFull: return @"Full";
        case CFSSLModeFullStrict: return @"Full (strict)";
    }
}

+ (NSString *)stringFromSecurityLevel:(CFSecurityLevel)level {
    switch (level) {
        case CFSecurityLevelEssentiallyOff: return @"Essentially Off";
        case CFSecurityLevelLow: return @"Low";
        case CFSecurityLevelMedium: return @"Medium";
        case CFSecurityLevelHigh: return @"High";
        case CFSecurityLevelUnderAttack: return @"Under Attack";
    }
}

+ (CFSSLMode)sslModeFromString:(NSString *)string {
    if ([string isEqualToString:@"off"]) return CFSSLModeOff;
    if ([string isEqualToString:@"flexible"]) return CFSSLModeFlexible;
    if ([string isEqualToString:@"full"]) return CFSSLModeFull;
    if ([string isEqualToString:@"strict"]) return CFSSLModeFullStrict;
    return CFSSLModeFull;
}

+ (CFSecurityLevel)securityLevelFromString:(NSString *)string {
    if ([string isEqualToString:@"essentially_off"]) return CFSecurityLevelEssentiallyOff;
    if ([string isEqualToString:@"low"]) return CFSecurityLevelLow;
    if ([string isEqualToString:@"medium"]) return CFSecurityLevelMedium;
    if ([string isEqualToString:@"high"]) return CFSecurityLevelHigh;
    if ([string isEqualToString:@"under_attack"]) return CFSecurityLevelUnderAttack;
    return CFSecurityLevelMedium;
}

@end
