//
//  CFAccountsViewController.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CFAccountsViewController;

@protocol CFAccountsViewControllerDelegate <NSObject>

- (void)accountsViewControllerDidSwitchAccount:(CFAccountsViewController *)controller;
- (void)accountsViewControllerDidLogout:(CFAccountsViewController *)controller;

@end

@interface CFAccountsViewController : UIViewController

@property (nonatomic, weak, nullable) id<CFAccountsViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
