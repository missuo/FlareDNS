//
//  CFDNSRecord.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CFDNSRecordType) {
    CFDNSRecordTypeA,
    CFDNSRecordTypeAAAA,
    CFDNSRecordTypeCNAME,
    CFDNSRecordTypeTXT,
    CFDNSRecordTypeMX,
    CFDNSRecordTypeNS,
    CFDNSRecordTypeSRV,
    CFDNSRecordTypeCAA,
    CFDNSRecordTypePTR,
    CFDNSRecordTypeHTTPS,
    CFDNSRecordTypeSVCB
};

@interface CFDNSRecord : NSObject

@property (nonatomic, copy) NSString *recordID;
@property (nonatomic, copy) NSString *zoneID;
@property (nonatomic, copy) NSString *zoneName;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CFDNSRecordType type;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) BOOL proxied;
@property (nonatomic, assign) BOOL proxiable;
@property (nonatomic, assign) NSInteger ttl;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, copy, nullable) NSDate *createdOn;
@property (nonatomic, copy, nullable) NSDate *modifiedOn;
@property (nonatomic, copy, nullable) NSString *comment;
@property (nonatomic, copy, nullable) NSArray<NSString *> *tags;

+ (instancetype)recordFromDictionary:(NSDictionary *)dict;
+ (NSString *)stringFromType:(CFDNSRecordType)type;
+ (CFDNSRecordType)typeFromString:(NSString *)string;
+ (NSArray<NSString *> *)allRecordTypeStrings;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
