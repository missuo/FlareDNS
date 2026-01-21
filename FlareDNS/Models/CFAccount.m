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
    self = [super init];
    if (self) {
        _identifier = [[NSUUID UUID] UUIDString];
        _email = email;
        _apiKey = apiKey;
        _displayName = email;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.email forKey:@"email"];
    [coder encodeObject:self.apiKey forKey:@"apiKey"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _email = [coder decodeObjectOfClass:[NSString class] forKey:@"email"];
        _apiKey = [coder decodeObjectOfClass:[NSString class] forKey:@"apiKey"];
        _displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
    }
    return self;
}

@end
