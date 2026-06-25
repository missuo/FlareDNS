//
//  CFAPIService.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>
#import "CFZone.h"
#import "CFDNSRecord.h"
#import "CFTrafficData.h"
#import "CFAccount.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^CFAPICompletionBlock)(id _Nullable result, NSError * _Nullable error);

@interface CFAPIService : NSObject

@property (nonatomic, copy, nullable) NSString *email;
@property (nonatomic, copy, nullable) NSString *apiKey;
@property (nonatomic, assign) BOOL usesAPIToken;

+ (instancetype)shared;

// Authentication
- (void)configureWithAccount:(CFAccount *)account;
- (void)verifyCredentialsWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

// Zones
- (void)fetchZonesWithCompletion:(void (^)(NSArray<CFZone *> * _Nullable zones, NSError * _Nullable error))completion;
- (void)fetchZoneDetailsForZoneID:(NSString *)zoneID completion:(void (^)(CFZone * _Nullable zone, NSError * _Nullable error))completion;
- (void)addZoneWithName:(NSString *)name completion:(void (^)(CFZone * _Nullable zone, NSError * _Nullable error))completion;

// DNS Records
- (void)fetchDNSRecordsForZoneID:(NSString *)zoneID completion:(void (^)(NSArray<CFDNSRecord *> * _Nullable records, NSError * _Nullable error))completion;
- (void)createDNSRecord:(CFDNSRecord *)record forZoneID:(NSString *)zoneID completion:(void (^)(CFDNSRecord * _Nullable record, NSError * _Nullable error))completion;
- (void)updateDNSRecord:(CFDNSRecord *)record forZoneID:(NSString *)zoneID completion:(void (^)(CFDNSRecord * _Nullable record, NSError * _Nullable error))completion;
- (void)deleteDNSRecordWithID:(NSString *)recordID forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

// Zone Settings
- (void)fetchSSLModeForZoneID:(NSString *)zoneID completion:(void (^)(CFSSLMode mode, NSError * _Nullable error))completion;
- (void)setSSLMode:(CFSSLMode)mode forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)fetchSecurityLevelForZoneID:(NSString *)zoneID completion:(void (^)(CFSecurityLevel level, NSError * _Nullable error))completion;
- (void)setSecurityLevel:(CFSecurityLevel)level forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)fetchDevelopmentModeForZoneID:(NSString *)zoneID completion:(void (^)(BOOL enabled, NSError * _Nullable error))completion;
- (void)setDevelopmentMode:(BOOL)enabled forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)purgeCacheForZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)purgeCacheForZoneID:(NSString *)zoneID files:(NSArray<NSString *> *)files completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)fetchBrotliForZoneID:(NSString *)zoneID completion:(void (^)(BOOL enabled, NSError * _Nullable error))completion;
- (void)setBrotli:(BOOL)enabled forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)fetchAlwaysOnlineForZoneID:(NSString *)zoneID completion:(void (^)(BOOL enabled, NSError * _Nullable error))completion;
- (void)setAlwaysOnline:(BOOL)enabled forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)fetchCacheLevelForZoneID:(NSString *)zoneID completion:(void (^)(NSString * _Nullable value, NSError * _Nullable error))completion;
- (void)setCacheLevel:(NSString *)value forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)fetchBrowserCacheTTLForZoneID:(NSString *)zoneID completion:(void (^)(NSInteger seconds, NSError * _Nullable error))completion;
- (void)setBrowserCacheTTL:(NSInteger)seconds forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

// Analytics
- (void)fetchTrafficAnalyticsForZoneID:(NSString *)zoneID since:(NSDate *)since until:(NSDate *)until completion:(void (^)(CFTrafficData * _Nullable data, NSError * _Nullable error))completion;

// Registrar
// Returns registration/expiry dates for domains registered with Cloudflare Registrar.
// Domains registered with another registrar are not covered by this endpoint and will return an error.
- (void)fetchRegistrationForDomain:(NSString *)domainName accountID:(nullable NSString *)accountID completion:(void (^)(NSString * _Nullable registeredAt, NSString * _Nullable expiresAt, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
