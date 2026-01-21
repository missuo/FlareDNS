//
//  CFKeychainService.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>
#import "CFAccount.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFKeychainService : NSObject

+ (instancetype)shared;

// Legacy single account methods (for backward compatibility)
- (BOOL)saveEmail:(NSString *)email apiKey:(NSString *)apiKey;
- (nullable NSString *)getEmail;
- (nullable NSString *)getAPIKey;
- (BOOL)deleteCredentials;
- (BOOL)hasStoredCredentials;

// Multi-account methods
- (NSArray<CFAccount *> *)getAllAccounts;
- (BOOL)addAccount:(CFAccount *)account;
- (BOOL)removeAccount:(CFAccount *)account;
- (BOOL)updateAccount:(CFAccount *)account;

// Current account
- (nullable CFAccount *)getCurrentAccount;
- (BOOL)setCurrentAccount:(CFAccount *)account;
- (nullable NSString *)getCurrentAccountIdentifier;

@end

NS_ASSUME_NONNULL_END
