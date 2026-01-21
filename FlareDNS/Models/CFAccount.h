//
//  CFAccount.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFAccount : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy, nullable) NSString *displayName;

- (instancetype)initWithEmail:(NSString *)email apiKey:(NSString *)apiKey;

@end

NS_ASSUME_NONNULL_END
