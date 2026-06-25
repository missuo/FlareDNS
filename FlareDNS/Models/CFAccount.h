//
//  CFAccount.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CFAuthMode) {
    CFAuthModeGlobalKey = 0,
    CFAuthModeAPIToken = 1
};

@interface CFAccount : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, assign) CFAuthMode authMode;

- (instancetype)initWithEmail:(NSString *)email apiKey:(NSString *)apiKey;
- (instancetype)initWithEmail:(NSString *)email apiKey:(NSString *)apiKey authMode:(CFAuthMode)authMode;
- (BOOL)usesAPIToken;

@end

NS_ASSUME_NONNULL_END
