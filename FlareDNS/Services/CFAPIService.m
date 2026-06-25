//
//  CFAPIService.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFAPIService.h"
#import <UIKit/UIKit.h>

static NSString *const kBaseURL = @"https://api.cloudflare.com/client/v4";

@interface CFAPIService ()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation CFAPIService

+ (instancetype)shared {
    static CFAPIService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CFAPIService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

#pragma mark - Private Methods

- (NSMutableURLRequest *)requestWithPath:(NSString *)path method:(NSString *)method {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kBaseURL, path]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (self.usesAPIToken) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey ?: @""] forHTTPHeaderField:@"Authorization"];
    } else {
        [request setValue:self.email forHTTPHeaderField:@"X-Auth-Email"];
        [request setValue:self.apiKey forHTTPHeaderField:@"X-Auth-Key"];
    }
    
    return request;
}

- (void)performRequest:(NSURLRequest *)request completion:(CFAPICompletionBlock)completion {
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            // Check if error is due to app entering background
            // NSURLErrorCancelled (-999) or NSURLErrorNetworkConnectionLost (-1005)
            NSInteger errorCode = error.code;
            BOOL isBackgroundError = (errorCode == NSURLErrorCancelled || 
                                      errorCode == NSURLErrorNetworkConnectionLost ||
                                      errorCode == NSURLErrorTimedOut);
            
            // Check if app is in background
            UIApplicationState appState = [UIApplication sharedApplication].applicationState;
            BOOL isInBackground = (appState == UIApplicationStateBackground || appState == UIApplicationStateInactive);
            
            // If error is due to app entering background, silently ignore it
            if (isBackgroundError && isInBackground) {
                // Silently ignore - don't call completion to avoid showing error
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if (data) {
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            if (jsonError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, jsonError);
                });
                return;
            }
            
            BOOL success = [json[@"success"] boolValue];
            if (!success) {
                NSArray *errors = json[@"errors"];
                NSString *errorMessage = @"Unknown error";
                if (errors.count > 0) {
                    errorMessage = errors[0][@"message"] ?: errorMessage;
                }
                NSError *apiError = [NSError errorWithDomain:@"CFAPIService"
                                                       code:httpResponse.statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, apiError);
                });
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(json[@"result"], nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, nil);
            });
        }
    }];
    
    [task resume];
}

#pragma mark - Authentication

- (void)configureWithAccount:(CFAccount *)account {
    self.email = account.email;
    self.apiKey = account.apiKey;
    self.usesAPIToken = [account usesAPIToken];
}

- (void)verifyCredentialsWithCompletion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSMutableURLRequest *request = [self requestWithPath:@"/zones?per_page=1" method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(NO, error);
        } else {
            completion(YES, nil);
        }
    }];
}

#pragma mark - Zones

- (void)fetchZonesWithCompletion:(void (^)(NSArray<CFZone *> * _Nullable, NSError * _Nullable))completion {
    NSMutableURLRequest *request = [self requestWithPath:@"/zones?per_page=50" method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSMutableArray<CFZone *> *zones = [NSMutableArray array];
        for (NSDictionary *dict in result) {
            [zones addObject:[CFZone zoneFromDictionary:dict]];
        }
        
        completion(zones, nil);
    }];
}

- (void)fetchZoneDetailsForZoneID:(NSString *)zoneID completion:(void (^)(CFZone * _Nullable, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        completion([CFZone zoneFromDictionary:result], nil);
    }];
}

- (void)addZoneWithName:(NSString *)name completion:(void (^)(CFZone * _Nullable, NSError * _Nullable))completion {
    NSMutableURLRequest *request = [self requestWithPath:@"/zones" method:@"POST"];
    
    NSDictionary *body = @{
        @"name": name,
        @"jump_start": @YES
    };
    
    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        completion([CFZone zoneFromDictionary:result], nil);
    }];
}

#pragma mark - DNS Records

- (void)fetchDNSRecordsForZoneID:(NSString *)zoneID completion:(void (^)(NSArray<CFDNSRecord *> * _Nullable, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/dns_records?per_page=100", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSMutableArray<CFDNSRecord *> *records = [NSMutableArray array];
        for (NSDictionary *dict in result) {
            [records addObject:[CFDNSRecord recordFromDictionary:dict]];
        }
        
        completion(records, nil);
    }];
}

- (void)createDNSRecord:(CFDNSRecord *)record forZoneID:(NSString *)zoneID completion:(void (^)(CFDNSRecord * _Nullable, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/dns_records", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST"];
    
    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:[record toDictionary] options:0 error:&jsonError];
    
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        completion([CFDNSRecord recordFromDictionary:result], nil);
    }];
}

- (void)updateDNSRecord:(CFDNSRecord *)record forZoneID:(NSString *)zoneID completion:(void (^)(CFDNSRecord * _Nullable, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/dns_records/%@", zoneID, record.recordID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PATCH"];
    
    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:[record toDictionary] options:0 error:&jsonError];
    
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        completion([CFDNSRecord recordFromDictionary:result], nil);
    }];
}

- (void)deleteDNSRecordWithID:(NSString *)recordID forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/dns_records/%@", zoneID, recordID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"DELETE"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(NO, error);
        } else {
            completion(YES, nil);
        }
    }];
}

#pragma mark - Zone Settings

- (void)fetchSSLModeForZoneID:(NSString *)zoneID completion:(void (^)(CFSSLMode, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/ssl", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(CFSSLModeFull, error);
            return;
        }
        
        NSString *value = result[@"value"];
        completion([CFZone sslModeFromString:value], nil);
    }];
}

- (void)setSSLMode:(CFSSLMode)mode forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/ssl", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PATCH"];
    
    NSString *value;
    switch (mode) {
        case CFSSLModeOff: value = @"off"; break;
        case CFSSLModeFlexible: value = @"flexible"; break;
        case CFSSLModeFull: value = @"full"; break;
        case CFSSLModeFullStrict: value = @"strict"; break;
    }
    
    NSDictionary *body = @{@"value": value};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)fetchSecurityLevelForZoneID:(NSString *)zoneID completion:(void (^)(CFSecurityLevel, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/security_level", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(CFSecurityLevelMedium, error);
            return;
        }
        
        NSString *value = result[@"value"];
        completion([CFZone securityLevelFromString:value], nil);
    }];
}

- (void)setSecurityLevel:(CFSecurityLevel)level forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/security_level", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PATCH"];
    
    NSString *value;
    switch (level) {
        case CFSecurityLevelEssentiallyOff: value = @"essentially_off"; break;
        case CFSecurityLevelLow: value = @"low"; break;
        case CFSecurityLevelMedium: value = @"medium"; break;
        case CFSecurityLevelHigh: value = @"high"; break;
        case CFSecurityLevelUnderAttack: value = @"under_attack"; break;
    }
    
    NSDictionary *body = @{@"value": value};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)fetchDevelopmentModeForZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/development_mode", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(NO, error);
            return;
        }
        
        NSString *value = result[@"value"];
        completion([value isEqualToString:@"on"], nil);
    }];
}

- (void)setDevelopmentMode:(BOOL)enabled forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/development_mode", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PATCH"];
    
    NSDictionary *body = @{@"value": enabled ? @"on" : @"off"};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)purgeCacheForZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/purge_cache", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST"];
    
    NSDictionary *body = @{@"purge_everything": @YES};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    [self performRequest:request completion:^(id result, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)purgeCacheForZoneID:(NSString *)zoneID files:(NSArray<NSString *> *)files completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/purge_cache", zoneID];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"POST"];
    NSDictionary *body = @{@"files": files};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [self performRequest:request completion:^(id result, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)fetchZoneSetting:(NSString *)setting forZoneID:(NSString *)zoneID completion:(void (^)(id _Nullable value, NSError * _Nullable error))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/%@", zoneID, setting];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];

    [self performRequest:request completion:^(id result, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        completion([result isKindOfClass:[NSDictionary class]] ? result[@"value"] : nil, nil);
    }];
}

- (void)setZoneSetting:(NSString *)setting value:(id)value forZoneID:(NSString *)zoneID completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    NSString *path = [NSString stringWithFormat:@"/zones/%@/settings/%@", zoneID, setting];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"PATCH"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"value": value} options:0 error:nil];

    [self performRequest:request completion:^(id result, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)fetchBrotliForZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self fetchZoneSetting:@"brotli" forZoneID:zoneID completion:^(id value, NSError *error) {
        completion([value isKindOfClass:[NSString class]] && [value isEqualToString:@"on"], error);
    }];
}

- (void)setBrotli:(BOOL)enabled forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self setZoneSetting:@"brotli" value:(enabled ? @"on" : @"off") forZoneID:zoneID completion:completion];
}

- (void)fetchAlwaysOnlineForZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self fetchZoneSetting:@"always_online" forZoneID:zoneID completion:^(id value, NSError *error) {
        completion([value isKindOfClass:[NSString class]] && [value isEqualToString:@"on"], error);
    }];
}

- (void)setAlwaysOnline:(BOOL)enabled forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self setZoneSetting:@"always_online" value:(enabled ? @"on" : @"off") forZoneID:zoneID completion:completion];
}

- (void)fetchCacheLevelForZoneID:(NSString *)zoneID completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    [self fetchZoneSetting:@"cache_level" forZoneID:zoneID completion:^(id value, NSError *error) {
        completion([value isKindOfClass:[NSString class]] ? value : nil, error);
    }];
}

- (void)setCacheLevel:(NSString *)value forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self setZoneSetting:@"cache_level" value:value forZoneID:zoneID completion:completion];
}

- (void)fetchBrowserCacheTTLForZoneID:(NSString *)zoneID completion:(void (^)(NSInteger, NSError * _Nullable))completion {
    [self fetchZoneSetting:@"browser_cache_ttl" forZoneID:zoneID completion:^(id value, NSError *error) {
        completion([value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0, error);
    }];
}

- (void)setBrowserCacheTTL:(NSInteger)seconds forZoneID:(NSString *)zoneID completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [self setZoneSetting:@"browser_cache_ttl" value:@(seconds) forZoneID:zoneID completion:completion];
}

#pragma mark - Analytics (GraphQL)

- (void)fetchTrafficAnalyticsForZoneID:(NSString *)zoneID since:(NSDate *)since until:(NSDate *)until completion:(void (^)(CFTrafficData * _Nullable, NSError * _Nullable))completion {
    // Calculate time range in seconds
    NSTimeInterval timeRange = [until timeIntervalSinceDate:since];
    
    // Max time range for hourly data is ~3 days (259200 seconds)
    // Use daily aggregation for longer periods
    BOOL useDailyAggregation = timeRange > 259200;
    
    NSString *query;
    NSDictionary *variables;
    
    if (useDailyAggregation) {
        // Use date format for daily aggregation
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.dateFormat = @"yyyy-MM-dd";
        dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        
        NSString *sinceStr = [dateFormatter stringFromDate:since];
        NSString *untilStr = [dateFormatter stringFromDate:until];
        
        // GraphQL query for daily zone analytics
        query = @"query ZoneAnalyticsDaily($zoneTag: String!, $since: Date!, $until: Date!) {"
                 "  viewer {"
                 "    zones(filter: { zoneTag: $zoneTag }) {"
                 "      httpRequests1dGroups(filter: { date_geq: $since, date_lt: $until }, orderBy: [date_ASC], limit: 1000) {"
                 "        dimensions {"
                 "          date"
                 "        }"
                 "        sum {"
                 "          requests"
                 "          cachedRequests"
                 "          bytes"
                 "          cachedBytes"
                 "        }"
                 "        uniq {"
                 "          uniques"
                 "        }"
                 "      }"
                 "    }"
                 "  }"
                 "}";
        
        variables = @{
            @"zoneTag": zoneID,
            @"since": sinceStr,
            @"until": untilStr
        };
    } else {
        // Use datetime format for hourly aggregation
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        
        NSString *sinceStr = [formatter stringFromDate:since];
        NSString *untilStr = [formatter stringFromDate:until];
        
        // GraphQL query for hourly zone analytics
        query = @"query ZoneAnalyticsHourly($zoneTag: String!, $since: Time!, $until: Time!) {"
                 "  viewer {"
                 "    zones(filter: { zoneTag: $zoneTag }) {"
                 "      httpRequests1hGroups(filter: { datetime_geq: $since, datetime_lt: $until }, orderBy: [datetime_ASC], limit: 1000) {"
                 "        dimensions {"
                 "          datetime"
                 "        }"
                 "        sum {"
                 "          requests"
                 "          cachedRequests"
                 "          bytes"
                 "          cachedBytes"
                 "        }"
                 "        uniq {"
                 "          uniques"
                 "        }"
                 "      }"
                 "    }"
                 "  }"
                 "}";
        
        variables = @{
            @"zoneTag": zoneID,
            @"since": sinceStr,
            @"until": untilStr
        };
    }
    
    NSDictionary *body = @{
        @"query": query,
        @"variables": variables
    };
    
    NSURL *url = [NSURL URLWithString:@"https://api.cloudflare.com/client/v4/graphql"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (self.usesAPIToken) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey ?: @""] forHTTPHeaderField:@"Authorization"];
    } else {
        [request setValue:self.email forHTTPHeaderField:@"X-Auth-Email"];
        [request setValue:self.apiKey forHTTPHeaderField:@"X-Auth-Key"];
    }
    
    NSError *jsonError;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    
    if (jsonError) {
        completion(nil, jsonError);
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            // Check if error is due to app entering background
            NSInteger errorCode = error.code;
            BOOL isBackgroundError = (errorCode == NSURLErrorCancelled || 
                                      errorCode == NSURLErrorNetworkConnectionLost ||
                                      errorCode == NSURLErrorTimedOut);
            
            // Check if app is in background
            UIApplicationState appState = [UIApplication sharedApplication].applicationState;
            BOOL isInBackground = (appState == UIApplicationStateBackground || appState == UIApplicationStateInactive);
            
            // If error is due to app entering background, silently ignore it
            if (isBackgroundError && isInBackground) {
                // Silently ignore - don't call completion to avoid showing error
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSError *parseError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            
            if (parseError) {
                completion(nil, parseError);
                return;
            }
            
            // Check for GraphQL errors
            id errorsObj = json[@"errors"];
            if (errorsObj && errorsObj != [NSNull null] && [errorsObj isKindOfClass:[NSArray class]] && [(NSArray *)errorsObj count] > 0) {
                NSString *errorMessage = errorsObj[0][@"message"] ?: @"GraphQL error";
                NSError *graphqlError = [NSError errorWithDomain:@"CFAPIServiceError" code:1001 userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
                completion(nil, graphqlError);
                return;
            }
            
            // Parse the GraphQL response with null checks
            id dataObj = json[@"data"];
            if (!dataObj || dataObj == [NSNull null] || ![dataObj isKindOfClass:[NSDictionary class]]) {
                completion(nil, [NSError errorWithDomain:@"CFAPIServiceError" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response format"}]);
                return;
            }
            
            id viewerObj = dataObj[@"viewer"];
            if (!viewerObj || viewerObj == [NSNull null] || ![viewerObj isKindOfClass:[NSDictionary class]]) {
                completion(nil, [NSError errorWithDomain:@"CFAPIServiceError" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"No viewer data returned"}]);
                return;
            }
            
            id zonesObj = viewerObj[@"zones"];
            if (!zonesObj || zonesObj == [NSNull null] || ![zonesObj isKindOfClass:[NSArray class]] || [(NSArray *)zonesObj count] == 0) {
                completion(nil, [NSError errorWithDomain:@"CFAPIServiceError" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"No zone data returned"}]);
                return;
            }
            
            NSArray *zones = (NSArray *)zonesObj;
            NSDictionary *zoneData = zones[0];
            
            // Try hourly data first, then daily data
            id httpRequestGroupsObj = zoneData[@"httpRequests1hGroups"];
            if (!httpRequestGroupsObj || httpRequestGroupsObj == [NSNull null]) {
                httpRequestGroupsObj = zoneData[@"httpRequests1dGroups"];
            }
            
            // Handle null or missing httpRequestGroups
            NSArray *httpRequestGroups = nil;
            if (httpRequestGroupsObj && httpRequestGroupsObj != [NSNull null] && [httpRequestGroupsObj isKindOfClass:[NSArray class]]) {
                httpRequestGroups = (NSArray *)httpRequestGroupsObj;
            } else {
                httpRequestGroups = @[]; // Empty array if no data
            }
            
            CFTrafficData *trafficData = [CFTrafficData trafficDataFromGraphQLResponse:httpRequestGroups];
            completion(trafficData, nil);
        });
    }];

    [task resume];
}

#pragma mark - Registrar

- (void)fetchRegistrationForDomain:(NSString *)domainName accountID:(nullable NSString *)accountID completion:(void (^)(NSString * _Nullable, NSString * _Nullable, NSError * _Nullable))completion {
    if (accountID.length == 0 || domainName.length == 0) {
        NSError *error = [NSError errorWithDomain:@"CFAPIService"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Missing account or domain"}];
        completion(nil, nil, error);
        return;
    }

    NSString *encodedDomain = [domainName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
    NSString *path = [NSString stringWithFormat:@"/accounts/%@/registrar/domains/%@", accountID, encodedDomain];
    NSMutableURLRequest *request = [self requestWithPath:path method:@"GET"];

    // Domains registered outside Cloudflare return an API error here, which we surface as
    // "no registration data" so the UI can mark them unsupported. The domain name is only ever
    // sent to Cloudflare's own API, never to any third party.
    [self performRequest:request completion:^(id _Nullable result, NSError * _Nullable error) {
        if (error || ![result isKindOfClass:[NSDictionary class]]) {
            completion(nil, nil, error ?: [NSError errorWithDomain:@"CFAPIService"
                                                              code:-2
                                                          userInfo:@{NSLocalizedDescriptionKey: @"No registration data"}]);
            return;
        }

        NSDictionary *dict = (NSDictionary *)result;
        NSString *registeredAt = [dict[@"created_at"] isKindOfClass:[NSString class]] ? dict[@"created_at"] : nil;
        NSString *expiresAt = [dict[@"expires_at"] isKindOfClass:[NSString class]] ? dict[@"expires_at"] : nil;

        if (registeredAt.length == 0 || expiresAt.length == 0) {
            NSError *missingError = [NSError errorWithDomain:@"CFAPIService"
                                                        code:-3
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Missing date information"}];
            completion(nil, nil, missingError);
            return;
        }

        completion(registeredAt, expiresAt, nil);
    }];
}

@end
