//
//  CFKVNamespace.h
//  FlareDNS
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CFKVNamespace : NSObject

@property (nonatomic, copy) NSString *namespaceID;
@property (nonatomic, copy) NSString *title;

+ (instancetype)namespaceFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
