//
//  CFKeychainService.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFKeychainService.h"
#import <Security/Security.h>

static NSString *const kServiceName = @"nz.owo.FlareDNS";
static NSString *const kEmailAccount = @"cloudflare_email";
static NSString *const kAPIKeyAccount = @"cloudflare_api_key";
static NSString *const kAccountsKey = @"cloudflare_accounts";
static NSString *const kCurrentAccountKey = @"cloudflare_current_account";

@implementation CFKeychainService

+ (instancetype)shared {
    static CFKeychainService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CFKeychainService alloc] init];
    });
    return instance;
}

#pragma mark - Legacy Single Account Methods

- (BOOL)saveEmail:(NSString *)email apiKey:(NSString *)apiKey {
    // Create an account and add it
    CFAccount *account = [[CFAccount alloc] initWithEmail:email apiKey:apiKey];
    
    // Check if account with same email already exists
    NSArray *existingAccounts = [self getAllAccounts];
    for (CFAccount *existing in existingAccounts) {
        if ([existing.email isEqualToString:email]) {
            // Update existing account
            existing.apiKey = apiKey;
            [self updateAccount:existing];
            [self setCurrentAccount:existing];
            return YES;
        }
    }
    
    // Add new account
    [self addAccount:account];
    [self setCurrentAccount:account];
    return YES;
}

- (nullable NSString *)getEmail {
    CFAccount *current = [self getCurrentAccount];
    return current.email;
}

- (nullable NSString *)getAPIKey {
    CFAccount *current = [self getCurrentAccount];
    return current.apiKey;
}

- (BOOL)deleteCredentials {
    CFAccount *current = [self getCurrentAccount];
    if (current) {
        [self removeAccount:current];
    }
    
    // Set another account as current if available
    NSArray *accounts = [self getAllAccounts];
    if (accounts.count > 0) {
        [self setCurrentAccount:accounts.firstObject];
    } else {
        [self deleteValueForAccount:kCurrentAccountKey];
    }
    
    return YES;
}

- (BOOL)hasStoredCredentials {
    return [self getCurrentAccount] != nil;
}

#pragma mark - Multi-Account Methods

- (NSArray<CFAccount *> *)getAllAccounts {
    NSData *data = [self getDataForAccount:kAccountsKey];
    if (!data) {
        return @[];
    }
    
    NSError *error;
    NSSet *allowedClasses = [NSSet setWithObjects:[NSArray class], [NSMutableArray class], [CFAccount class], [NSString class], nil];
    NSArray *accounts = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses fromData:data error:&error];
    
    if (error) {
        NSLog(@"Error unarchiving accounts: %@", error);
        return @[];
    }
    
    return accounts ?: @[];
}

- (BOOL)saveAllAccounts:(NSArray<CFAccount *> *)accounts {
    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:accounts requiringSecureCoding:YES error:&error];
    
    if (error) {
        NSLog(@"Error archiving accounts: %@", error);
        return NO;
    }
    
    [self deleteValueForAccount:kAccountsKey];
    return [self saveData:data forAccount:kAccountsKey];
}

- (BOOL)addAccount:(CFAccount *)account {
    NSMutableArray *accounts = [[self getAllAccounts] mutableCopy];
    [accounts addObject:account];
    return [self saveAllAccounts:accounts];
}

- (BOOL)removeAccount:(CFAccount *)account {
    NSMutableArray *accounts = [[self getAllAccounts] mutableCopy];
    
    CFAccount *toRemove = nil;
    for (CFAccount *existing in accounts) {
        if ([existing.identifier isEqualToString:account.identifier]) {
            toRemove = existing;
            break;
        }
    }
    
    if (toRemove) {
        [accounts removeObject:toRemove];
        
        // If removing current account, clear current account
        NSString *currentId = [self getCurrentAccountIdentifier];
        if ([currentId isEqualToString:account.identifier]) {
            [self deleteValueForAccount:kCurrentAccountKey];
            if (accounts.count > 0) {
                [self setCurrentAccount:accounts.firstObject];
            }
        }
        
        return [self saveAllAccounts:accounts];
    }
    
    return NO;
}

- (BOOL)updateAccount:(CFAccount *)account {
    NSMutableArray *accounts = [[self getAllAccounts] mutableCopy];
    
    for (NSInteger i = 0; i < accounts.count; i++) {
        CFAccount *existing = accounts[i];
        if ([existing.identifier isEqualToString:account.identifier]) {
            accounts[i] = account;
            return [self saveAllAccounts:accounts];
        }
    }
    
    return NO;
}

#pragma mark - Current Account

- (nullable CFAccount *)getCurrentAccount {
    NSString *currentId = [self getCurrentAccountIdentifier];
    if (!currentId) {
        // Return first account if no current is set
        NSArray *accounts = [self getAllAccounts];
        if (accounts.count > 0) {
            [self setCurrentAccount:accounts.firstObject];
            return accounts.firstObject;
        }
        return nil;
    }
    
    NSArray *accounts = [self getAllAccounts];
    for (CFAccount *account in accounts) {
        if ([account.identifier isEqualToString:currentId]) {
            return account;
        }
    }
    
    // Current account not found, return first available
    if (accounts.count > 0) {
        [self setCurrentAccount:accounts.firstObject];
        return accounts.firstObject;
    }
    
    return nil;
}

- (BOOL)setCurrentAccount:(CFAccount *)account {
    [self deleteValueForAccount:kCurrentAccountKey];
    return [self saveValue:account.identifier forAccount:kCurrentAccountKey];
}

- (nullable NSString *)getCurrentAccountIdentifier {
    return [self getValueForAccount:kCurrentAccountKey];
}

#pragma mark - Private Methods

- (BOOL)saveValue:(NSString *)value forAccount:(NSString *)account {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    return [self saveData:data forAccount:account];
}

- (BOOL)saveData:(NSData *)data forAccount:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kServiceName,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    };
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return status == errSecSuccess;
}

- (nullable NSString *)getValueForAccount:(NSString *)account {
    NSData *data = [self getDataForAccount:account];
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (nullable NSData *)getDataForAccount:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kServiceName,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFTypeRef dataRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataRef);
    
    if (status == errSecSuccess && dataRef) {
        return (__bridge_transfer NSData *)dataRef;
    }
    
    return nil;
}

- (void)deleteValueForAccount:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kServiceName,
        (__bridge id)kSecAttrAccount: account
    };
    
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@end
