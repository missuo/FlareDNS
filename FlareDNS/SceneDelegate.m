//
//  SceneDelegate.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "SceneDelegate.h"
#import "CFLoginViewController.h"
#import "CFDomainsListViewController.h"
#import "CFAPIService.h"
#import "CFKeychainService.h"
#import "UIColor+FlareDNS.h"

@interface SceneDelegate () <CFLoginViewControllerDelegate, CFDomainsListViewControllerDelegate>

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    
    // Configure global appearance
    [self configureAppearance];
    
    // Check if user has stored credentials
    CFKeychainService *keychain = [CFKeychainService shared];
    if ([keychain hasStoredCredentials]) {
        // Set up API service with stored credentials
        CFAPIService *api = [CFAPIService shared];
        CFAccount *account = [keychain getCurrentAccount];
        if (account) {
            [api configureWithAccount:account];
        }
        
        // Show domains list
        [self showDomainsListAnimated:NO];
    } else {
        // Show login
        [self showLoginAnimated:NO];
    }
    
    [self.window makeKeyAndVisible];
}

- (void)configureAppearance {
    if (@available(iOS 26.0, *)) {
        // iOS 26+ uses Liquid Glass - use transparent/default appearances
        // Navigation bar with transparent background for Liquid Glass
        UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
        [navAppearance configureWithDefaultBackground];
        navAppearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        navAppearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        
        [UINavigationBar appearance].standardAppearance = navAppearance;
        [UINavigationBar appearance].scrollEdgeAppearance = navAppearance;
        [UINavigationBar appearance].tintColor = [UIColor systemBlueColor];
        
        // Tab bar with default (glass) appearance
        UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
        [tabAppearance configureWithDefaultBackground];
        
        [UITabBar appearance].standardAppearance = tabAppearance;
        [UITabBar appearance].scrollEdgeAppearance = tabAppearance;
        [UITabBar appearance].tintColor = [UIColor systemBlueColor];
    } else {
        // Pre-iOS 26: use custom dark appearance
        UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
        [navAppearance configureWithOpaqueBackground];
        navAppearance.backgroundColor = [UIColor cf_primaryBackgroundColor];
        navAppearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor cf_primaryTextColor]};
        navAppearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor cf_primaryTextColor]};
        
        [UINavigationBar appearance].standardAppearance = navAppearance;
        [UINavigationBar appearance].scrollEdgeAppearance = navAppearance;
        [UINavigationBar appearance].tintColor = [UIColor cf_accentColor];
        
        // Tab bar appearance
        UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
        [tabAppearance configureWithOpaqueBackground];
        tabAppearance.backgroundColor = [UIColor cf_primaryBackgroundColor];
        
        [UITabBar appearance].standardAppearance = tabAppearance;
        [UITabBar appearance].scrollEdgeAppearance = tabAppearance;
        [UITabBar appearance].tintColor = [UIColor cf_accentColor];
        
        // Table view appearance - only for pre-iOS 26
        [UITableView appearance].backgroundColor = [UIColor cf_primaryBackgroundColor];
        [UITableViewCell appearance].backgroundColor = [UIColor cf_secondaryBackgroundColor];
    }
}

- (void)showLoginAnimated:(BOOL)animated {
    CFLoginViewController *loginVC = [[CFLoginViewController alloc] init];
    loginVC.delegate = self;
    
    if (animated && self.window.rootViewController) {
        [UIView transitionWithView:self.window
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.window.rootViewController = loginVC;
        } completion:nil];
    } else {
        self.window.rootViewController = loginVC;
    }
}

- (void)showDomainsListAnimated:(BOOL)animated {
    CFDomainsListViewController *domainsVC = [[CFDomainsListViewController alloc] init];
    domainsVC.delegate = self;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:domainsVC];
    // Don't hide navigation bar - it uses Liquid Glass on iOS 26+
    
    if (animated && self.window.rootViewController) {
        [UIView transitionWithView:self.window
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.window.rootViewController = navController;
        } completion:nil];
    } else {
        self.window.rootViewController = navController;
    }
}

#pragma mark - CFLoginViewControllerDelegate

- (void)loginViewControllerDidLogin:(UIViewController *)controller {
    [self showDomainsListAnimated:YES];
}

#pragma mark - CFDomainsListViewControllerDelegate

- (void)domainsListViewControllerDidLogout:(UIViewController *)controller {
    [self showLoginAnimated:YES];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
}


- (void)sceneWillResignActive:(UIScene *)scene {
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
}


@end
