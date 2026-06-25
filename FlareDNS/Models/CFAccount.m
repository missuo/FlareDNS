//
//  CFAccount.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFAccount.h"

@implementation CFAccount

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithEmail:(NSString *)email apiKey:(NSString *)apiKey {
    return [self initWithEmail:email apiKey:apiKey authMode:CFAuthModeGlobalKey];
}

- (instancetype)initWithEmail:(NSString *)email apiKey:(NSString *)apiKey authMode:(CFAuthMode)authMode {
    self = [super init];
    if (self) {
        _identifier = [[NSUUID UUID] UUIDString];
        _email = email ?: @"";
        _apiKey = apiKey;
        _authMode = authMode;
        _displayName = (authMode == CFAuthModeAPIToken) ? @"API Token" : email;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.email forKey:@"email"];
    [coder encodeObject:self.apiKey forKey:@"apiKey"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeInteger:self.authMode forKey:@"authMode"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _email = [coder decodeObjectOfClass:[NSString class] forKey:@"email"];
        _apiKey = [coder decodeObjectOfClass:[NSString class] forKey:@"apiKey"];
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
        _authMode = [coder containsValueForKey:@"authMode"] ? [coder decodeIntegerForKey:@"authMode"] : CFAuthModeGlobalKey;
        if (!_email) {
            _email = @"";
        }
        if (!_displayName) {
            _displayName = (_authMode == CFAuthModeAPIToken) ? @"API Token" : _email;
        }
    }
    return self;
}

- (BOOL)usesAPIToken {
    return self.authMode == CFAuthModeAPIToken;
}

@end
