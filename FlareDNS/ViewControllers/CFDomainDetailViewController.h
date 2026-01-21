//
//  CFDomainDetailViewController.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>
#import "CFZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFDomainDetailViewController : UIViewController

- (instancetype)initWithZone:(CFZone *)zone;

@end

NS_ASSUME_NONNULL_END
