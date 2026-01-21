//
//  CFDomainCell.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>
#import "CFZone.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFDomainCell : UITableViewCell

@property (nonatomic, strong, readonly) UIImageView *globeImageView;
@property (nonatomic, strong, readonly) UILabel *domainLabel;

- (void)configureWithZone:(CFZone *)zone;

@end

NS_ASSUME_NONNULL_END
