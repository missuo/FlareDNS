//
//  CFWorkerRoutesViewController.h
//  FlareDNS
//

#import <UIKit/UIKit.h>
#import "CFZone.h"

NS_ASSUME_NONNULL_BEGIN

// Zone-level screen: lists, creates, and deletes the Worker routes that bind
// URL patterns on a specific zone to Worker scripts.
@interface CFWorkerRoutesViewController : UIViewController

- (instancetype)initWithZone:(CFZone *)zone;

@end

NS_ASSUME_NONNULL_END
