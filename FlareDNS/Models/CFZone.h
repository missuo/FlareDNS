//
//  CFZone.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CFZoneStatus) {
    CFZoneStatusActive,
    CFZoneStatusPending,
    CFZoneStatusInitializing,
    CFZoneStatusMoved,
    CFZoneStatusDeleted,
    CFZoneStatusDeactivated
};

typedef NS_ENUM(NSInteger, CFSSLMode) {
    CFSSLModeOff,
    CFSSLModeFlexible,
    CFSSLModeFull,
    CFSSLModeFullStrict
};

typedef NS_ENUM(NSInteger, CFSecurityLevel) {
    CFSecurityLevelEssentiallyOff,
    CFSecurityLevelLow,
    CFSecurityLevelMedium,
    CFSecurityLevelHigh,
    CFSecurityLevelUnderAttack
};

@interface CFZone : NSObject

@property (nonatomic, copy) NSString *zoneID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CFZoneStatus status;
@property (nonatomic, copy) NSArray<NSString *> *nameServers;
@property (nonatomic, copy, nullable) NSString *originalNameServers;
@property (nonatomic, assign) CFSSLMode sslMode;
@property (nonatomic, assign) CFSecurityLevel securityLevel;
@property (nonatomic, assign) BOOL developmentMode;
@property (nonatomic, copy, nullable) NSDate *createdOn;
@property (nonatomic, copy, nullable) NSDate *modifiedOn;
@property (nonatomic, copy, nullable) NSString *accountID;
@property (nonatomic, copy, nullable) NSString *accountName;

+ (instancetype)zoneFromDictionary:(NSDictionary *)dict;
+ (NSString *)stringFromStatus:(CFZoneStatus)status;
+ (NSString *)stringFromSSLMode:(CFSSLMode)mode;
+ (NSString *)stringFromSecurityLevel:(CFSecurityLevel)level;
+ (CFSSLMode)sslModeFromString:(NSString *)string;
+ (CFSecurityLevel)securityLevelFromString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
