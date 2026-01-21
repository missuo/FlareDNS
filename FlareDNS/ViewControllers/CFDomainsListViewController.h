//
//  CFDomainsListViewController.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CFDomainsListViewControllerDelegate <NSObject>
- (void)domainsListViewControllerDidLogout:(UIViewController *)controller;
@end

@interface CFDomainsListViewController : UIViewController

@property (nonatomic, weak) id<CFDomainsListViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
