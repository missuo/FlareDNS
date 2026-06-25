//
//  CFWorkerScript.h
//  FlareDNS
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFWorkerScript : NSObject

@property (nonatomic, copy) NSString *scriptID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *createdOn;
@property (nonatomic, copy, nullable) NSString *modifiedOn;

+ (instancetype)scriptFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
