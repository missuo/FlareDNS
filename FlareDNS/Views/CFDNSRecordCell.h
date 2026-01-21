//
//  CFDNSRecordCell.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>
#import "CFDNSRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFDNSRecordCell : UITableViewCell

- (void)configureWithRecord:(CFDNSRecord *)record;

@end

NS_ASSUME_NONNULL_END
