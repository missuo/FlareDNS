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
@property (nonatomic, assign) BOOL brotliEnabled;
@property (nonatomic, assign) BOOL alwaysOnlineEnabled;
@property (nonatomic, copy) NSString *cacheLevel;
@property (nonatomic, assign) NSInteger browserCacheTTL;
@property (nonatomic, assign) BOOL isLoadingSettings;
@property (nonatomic, assign) BOOL hasLoadedSettings;
@property (nonatomic, copy) NSString *registeredAt;
@property (nonatomic, copy) NSString *expiresAt;
@property (nonatomic, assign) BOOL domainExpiryLoaded;
@property (nonatomic, assign) BOOL domainExpiryError;

@end

@implementation CFDomainDetailViewController

- (instancetype)initWithZone:(CFZone *)zone {
    self = [super init];
    if (self) {
        _zone = zone;
        _sslMode = CFSSLModeFull;
        _securityLevel = CFSecurityLevelMedium;
        _developmentMode = NO;
        _brotliEnabled = NO;
        _alwaysOnlineEnabled = NO;
        _cacheLevel = @"basic";
        _browserCacheTTL = 14400;
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

    dispatch_group_enter(group);
    [[CFAPIService shared] fetchBrotliForZoneID:self.zone.zoneID completion:^(BOOL enabled, NSError * _Nullable error) {
        if (!error) {
            self.brotliEnabled = enabled;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [[CFAPIService shared] fetchAlwaysOnlineForZoneID:self.zone.zoneID completion:^(BOOL enabled, NSError * _Nullable error) {
        if (!error) {
            self.alwaysOnlineEnabled = enabled;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [[CFAPIService shared] fetchCacheLevelForZoneID:self.zone.zoneID completion:^(NSString * _Nullable value, NSError * _Nullable error) {
        if (!error && value.length > 0) {
            self.cacheLevel = value;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [[CFAPIService shared] fetchBrowserCacheTTLForZoneID:self.zone.zoneID completion:^(NSInteger seconds, NSError * _Nullable error) {
        if (!error && seconds > 0) {
            self.browserCacheTTL = seconds;
        }
        dispatch_group_leave(group);
    }];

    // Load cached auto-fetched dates for immediate display
    NSString *cacheKey = [NSString stringWithFormat:@"domainCachedDates_%@", self.zone.name];
    NSDictionary *cachedDates = [[NSUserDefaults standardUserDefaults] dictionaryForKey:cacheKey];
    if (cachedDates[@"registeredAt"] && cachedDates[@"expiresAt"]) {
        self.registeredAt = cachedDates[@"registeredAt"];
        self.expiresAt = cachedDates[@"expiresAt"];
    }

    dispatch_group_enter(group);
    // Registration/expiry comes from Cloudflare's own Registrar API (only domains registered with
    // Cloudflare Registrar are covered). The domain name is never sent to any third-party service.
    [[CFAPIService shared] fetchRegistrationForDomain:self.zone.name accountID:self.zone.accountID completion:^(NSString * _Nullable registeredAt, NSString * _Nullable expiresAt, NSError * _Nullable error) {
        if (!error && registeredAt && expiresAt) {
            self.registeredAt = registeredAt;
            self.expiresAt = expiresAt;
            // Cache the fetched dates, update if different
            NSDictionary *cached = [[NSUserDefaults standardUserDefaults] dictionaryForKey:cacheKey];
            if (![cached[@"registeredAt"] isEqualToString:registeredAt] || ![cached[@"expiresAt"] isEqualToString:expiresAt]) {
                [[NSUserDefaults standardUserDefaults] setObject:@{@"registeredAt": registeredAt, @"expiresAt": expiresAt} forKey:cacheKey];
            }
        } else {
            // Only mark error if we have no data at all
            if (!self.registeredAt || !self.expiresAt) {
                self.domainExpiryError = YES;
            }
        }
        self.domainExpiryLoaded = YES;
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
    return 7;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Domain Information (Status)
        case 1: return 1; // Domain Registration
        case 2: return 2; // Zone Details (DNS Records, Traffic Analytics)
        case 3: return self.zone.nameServers.count; // Nameservers
        case 4: return 2; // Security (SSL Mode, Security Level)
        case 5: return 4; // Performance (Brotli, Always Online, Cache Level, Browser TTL)
        case 6: return 3; // Cache Management (Development Mode, Custom Purge, Purge Cache)
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"DOMAIN INFORMATION";
        case 1: return @"DOMAIN REGISTRATION";
        case 2: return @"ZONE DETAILS";
        case 3: return @"NAMESERVERS";
        case 4: return @"SECURITY";
        case 5: return @"PERFORMANCE";
        case 6: return @"CACHE MANAGEMENT";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 6) {
        return @"Custom purge clears specific URLs. Purge cache clears all cached resources.";
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
        case 1: // Domain Registration
            return [self registrationCellForTableView:tableView];
        case 2: // Zone Details
            [self configureZoneDetailsCell:cell atRow:indexPath.row];
            break;
        case 3: // Nameservers
            [self configureNameserverCell:cell atRow:indexPath.row];
            break;
        case 4: // Security & Performance
            [self configureSecurityCell:cell atRow:indexPath.row];
            break;
        case 5: // Performance
            [self configurePerformanceCell:cell atRow:indexPath.row];
            break;
        case 6: // Cache Management
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

- (void)configurePerformanceCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    cell.imageView.image = [[self class] placeholderImage];
    cell.imageView.alpha = 0;

    UIImageView *customImageView = [[UIImageView alloc] init];
    customImageView.translatesAutoresizingMaskIntoConstraints = NO;
    customImageView.contentMode = UIViewContentModeScaleAspectFit;
    customImageView.tag = 999;

    if (row == 0) {
        cell.textLabel.text = @"Brotli";
        customImageView.image = [self iconWithName:@"archivebox.fill"];
        customImageView.tintColor = [UIColor systemTealColor];
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = self.brotliEnabled;
        [toggle addTarget:self action:@selector(brotliSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if (row == 1) {
        cell.textLabel.text = @"Always Online";
        customImageView.image = [self iconWithName:@"network"];
        customImageView.tintColor = [UIColor systemGreenColor];
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = self.alwaysOnlineEnabled;
        [toggle addTarget:self action:@selector(alwaysOnlineSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if (row == 2) {
        cell.textLabel.text = @"Cache Level";
        customImageView.image = [self iconWithName:@"speedometer"];
        customImageView.tintColor = [UIColor systemBlueColor];
        cell.detailTextLabel.text = [self displayNameForCacheLevel:self.cacheLevel];
        cell.detailTextLabel.textColor = [UIColor systemBlueColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.textLabel.text = @"Browser Cache TTL";
        customImageView.image = [self iconWithName:@"clock.fill"];
        customImageView.tintColor = [UIColor systemOrangeColor];
        cell.detailTextLabel.text = [self displayNameForBrowserCacheTTL:self.browserCacheTTL];
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
    } else if (row == 1) {
        cell.textLabel.text = @"Custom Purge";
        cell.textLabel.textColor = [UIColor systemBlueColor];
        customImageView.image = [self iconWithName:@"link.badge.plus"];
        customImageView.tintColor = [UIColor systemOrangeColor];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
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

- (UITableViewCell *)registrationCellForTableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (@available(iOS 26.0, *)) {
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        cell.backgroundColor = [UIColor cf_secondaryBackgroundColor];
    }

    if (!self.domainExpiryLoaded) {
        cell.textLabel.text = @"Loading...";
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        return cell;
    }

    if (!self.registeredAt || !self.expiresAt) {
        cell.textLabel.text = @"Unsupported";
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        return cell;
    }

    // Parse dates
    NSDateFormatter *parser = [[NSDateFormatter alloc] init];
    parser.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    parser.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    parser.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSDate *regDate = [parser dateFromString:self.registeredAt];
    NSDate *expDate = [parser dateFromString:self.expiresAt];

    // Try alternative format without time
    if (!regDate || !expDate) {
        parser.dateFormat = @"yyyy-MM-dd";
        if (!regDate) regDate = [parser dateFromString:self.registeredAt];
        if (!expDate) expDate = [parser dateFromString:self.expiresAt];
    }

    // Fall back to ISO8601 (handles fractional seconds and timezone offsets, e.g. Cloudflare timestamps)
    if (!regDate || !expDate) {
        NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
        iso.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        if (!regDate) regDate = [iso dateFromString:self.registeredAt];
        if (!expDate) expDate = [iso dateFromString:self.expiresAt];
    }

    if (!regDate || !expDate) {
        cell.textLabel.text = @"Unsupported";
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        self.registeredAt = nil;
        self.expiresAt = nil;
        return cell;
    }

    // Format for display
    NSDateFormatter *displayFormatter = [[NSDateFormatter alloc] init];
    displayFormatter.dateStyle = NSDateFormatterMediumStyle;
    displayFormatter.timeStyle = NSDateFormatterNoStyle;

    NSString *regStr = [displayFormatter stringFromDate:regDate];
    NSString *expStr = [displayFormatter stringFromDate:expDate];

    // Calculate progress
    NSTimeInterval totalInterval = [expDate timeIntervalSinceDate:regDate];
    NSTimeInterval elapsedInterval = [[NSDate date] timeIntervalSinceDate:regDate];
    float progress = (totalInterval > 0) ? (float)(elapsedInterval / totalInterval) : 0;
    progress = fminf(fmaxf(progress, 0.0f), 1.0f);
    float remaining = 1.0f - progress;

    // Determine color
    UIColor *progressColor;
    if (remaining > 0.5f) {
        progressColor = [UIColor systemGreenColor];
    } else if (remaining > 0.25f) {
        progressColor = [UIColor systemOrangeColor];
    } else {
        progressColor = [UIColor systemRedColor];
    }

    // Build custom content
    cell.textLabel.text = nil;

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
        [container.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [container.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [container.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12]
    ]];

    // Top row: Registered on left, Expires on right
    UILabel *regTitleLabel = [[UILabel alloc] init];
    regTitleLabel.text = @"Registered";
    regTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    regTitleLabel.textColor = [UIColor secondaryLabelColor];
    regTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *regDateLabel = [[UILabel alloc] init];
    regDateLabel.text = regStr;
    regDateLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    if (@available(iOS 26.0, *)) {
        regDateLabel.textColor = [UIColor labelColor];
    } else {
        regDateLabel.textColor = [UIColor cf_primaryTextColor];
    }
    regDateLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *expTitleLabel = [[UILabel alloc] init];
    expTitleLabel.text = @"Expires";
    expTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    expTitleLabel.textColor = [UIColor secondaryLabelColor];
    expTitleLabel.textAlignment = NSTextAlignmentRight;
    expTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *expDateLabel = [[UILabel alloc] init];
    expDateLabel.text = expStr;
    expDateLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    if (@available(iOS 26.0, *)) {
        expDateLabel.textColor = [UIColor labelColor];
    } else {
        expDateLabel.textColor = [UIColor cf_primaryTextColor];
    }
    expDateLabel.textAlignment = NSTextAlignmentRight;
    expDateLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:regTitleLabel];
    [container addSubview:regDateLabel];
    [container addSubview:expTitleLabel];
    [container addSubview:expDateLabel];

    // Progress bar
    UIView *trackView = [[UIView alloc] init];
    trackView.translatesAutoresizingMaskIntoConstraints = NO;
    trackView.backgroundColor = [[UIColor systemGrayColor] colorWithAlphaComponent:0.2];
    trackView.layer.cornerRadius = 4;
    trackView.clipsToBounds = YES;

    UIView *fillView = [[UIView alloc] init];
    fillView.translatesAutoresizingMaskIntoConstraints = NO;
    fillView.backgroundColor = progressColor;
    fillView.layer.cornerRadius = 4;

    [trackView addSubview:fillView];
    [container addSubview:trackView];

    // Percentage and remaining days labels
    NSInteger percentUsed = (NSInteger)(progress * 100);
    NSTimeInterval remainingInterval = [expDate timeIntervalSinceDate:[NSDate date]];
    NSInteger remainingDays = (NSInteger)(remainingInterval / 86400);

    UILabel *percentLabel = [[UILabel alloc] init];
    percentLabel.text = [NSString stringWithFormat:@"%ld%%", (long)percentUsed];
    percentLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    percentLabel.textColor = progressColor;
    percentLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *remainingLabel = [[UILabel alloc] init];
    if (remainingDays > 0) {
        remainingLabel.text = [NSString stringWithFormat:@"%ld days remaining", (long)remainingDays];
    } else {
        remainingLabel.text = @"Expired";
    }
    remainingLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    remainingLabel.textColor = [UIColor secondaryLabelColor];
    remainingLabel.textAlignment = NSTextAlignmentRight;
    remainingLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:percentLabel];
    [container addSubview:remainingLabel];

    [NSLayoutConstraint activateConstraints:@[
        // Registered title
        [regTitleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [regTitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],

        // Registered date
        [regDateLabel.topAnchor constraintEqualToAnchor:regTitleLabel.bottomAnchor constant:2],
        [regDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],

        // Expires title
        [expTitleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [expTitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        // Expires date
        [expDateLabel.topAnchor constraintEqualToAnchor:expTitleLabel.bottomAnchor constant:2],
        [expDateLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        // Progress bar track
        [trackView.topAnchor constraintEqualToAnchor:regDateLabel.bottomAnchor constant:10],
        [trackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [trackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [trackView.heightAnchor constraintEqualToConstant:8],

        // Progress bar fill
        [fillView.topAnchor constraintEqualToAnchor:trackView.topAnchor],
        [fillView.leadingAnchor constraintEqualToAnchor:trackView.leadingAnchor],
        [fillView.bottomAnchor constraintEqualToAnchor:trackView.bottomAnchor],
        [fillView.widthAnchor constraintEqualToAnchor:trackView.widthAnchor multiplier:progress],

        // Percentage label (left, below progress bar)
        [percentLabel.topAnchor constraintEqualToAnchor:trackView.bottomAnchor constant:6],
        [percentLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],

        // Remaining days label (right, below progress bar)
        [remainingLabel.topAnchor constraintEqualToAnchor:trackView.bottomAnchor constant:6],
        [remainingLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
    ]];
    [percentLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;

    return cell;
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
    
    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            CFDNSRecordsViewController *dnsVC = [[CFDNSRecordsViewController alloc] initWithZone:self.zone];
            [self.navigationController pushViewController:dnsVC animated:YES];
        } else {
            CFTrafficAnalyticsViewController *analyticsVC = [[CFTrafficAnalyticsViewController alloc] initWithZone:self.zone];
            [self.navigationController pushViewController:analyticsVC animated:YES];
        }
    } else if (indexPath.section == 4) {
        if (indexPath.row == 0) {
            [self showSSLModePicker];
        } else {
            [self showSecurityLevelPicker];
        }
    } else if (indexPath.section == 5) {
        if (indexPath.row == 2) {
            [self showCacheLevelPicker];
        } else if (indexPath.row == 3) {
            [self showBrowserCacheTTLPicker];
        }
    } else if (indexPath.section == 6) {
        if (indexPath.row == 1) {
            [self customPurgeTapped];
        } else if (indexPath.row == 2) {
            [self purgeCacheTapped];
        }
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

- (void)brotliSwitchChanged:(UISwitch *)sender {
    [[CFAPIService shared] setBrotli:sender.on forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            sender.on = !sender.on;
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.brotliEnabled = sender.on;
        }
    }];
}

- (void)alwaysOnlineSwitchChanged:(UISwitch *)sender {
    [[CFAPIService shared] setAlwaysOnline:sender.on forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            sender.on = !sender.on;
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.alwaysOnlineEnabled = sender.on;
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

- (NSString *)displayNameForCacheLevel:(NSString *)value {
    NSDictionary *names = @{
        @"aggressive": @"Aggressive",
        @"basic": @"Basic",
        @"simplified": @"Simplified"
    };
    return names[value] ?: value ?: @"Unknown";
}

- (void)showCacheLevelPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cache Level" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSString *> *values = @[@"aggressive", @"basic", @"simplified"];

    for (NSString *value in values) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:[self displayNameForCacheLevel:value] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
            [self setCacheLevel:value];
        }];
        if ([value isEqualToString:self.cacheLevel]) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        [alert addAction:action];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setCacheLevel:(NSString *)cacheLevel {
    [[CFAPIService shared] setCacheLevel:cacheLevel forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.cacheLevel = cacheLevel;
            [self.tableView reloadData];
        }
    }];
}

- (NSString *)displayNameForBrowserCacheTTL:(NSInteger)seconds {
    if (seconds <= 0) return @"Respect Existing";
    NSDictionary<NSNumber *, NSString *> *names = @{
        @30: @"30 seconds",
        @60: @"1 minute",
        @300: @"5 minutes",
        @1200: @"20 minutes",
        @3600: @"1 hour",
        @14400: @"4 hours",
        @28800: @"8 hours",
        @43200: @"12 hours",
        @86400: @"1 day",
        @604800: @"1 week",
        @2592000: @"1 month",
        @31536000: @"1 year"
    };
    return names[@(seconds)] ?: [NSString stringWithFormat:@"%ld seconds", (long)seconds];
}

- (void)showBrowserCacheTTLPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Browser Cache TTL" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSNumber *> *values = @[@0, @1800, @3600, @7200, @14400, @28800, @43200, @86400, @604800, @2592000, @31536000];

    for (NSNumber *number in values) {
        NSInteger seconds = [number integerValue];
        UIAlertAction *action = [UIAlertAction actionWithTitle:[self displayNameForBrowserCacheTTL:seconds] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
            [self setBrowserCacheTTL:seconds];
        }];
        if (seconds == self.browserCacheTTL) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        [alert addAction:action];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setBrowserCacheTTL:(NSInteger)seconds {
    [[CFAPIService shared] setBrowserCacheTTL:seconds forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            self.browserCacheTTL = seconds;
            [self.tableView reloadData];
        }
    }];
}

- (void)customPurgeTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom Purge"
                                                                   message:@"Enter a URL to purge. Separate multiple URLs with commas."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = [NSString stringWithFormat:@"https://%@/path", self.zone.name];
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Purge" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction * _Nonnull action) {
        NSString *raw = alert.textFields.firstObject.text ?: @"";
        NSMutableCharacterSet *separators = [NSMutableCharacterSet newlineCharacterSet];
        [separators addCharactersInString:@","];
        NSArray<NSString *> *lines = [raw componentsSeparatedByCharactersInSet:separators];
        NSMutableArray<NSString *> *files = [NSMutableArray array];
        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length > 0) {
                [files addObject:trimmed];
            }
        }

        if (files.count == 0) {
            [self showAlertWithTitle:@"Error" message:@"Enter at least one URL."];
            return;
        }

        [[CFAPIService shared] purgeCacheForZoneID:self.zone.zoneID files:files completion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            } else {
                [self showAlertWithTitle:@"Success" message:@"Selected URLs have been purged."];
            }
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
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
