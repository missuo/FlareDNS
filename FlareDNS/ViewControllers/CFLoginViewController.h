//
//  CFLoginViewController.h
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CFLoginViewControllerDelegate <NSObject>
- (void)loginViewControllerDidLogin:(UIViewController *)controller;
@end

@interface CFLoginViewController : UIViewController

@property (nonatomic, weak) id<CFLoginViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
