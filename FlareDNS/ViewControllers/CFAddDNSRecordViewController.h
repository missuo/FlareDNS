//
//  CFAddDNSRecordViewController.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>
#import "CFZone.h"
#import "CFDNSRecord.h"

NS_ASSUME_NONNULL_BEGIN

@class CFAddDNSRecordViewController;

@protocol CFAddDNSRecordViewControllerDelegate <NSObject>
- (void)addDNSRecordViewControllerDidSave:(CFAddDNSRecordViewController *)controller;
- (void)addDNSRecordViewControllerDidCancel:(CFAddDNSRecordViewController *)controller;
@end

@interface CFAddDNSRecordViewController : UIViewController

@property (nonatomic, weak) id<CFAddDNSRecordViewControllerDelegate> delegate;

- (instancetype)initWithZone:(CFZone *)zone record:(nullable CFDNSRecord *)record;

@end

NS_ASSUME_NONNULL_END
