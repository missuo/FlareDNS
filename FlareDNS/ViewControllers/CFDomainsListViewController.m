//
//  CFDomainsListViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import <UIKit/UIKit.h>

#import "CFAPIService.h"
#import "CFAccount.h"
#import "CFAccountsViewController.h"
#import "CFDomainCell.h"
#import "CFDomainDetailViewController.h"
#import "CFDomainsListViewController.h"
#import "CFKeychainService.h"
#import "CFTrafficData.h"
#import "CFZone.h"
#import "UIColor+FlareDNS.h"

static NSString *const kDomainCellIdentifier = @"DomainCell";

@interface CFDomainsListViewController () <
    UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate,
    UISearchResultsUpdating, CFAccountsViewControllerDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIRefreshControl *refreshControl;
@property(nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property(nonatomic, strong) NSArray<CFZone *> *zones;
@property(nonatomic, strong) NSArray<CFZone *> *filteredZones;
@property(nonatomic, assign) BOOL isSearching;

// Traffic cache: zoneID → @{ @"points": NSArray<NSNumber*>, @"value": NSString
// }
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSDictionary *> *trafficCache;

@end

@implementation CFDomainsListViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupNavigationBar];
  [self setupUI];
  [self setupConstraints];
  [self loadZones];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  // Ensure navigation bar is visible when returning from other views
  self.navigationController.navigationBarHidden = NO;
}

- (void)setupNavigationBar {
  // Use standard navigation bar (gets Liquid Glass on iOS 26+)
  self.navigationController.navigationBarHidden = NO;
  self.title = @"Domains";
  self.navigationController.navigationBar.prefersLargeTitles = YES;
  self.navigationItem.largeTitleDisplayMode =
      UINavigationItemLargeTitleDisplayModeAlways;

  // Settings button (left)
  UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"gearshape"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(settingsButtonTapped)];
  self.navigationItem.leftBarButtonItem = settingsItem;

  // Add button (right)
  UIBarButtonItem *addItem =
      [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(addButtonTapped)];
  self.navigationItem.rightBarButtonItem = addItem;
}

- (void)setupUI {
  // Adapt background color based on iOS version
  // Use grouped background so cells stand out
  if (@available(iOS 26.0, *)) {
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  } else {
    self.view.backgroundColor = [UIColor cf_primaryBackgroundColor];
  }

  // Search bar - now as search controller for better integration
  UISearchController *searchController =
      [[UISearchController alloc] initWithSearchResultsController:nil];
  searchController.searchResultsUpdater = self;
  searchController.obscuresBackgroundDuringPresentation = NO;
  searchController.searchBar.placeholder = @"Search domains";
  searchController.searchBar.delegate = self;
  self.navigationItem.searchController = searchController;
  self.navigationItem.hidesSearchBarWhenScrolling = NO;
  self.definesPresentationContext = YES;

  // Table view - use inset grouped for modern appearance
  self.tableView =
      [[UITableView alloc] initWithFrame:CGRectZero
                                   style:UITableViewStyleInsetGrouped];
  if (@available(iOS 26.0, *)) {
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
  } else {
    self.tableView.backgroundColor = [UIColor cf_primaryBackgroundColor];
  }
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  self.tableView.rowHeight = 56;
  [self.tableView registerClass:[CFDomainCell class]
         forCellReuseIdentifier:kDomainCellIdentifier];
  [self.view addSubview:self.tableView];

  // Refresh control
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(loadZones)
                forControlEvents:UIControlEventValueChanged];
  self.tableView.refreshControl = self.refreshControl;

  // Activity indicator
  self.activityIndicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  self.activityIndicator.hidesWhenStopped = YES;
  [self.view addSubview:self.activityIndicator];

  self.zones = @[];
  self.filteredZones = @[];
  self.trafficCache = [NSMutableDictionary dictionary];
}

- (void)setupConstraints {
  [NSLayoutConstraint activateConstraints:@[
    // Table view - now starts from top since navigation handles the rest
    [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.tableView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor],

    // Activity indicator
    [self.activityIndicator.centerXAnchor
        constraintEqualToAnchor:self.view.centerXAnchor],
    [self.activityIndicator.centerYAnchor
        constraintEqualToAnchor:self.view.centerYAnchor]
  ]];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:
    (UISearchController *)searchController {
  NSString *searchText = searchController.searchBar.text;

  if (searchText.length == 0) {
    self.filteredZones = self.zones;
    self.isSearching = NO;
  } else {
    self.isSearching = YES;
    NSPredicate *predicate =
        [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", searchText];
    self.filteredZones = [self.zones filteredArrayUsingPredicate:predicate];
  }
  [self.tableView reloadData];
}

- (void)loadZones {
  if (self.zones.count == 0) {
    [self.activityIndicator startAnimating];
  }

  [[CFAPIService shared]
      fetchZonesWithCompletion:^(NSArray<CFZone *> *_Nullable zones,
                                 NSError *_Nullable error) {
        [self.activityIndicator stopAnimating];
        [self.refreshControl endRefreshing];

        if (error) {
          [self showAlertWithTitle:@"Error" message:error.localizedDescription];
          return;
        }

        self.zones = zones ?: @[];
        self.filteredZones = self.zones;
        [self.trafficCache removeAllObjects];
        [self.tableView reloadData];
        [self fetchTrafficForZones:self.zones];
      }];
}

#pragma mark - Traffic Analytics

- (void)fetchTrafficForZones:(NSArray<CFZone *> *)zones {
  NSDate *until = [NSDate date];
  NSDate *since = [until dateByAddingTimeInterval:-24 * 60 * 60];

  for (CFZone *zone in zones) {
    NSString *zoneID = zone.zoneID;
    [[CFAPIService shared]
        fetchTrafficAnalyticsForZoneID:zoneID
                                 since:since
                                 until:until
                            completion:^(CFTrafficData *_Nullable data,
                                         NSError *_Nullable error) {
                              // Extract requests time-series; fall back to
                              // empty
                              NSArray<NSNumber *> *requestsData = @[];
                              NSString *valueStr = @"0";

                              if (!error && data) {
                                for (NSDictionary *series in data
                                         .timeSeriesData) {
                                  if ([series[@"type"]
                                          isEqualToString:@"requests"]) {
                                    NSArray *pts = series[@"data"];
                                    if (pts.count > 0)
                                      requestsData = pts;
                                    break;
                                  }
                                }
                                if (data.totalRequests > 0) {
                                  valueStr =
                                      [self formatCount:data.totalRequests];
                                }
                              }

                              self.trafficCache[zoneID] = @{
                                @"points" : requestsData,
                                @"value" : valueStr
                              };

                              // Refresh the visible cell
                              dispatch_async(dispatch_get_main_queue(), ^{
                                NSUInteger idx = [self.filteredZones
                                    indexOfObjectPassingTest:^BOOL(
                                        CFZone *z, NSUInteger i, BOOL *stop) {
                                      return [z.zoneID isEqualToString:zoneID];
                                    }];
                                if (idx == NSNotFound)
                                  return;

                                NSIndexPath *ip =
                                    [NSIndexPath indexPathForRow:idx
                                                       inSection:0];
                                CFDomainCell *cell =
                                    (CFDomainCell *)[self.tableView
                                        cellForRowAtIndexPath:ip];
                                if (cell) {
                                  [cell
                                      configureChartWithDataPoints:requestsData
                                                             value:valueStr];
                                }
                              });
                            }];
  }
}

- (NSString *)formatCount:(NSInteger)count {
  if (count >= 1000000) {
    return [NSString stringWithFormat:@"%.1fM", count / 1000000.0];
  } else if (count >= 1000) {
    return [NSString stringWithFormat:@"%.1fk", count / 1000.0];
  }
  return [NSString stringWithFormat:@"%ld", (long)count];
}

#pragma mark - Actions

- (void)addButtonTapped {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"Add Domain"
                                          message:@"Enter the domain name you "
                                                  @"want to add to Cloudflare"
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert
      addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.placeholder = @"example.com";
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
      }];

  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [alert addAction:[UIAlertAction
                       actionWithTitle:@"Add"
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *_Nonnull action) {
                                 NSString *domainName =
                                     alert.textFields.firstObject.text;
                                 if (domainName.length > 0) {
                                   [self addDomainWithName:domainName];
                                 }
                               }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)addDomainWithName:(NSString *)domainName {
  [self.activityIndicator startAnimating];

  [[CFAPIService shared]
      addZoneWithName:domainName
           completion:^(CFZone *_Nullable zone, NSError *_Nullable error) {
             [self.activityIndicator stopAnimating];

             if (error) {
               [self showAlertWithTitle:@"Error"
                                message:error.localizedDescription];
               return;
             }

             // Show success message with nameservers
             NSString *message = [NSString
                 stringWithFormat:
                     @"Domain '%@' has been added successfully.\n\nPlease "
                     @"update your domain's nameservers to:\n%@",
                     zone.name,
                     [zone.nameServers componentsJoinedByString:@"\n"]];

             UIAlertController *successAlert = [UIAlertController
                 alertControllerWithTitle:@"Domain Added"
                                  message:message
                           preferredStyle:UIAlertControllerStyleAlert];
             [successAlert
                 addAction:[UIAlertAction
                               actionWithTitle:@"OK"
                                         style:UIAlertActionStyleDefault
                                       handler:nil]];
             [self presentViewController:successAlert
                                animated:YES
                              completion:nil];

             // Reload zones list
             [self loadZones];
           }];
}

- (void)settingsButtonTapped {
  CFAccountsViewController *settingsVC =
      [[CFAccountsViewController alloc] init];
  settingsVC.delegate = self;
  [self.navigationController pushViewController:settingsVC animated:YES];
}

#pragma mark - CFAccountsViewControllerDelegate

- (void)accountsViewControllerDidSwitchAccount:
    (CFAccountsViewController *)controller {
  // Reload zones for the new account
  self.zones = @[];
  self.filteredZones = @[];
  [self.tableView reloadData];
  [self loadZones];
}

- (void)accountsViewControllerDidLogout:(CFAccountsViewController *)controller {
  [CFAPIService shared].email = nil;
  [CFAPIService shared].apiKey = nil;
  [self.delegate domainsListViewControllerDidLogout:self];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return self.filteredZones.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  CFDomainCell *cell =
      [tableView dequeueReusableCellWithIdentifier:kDomainCellIdentifier
                                      forIndexPath:indexPath];
  CFZone *zone = self.filteredZones[indexPath.row];
  [cell configureWithZone:zone];
  // Populate chart from cache if available
  NSDictionary *cached = self.trafficCache[zone.zoneID];
  [cell configureChartWithDataPoints:cached[@"points"] value:cached[@"value"]];
  return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
  // Add shadow to cells for better depth perception (pre-iOS 26 only)
  if (@available(iOS 26.0, *)) {
    // iOS 26 has Liquid Glass, no need for extra shadows
  } else {
    // Add subtle shadow to the cell's layer
    cell.layer.shadowColor = [UIColor blackColor].CGColor;
    cell.layer.shadowOffset = CGSizeMake(0, 1);
    cell.layer.shadowRadius = 3;
    cell.layer.shadowOpacity = 0.2;
    cell.layer.masksToBounds = NO;
    cell.clipsToBounds = NO;
  }
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  CFZone *zone = self.filteredZones[indexPath.row];
  CFDomainDetailViewController *detailVC =
      [[CFDomainDetailViewController alloc] initWithZone:zone];
  [self.navigationController pushViewController:detailVC animated:YES];
}

- (UIView *)tableView:(UITableView *)tableView
    viewForHeaderInSection:(NSInteger)section {
  return nil;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForHeaderInSection:(NSInteger)section {
  return 0.01;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText {
  if (searchText.length == 0) {
    self.filteredZones = self.zones;
    self.isSearching = NO;
  } else {
    self.isSearching = YES;
    NSPredicate *predicate =
        [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", searchText];
    self.filteredZones = [self.zones filteredArrayUsingPredicate:predicate];
  }
  [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  [searchBar resignFirstResponder];
}

@end
