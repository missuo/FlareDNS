//
//  CFDomainDetailViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFDomainDetailViewController.h"
#import "CFDNSRecordsViewController.h"
#import "CFTrafficAnalyticsViewController.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

@interface CFDomainDetailViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) CFZone *zone;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) CFSSLMode sslMode;
@property (nonatomic, assign) CFSecurityLevel securityLevel;
@property (nonatomic, assign) BOOL developmentMode;
@property (nonatomic, assign) BOOL isLoadingSettings;
@property (nonatomic, assign) BOOL hasLoadedSettings;

@end

@implementation CFDomainDetailViewController

- (instancetype)initWithZone:(CFZone *)zone {
    self = [super init];
    if (self) {
        _zone = zone;
        _sslMode = CFSSLModeFull;
        _securityLevel = CFSecurityLevelMedium;
        _developmentMode = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupUI];
    [self loadZoneSettings];
}

- (void)setupNavigationBar {
    // Use standard navigation bar (gets Liquid Glass on iOS 26+)
    self.title = self.zone.name;
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (void)setupUI {
    // Adapt background color based on iOS version
    // Use grouped background so cells stand out
    if (@available(iOS 26.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor cf_primaryBackgroundColor];
    }
    
    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    if (@available(iOS 26.0, *)) {
        self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor cf_primaryBackgroundColor];
    }
    
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadZoneSettings {
    // Prevent duplicate requests
    if (self.isLoadingSettings || self.hasLoadedSettings) {
        return;
    }
    
    self.isLoadingSettings = YES;
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_enter(group);
    [[CFAPIService shared] fetchSSLModeForZoneID:self.zone.zoneID completion:^(CFSSLMode mode, NSError * _Nullable error) {
        if (!error) {
            self.sslMode = mode;
        }
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [[CFAPIService shared] fetchSecurityLevelForZoneID:self.zone.zoneID completion:^(CFSecurityLevel level, NSError * _Nullable error) {
        if (!error) {
            self.securityLevel = level;
        }
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [[CFAPIService shared] fetchDevelopmentModeForZoneID:self.zone.zoneID completion:^(BOOL enabled, NSError * _Nullable error) {
        if (!error) {
            self.developmentMode = enabled;
        }
        dispatch_group_leave(group);
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        self.isLoadingSettings = NO;
        self.hasLoadedSettings = YES;
        [self.tableView reloadData];
    });
}

// Helper to create consistent icon
- (UIImage *)iconWithName:(NSString *)name {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    return [UIImage systemImageNamed:name withConfiguration:config];
}

// Helper to create placeholder image for textLabel positioning
+ (UIImage *)placeholderImage {
    static UIImage *placeholder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), NO, 0);
        placeholder = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return placeholder;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Domain Information (Status)
        case 1: return 2; // Zone Details (DNS Records, Traffic Analytics)
        case 2: return self.zone.nameServers.count; // Nameservers
        case 3: return 2; // Security & Performance (SSL Mode, Security Level)
        case 4: return 2; // Cache Management (Development Mode, Purge Cache)
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"DOMAIN INFORMATION";
        case 1: return @"ZONE DETAILS";
        case 2: return @"NAMESERVERS";
        case 3: return @"SECURITY & PERFORMANCE";
        case 4: return @"CACHE MANAGEMENT";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 4) {
        return @"Development mode bypasses cache and purge cache clears all cached resources.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    
    // Adapt colors based on iOS version
    if (@available(iOS 26.0, *)) {
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.backgroundColor = [UIColor cf_secondaryBackgroundColor];
        cell.textLabel.textColor = [UIColor cf_primaryTextColor];
        cell.detailTextLabel.textColor = [UIColor cf_secondaryTextColor];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    switch (indexPath.section) {
        case 0: // Domain Information
            [self configureStatusCell:cell];
            break;
        case 1: // Zone Details
            [self configureZoneDetailsCell:cell atRow:indexPath.row];
            break;
        case 2: // Nameservers
            [self configureNameserverCell:cell atRow:indexPath.row];
            break;
        case 3: // Security & Performance
            [self configureSecurityCell:cell atRow:indexPath.row];
            break;
        case 4: // Cache Management
            [self configureCacheCell:cell atRow:indexPath.row];
            break;
    }
    
    return cell;
}

- (void)configureStatusCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Status";
    
    // Create a container view for proper centering
    NSString *statusText = [CFZone stringFromStatus:self.zone.status];
    UIColor *statusColor = (self.zone.status == CFZoneStatusActive) ? [UIColor systemGreenColor] : [UIColor secondaryLabelColor];
    UIColor *bgColor = (self.zone.status == CFZoneStatusActive) ? 
        [[UIColor systemGreenColor] colorWithAlphaComponent:0.15] : 
        [[UIColor secondaryLabelColor] colorWithAlphaComponent:0.15];
    
    // Create container view to ensure proper centering
    UIView *containerView = [[UIView alloc] init];
    containerView.backgroundColor = [UIColor clearColor];
    
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.text = statusText;
    statusLabel.textColor = statusColor;
    statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    statusLabel.backgroundColor = bgColor;
    statusLabel.layer.cornerRadius = 6;
    statusLabel.clipsToBounds = YES;
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [containerView addSubview:statusLabel];
    
    // Calculate size with padding
    CGSize textSize = [statusText sizeWithAttributes:@{NSFontAttributeName: statusLabel.font}];
    CGFloat width = textSize.width + 16;
    CGFloat height = 26;
    
    containerView.frame = CGRectMake(0, 0, width, height);
    
    [NSLayoutConstraint activateConstraints:@[
        [statusLabel.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        [statusLabel.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [statusLabel.widthAnchor constraintEqualToConstant:width],
        [statusLabel.heightAnchor constraintEqualToConstant:height]
    ]];
    
    cell.accessoryView = containerView;
}

- (void)configureZoneDetailsCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    // Use placeholder image to maintain textLabel positioning, then overlay custom imageView
    cell.imageView.image = [[self class] placeholderImage];
    cell.imageView.alpha = 0; // Make it invisible
    
    UIImageView *customImageView = [[UIImageView alloc] init];
    customImageView.translatesAutoresizingMaskIntoConstraints = NO;
    customImageView.contentMode = UIViewContentModeScaleAspectFit;
    customImageView.tag = 999;
    
    if (row == 0) {
        cell.textLabel.text = @"DNS Records";
        customImageView.image = [self iconWithName:@"list.bullet.rectangle.fill"];
        customImageView.tintColor = [UIColor systemBlueColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.textLabel.text = @"Traffic Analytics";
        customImageView.image = [self iconWithName:@"chart.bar.fill"];
        customImageView.tintColor = [UIColor systemGreenColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    [cell.contentView addSubview:customImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [customImageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [customImageView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [customImageView.widthAnchor constraintEqualToConstant:28],
        [customImageView.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)configureNameserverCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    if (row < self.zone.nameServers.count) {
        cell.textLabel.text = self.zone.nameServers[row];
        if (@available(iOS 26.0, *)) {
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            cell.textLabel.textColor = [UIColor cf_secondaryTextColor];
        }
    }
}

- (void)configureSecurityCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    // Use placeholder image to maintain textLabel positioning, then overlay custom imageView
    cell.imageView.image = [[self class] placeholderImage];
    cell.imageView.alpha = 0; // Make it invisible
    
    UIImageView *customImageView = [[UIImageView alloc] init];
    customImageView.translatesAutoresizingMaskIntoConstraints = NO;
    customImageView.contentMode = UIViewContentModeScaleAspectFit;
    customImageView.tag = 999;
    
    if (row == 0) {
        cell.textLabel.text = @"SSL Mode";
        customImageView.image = [self iconWithName:@"lock.fill"];
        customImageView.tintColor = [UIColor systemOrangeColor];
        cell.detailTextLabel.text = [CFZone stringFromSSLMode:self.sslMode];
        cell.detailTextLabel.textColor = [UIColor systemBlueColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.textLabel.text = @"Security Level";
        customImageView.image = [self iconWithName:@"shield.fill"];
        customImageView.tintColor = [UIColor systemPurpleColor];
        cell.detailTextLabel.text = [CFZone stringFromSecurityLevel:self.securityLevel];
        cell.detailTextLabel.textColor = [UIColor systemBlueColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    [cell.contentView addSubview:customImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [customImageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [customImageView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [customImageView.widthAnchor constraintEqualToConstant:28],
        [customImageView.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)configureCacheCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    // Use placeholder image to maintain textLabel positioning, then overlay custom imageView
    cell.imageView.image = [[self class] placeholderImage];
    cell.imageView.alpha = 0; // Make it invisible
    
    UIImageView *customImageView = [[UIImageView alloc] init];
    customImageView.translatesAutoresizingMaskIntoConstraints = NO;
    customImageView.contentMode = UIViewContentModeScaleAspectFit;
    customImageView.tag = 999;
    
    if (row == 0) {
        cell.textLabel.text = @"Development Mode";
        customImageView.image = [self iconWithName:@"wrench.and.screwdriver.fill"];
        customImageView.tintColor = [UIColor systemYellowColor];
        
        UISwitch *devModeSwitch = [[UISwitch alloc] init];
        devModeSwitch.on = self.developmentMode;
        devModeSwitch.onTintColor = [UIColor systemGreenColor];
        [devModeSwitch addTarget:self action:@selector(developmentModeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = devModeSwitch;
    } else {
        cell.textLabel.text = @"Purge Cache";
        cell.textLabel.textColor = [UIColor systemBlueColor];
        customImageView.image = [self iconWithName:@"trash.fill"];
        customImageView.tintColor = [UIColor systemRedColor];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    [cell.contentView addSubview:customImageView];
    
    [NSLayoutConstraint activateConstraints:@[
        [customImageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [customImageView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [customImageView.widthAnchor constraintEqualToConstant:28],
        [customImageView.heightAnchor constraintEqualToConstant:28]
    ]];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Add shadow to cells for better depth perception (pre-iOS 26 only)
    if (@available(iOS 26.0, *)) {
        // iOS 26 has Liquid Glass
    } else {
        cell.layer.shadowColor = [UIColor blackColor].CGColor;
        cell.layer.shadowOffset = CGSizeMake(0, 1);
        cell.layer.shadowRadius = 3;
        cell.layer.shadowOpacity = 0.2;
        cell.layer.masksToBounds = NO;
        cell.clipsToBounds = NO;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            CFDNSRecordsViewController *dnsVC = [[CFDNSRecordsViewController alloc] initWithZone:self.zone];
            [self.navigationController pushViewController:dnsVC animated:YES];
        } else {
            CFTrafficAnalyticsViewController *analyticsVC = [[CFTrafficAnalyticsViewController alloc] initWithZone:self.zone];
            [self.navigationController pushViewController:analyticsVC animated:YES];
        }
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            [self showSSLModePicker];
        } else {
            [self showSecurityLevelPicker];
        }
    } else if (indexPath.section == 4 && indexPath.row == 1) {
        [self purgeCacheTapped];
    }
}

#pragma mark - Actions

- (void)developmentModeSwitchChanged:(UISwitch *)sender {
    [[CFAPIService shared] setDevelopmentMode:sender.on forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            sender.on = !sender.on;
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.developmentMode = sender.on;
        }
    }];
}

- (void)showSSLModePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SSL Mode" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *modes = @[@(CFSSLModeOff), @(CFSSLModeFlexible), @(CFSSLModeFull), @(CFSSLModeFullStrict)];
    NSArray *titles = @[@"Off", @"Flexible", @"Full", @"Full (Strict)"];
    
    for (NSInteger i = 0; i < modes.count; i++) {
        CFSSLMode mode = [modes[i] integerValue];
        UIAlertAction *action = [UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self setSSLMode:mode];
        }];
        
        if (mode == self.sslMode) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setSSLMode:(CFSSLMode)mode {
    [[CFAPIService shared] setSSLMode:mode forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.sslMode = mode;
            [self.tableView reloadData];
        }
    }];
}

- (void)showSecurityLevelPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Security Level" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *levels = @[@(CFSecurityLevelUnderAttack), @(CFSecurityLevelHigh), @(CFSecurityLevelMedium), @(CFSecurityLevelLow), @(CFSecurityLevelEssentiallyOff)];
    NSArray *titles = @[@"Under Attack", @"High", @"Medium", @"Low", @"Essentially Off"];
    
    for (NSInteger i = 0; i < levels.count; i++) {
        CFSecurityLevel level = [levels[i] integerValue];
        UIAlertAction *action = [UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self setSecurityLevel:level];
        }];
        
        if (level == self.securityLevel) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setSecurityLevel:(CFSecurityLevel)level {
    [[CFAPIService shared] setSecurityLevel:level forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.securityLevel = level;
            [self.tableView reloadData];
        }
    }];
}

- (void)purgeCacheTapped {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Purge Cache"
                                                                     message:@"Are you sure you want to purge all cached resources?"
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Purge" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[CFAPIService shared] purgeCacheForZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            } else {
                [self showAlertWithTitle:@"Success" message:@"Cache has been purged successfully."];
            }
        }];
    }]];
    
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
