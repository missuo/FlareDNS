//
//  CFAccountsViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFAccountsViewController.h"
#import "CFAccount.h"
#import "CFKeychainService.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

static NSString *const kAccountCellIdentifier = @"AccountCell";
static NSString *const kActionCellIdentifier = @"ActionCell";

typedef NS_ENUM(NSInteger, CFSettingsSection) {
    CFSettingsSectionAccounts = 0,
    CFSettingsSectionActions,
    CFSettingsSectionHelp,
    CFSettingsSectionAbout,
    CFSettingsSectionCount
};

@interface CFAccountsViewController () <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<CFAccount *> *accounts;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation CFAccountsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupUI];
    [self loadAccounts];
}

- (void)setupNavigationBar {
    // Use standard navigation bar (gets Liquid Glass on iOS 26+)
    self.title = @"Settings";
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
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kAccountCellIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kActionCellIdentifier];
    
    // Footer view with version and branding
    self.tableView.tableFooterView = [self createFooterView];
    
    [self.view addSubview:self.tableView];
    
    // Activity indicator
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (UIView *)createFooterView {
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 150)];
    footerView.backgroundColor = [UIColor clearColor];
    
    // Get version info
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1";
    
    // App name label
    UILabel *appNameLabel = [[UILabel alloc] init];
    appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    appNameLabel.text = @"FlareDNS";
    appNameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    if (@available(iOS 26.0, *)) {
        appNameLabel.textColor = [UIColor labelColor];
    } else {
        appNameLabel.textColor = [UIColor cf_primaryTextColor];
    }
    appNameLabel.textAlignment = NSTextAlignmentCenter;
    [footerView addSubview:appNameLabel];
    
    // Version label
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.text = [NSString stringWithFormat:@"v%@ (%@)", version, build];
    versionLabel.font = [UIFont systemFontOfSize:13];
    if (@available(iOS 26.0, *)) {
        versionLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        versionLabel.textColor = [UIColor cf_secondaryTextColor];
    }
    versionLabel.textAlignment = NSTextAlignmentCenter;
    [footerView addSubview:versionLabel];
    
    // Made with love label
    UILabel *madeWithLabel = [[UILabel alloc] init];
    madeWithLabel.translatesAutoresizingMaskIntoConstraints = NO;
    madeWithLabel.text = @"Made with ❤️ from SF";
    madeWithLabel.font = [UIFont systemFontOfSize:13];
    if (@available(iOS 26.0, *)) {
        madeWithLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        madeWithLabel.textColor = [UIColor cf_secondaryTextColor];
    }
    madeWithLabel.textAlignment = NSTextAlignmentCenter;
    [footerView addSubview:madeWithLabel];
    
    // Company label
    UILabel *companyLabel = [[UILabel alloc] init];
    companyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    companyLabel.text = @"© 2026 OwO Network, LLC";
    companyLabel.font = [UIFont systemFontOfSize:12];
    if (@available(iOS 26.0, *)) {
        companyLabel.textColor = [UIColor tertiaryLabelColor];
    } else {
        companyLabel.textColor = [UIColor cf_tertiaryTextColor];
    }
    companyLabel.textAlignment = NSTextAlignmentCenter;
    [footerView addSubview:companyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [appNameLabel.topAnchor constraintEqualToAnchor:footerView.topAnchor constant:20],
        [appNameLabel.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor],
        
        [versionLabel.topAnchor constraintEqualToAnchor:appNameLabel.bottomAnchor constant:4],
        [versionLabel.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor],
        
        [madeWithLabel.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:12],
        [madeWithLabel.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor],
        
        [companyLabel.topAnchor constraintEqualToAnchor:madeWithLabel.bottomAnchor constant:12],
        [companyLabel.centerXAnchor constraintEqualToAnchor:footerView.centerXAnchor]
    ]];
    
    return footerView;
}

- (void)loadAccounts {
    self.accounts = [[[CFKeychainService shared] getAllAccounts] mutableCopy];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addAccountTappedFromView:(nullable UIView *)sourceView {
    // Step 1: choose the authentication method. The chosen method decides which
    // fields the next step shows (API Token has no email field at all).
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Add Account"
                                                                  message:@"Choose how to authenticate."
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"API Token" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self promptForCredentialsWithAuthMode:CFAuthModeAPIToken];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Global API Key" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self promptForCredentialsWithAuthMode:CFAuthModeGlobalKey];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    // Anchor the popover for iPad / regular-width presentations.
    UIView *anchor = sourceView ?: self.view;
    sheet.popoverPresentationController.sourceView = anchor;
    sheet.popoverPresentationController.sourceRect = anchor.bounds;

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)promptForCredentialsWithAuthMode:(CFAuthMode)authMode {
    BOOL usesToken = (authMode == CFAuthModeAPIToken);
    NSString *message = usesToken
        ? @"Paste your API Token. Some features may be limited by its permissions."
        : @"Enter the email and Global API Key for your Cloudflare account.";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(usesToken ? @"API Token" : @"Global API Key")
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];

    if (!usesToken) {
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"Email";
            textField.keyboardType = UIKeyboardTypeEmailAddress;
            textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
        }];
    }

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = usesToken ? @"API Token" : @"Global API Key";
        textField.secureTextEntry = YES;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *email = usesToken ? @"" : [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        UITextField *keyField = usesToken ? alert.textFields[0] : alert.textFields[1];
        NSString *apiKey = [keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if (apiKey.length == 0) {
            [self showAlertWithTitle:@"Error" message:[NSString stringWithFormat:@"Please enter %@.", usesToken ? @"an API Token" : @"your Global API Key"]];
            return;
        }
        if (!usesToken && email.length == 0) {
            [self showAlertWithTitle:@"Error" message:@"Please enter the email for your Global API Key."];
            return;
        }

        [self verifyAndAddAccountWithEmail:email apiKey:apiKey authMode:authMode];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)verifyAndAddAccountWithEmail:(NSString *)email apiKey:(NSString *)apiKey authMode:(CFAuthMode)authMode {
    // Verify credentials by fetching zones, restoring the active service
    // configuration if verification fails.
    [self.activityIndicator startAnimating];
    CFAPIService *apiService = [CFAPIService shared];
    NSString *originalEmail = apiService.email;
    NSString *originalAPIKey = apiService.apiKey;
    BOOL originalUsesAPIToken = apiService.usesAPIToken;

    apiService.email = email;
    apiService.apiKey = apiKey;
    apiService.usesAPIToken = (authMode == CFAuthModeAPIToken);

    [[CFAPIService shared] fetchZonesWithCompletion:^(NSArray<CFZone *> * _Nullable zones, NSError * _Nullable error) {
        [self.activityIndicator stopAnimating];

        if (error) {
            apiService.email = originalEmail;
            apiService.apiKey = originalAPIKey;
            apiService.usesAPIToken = originalUsesAPIToken;
            NSString *what = (authMode == CFAuthModeAPIToken) ? @"API Token" : @"email and Global API Key";
            [self showAlertWithTitle:@"Error" message:[NSString stringWithFormat:@"Invalid credentials. Please check your %@.", what]];
            return;
        }

        // Create and save account
        CFAccount *account = [[CFAccount alloc] initWithEmail:email apiKey:apiKey authMode:authMode];
        if ([[CFKeychainService shared] addAccount:account]) {
            // Set as current account if it's the first one
            if (self.accounts.count == 0) {
                [[CFKeychainService shared] setCurrentAccount:account];
            }
            [self loadAccounts];
        } else {
            [self showAlertWithTitle:@"Error" message:@"Failed to save account."];
        }
    }];
}

- (void)switchToAccount:(CFAccount *)account {
    [[CFKeychainService shared] setCurrentAccount:account];
    
    CFAPIService *apiService = [CFAPIService shared];
    [apiService configureWithAccount:account];
    
    if ([self.delegate respondsToSelector:@selector(accountsViewControllerDidSwitchAccount:)]) {
        [self.delegate accountsViewControllerDidSwitchAccount:self];
    }
    
    [self.tableView reloadData];
}

- (void)deleteAccount:(CFAccount *)account {
    [[CFKeychainService shared] removeAccount:account];
    [self loadAccounts];
    
    // If deleted account was current, switch to first available or logout
    CFAccount *currentAccount = [[CFKeychainService shared] getCurrentAccount];
    if (!currentAccount) {
        NSArray *remainingAccounts = [[CFKeychainService shared] getAllAccounts];
        if (remainingAccounts.count > 0) {
            [self switchToAccount:remainingAccounts[0]];
        } else {
            // No accounts left, logout
            if ([self.delegate respondsToSelector:@selector(accountsViewControllerDidLogout:)]) {
                [self.delegate accountsViewControllerDidLogout:self];
            }
        }
    }
}

- (void)logoutAllAccounts {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Logout All Accounts"
                                                                     message:@"Are you sure you want to logout all accounts? This will remove all stored credentials."
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Logout" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[CFKeychainService shared] deleteCredentials];
        
        if ([self.delegate respondsToSelector:@selector(accountsViewControllerDidLogout:)]) {
            [self.delegate accountsViewControllerDidLogout:self];
        }
    }]];
    
    [self presentViewController:confirm animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CFSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case CFSettingsSectionAccounts:
            return self.accounts.count;
        case CFSettingsSectionActions:
            return 2; // Add Account, Logout All
        case CFSettingsSectionHelp:
            return 1; // How to get API Key
        case CFSettingsSectionAbout:
            return 0; // Footer handles this
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Determine colors based on iOS version
    UIColor *cellBackground;
    UIColor *textColor;
    UIColor *secondaryTextColor;
    UIColor *accentColor = [UIColor systemBlueColor];
    UIColor *destructiveColor = [UIColor systemRedColor];
    
    if (@available(iOS 26.0, *)) {
        cellBackground = [UIColor secondarySystemGroupedBackgroundColor];
        textColor = [UIColor labelColor];
        secondaryTextColor = [UIColor secondaryLabelColor];
    } else {
        cellBackground = [UIColor cf_secondaryBackgroundColor];
        textColor = [UIColor cf_primaryTextColor];
        secondaryTextColor = [UIColor cf_secondaryTextColor];
    }
    
    if (indexPath.section == CFSettingsSectionAccounts) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAccountCellIdentifier forIndexPath:indexPath];
        
        CFAccount *account = self.accounts[indexPath.row];
        CFAccount *currentAccount = [[CFKeychainService shared] getCurrentAccount];
        BOOL isCurrentAccount = [account.identifier isEqualToString:currentAccount.identifier];
        
        cell.backgroundColor = cellBackground;
        cell.textLabel.text = [account usesAPIToken] ? (account.displayName ?: @"API Token") : account.email;
        cell.textLabel.textColor = textColor;
        cell.textLabel.font = [UIFont systemFontOfSize:17];
        cell.imageView.image = nil;
        
        if (isCurrentAccount) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.tintColor = accentColor;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
    } else if (indexPath.section == CFSettingsSectionActions) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kActionCellIdentifier forIndexPath:indexPath];
        cell.backgroundColor = cellBackground;
        cell.imageView.image = nil;
        
        if (indexPath.row == 0) {
            // Add Account
            cell.textLabel.text = @"Add Account";
            cell.textLabel.textColor = accentColor;
            cell.textLabel.textAlignment = NSTextAlignmentNatural;
            cell.accessoryType = UITableViewCellAccessoryNone;
        } else {
            // Logout All
            cell.textLabel.text = @"Logout All Accounts";
            cell.textLabel.textColor = destructiveColor;
            cell.textLabel.textAlignment = NSTextAlignmentNatural;
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        
        return cell;
    } else if (indexPath.section == CFSettingsSectionHelp) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"HelpCell"];
        cell.backgroundColor = cellBackground;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.separatorInset = UIEdgeInsetsZero;
        
        // Remove default labels
        cell.textLabel.text = nil;
        cell.detailTextLabel.text = nil;
        
        // Content text view with link (no title since it's in section header)
        UITextView *contentTextView = [[UITextView alloc] init];
        contentTextView.translatesAutoresizingMaskIntoConstraints = NO;
        contentTextView.backgroundColor = [UIColor clearColor];
        contentTextView.editable = NO;
        contentTextView.scrollEnabled = NO;
        contentTextView.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);
        contentTextView.textContainer.lineFragmentPadding = 0;
        contentTextView.font = [UIFont systemFontOfSize:15];
        contentTextView.textColor = secondaryTextColor;
        contentTextView.dataDetectorTypes = UIDataDetectorTypeLink;
        contentTextView.userInteractionEnabled = YES;
        contentTextView.delegate = self;
        
        NSString *linkURL = @"https://dash.cloudflare.com/profile/api-tokens";
        NSString *contentText = [NSString stringWithFormat:@"1. Open %@\n\n2. Create an API Token with the permissions you need.\n\n3. When adding an account, choose API Token (no email needed) or Global API Key (email plus key).", linkURL];
        
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:contentText];
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.lineSpacing = 4;
        [attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, contentText.length)];
        [attributedText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:15] range:NSMakeRange(0, contentText.length)];
        [attributedText addAttribute:NSForegroundColorAttributeName value:secondaryTextColor range:NSMakeRange(0, contentText.length)];
        
        // Make the URL clickable
        NSRange linkRange = [contentText rangeOfString:linkURL];
        if (linkRange.location != NSNotFound) {
            [attributedText addAttribute:NSLinkAttributeName value:linkURL range:linkRange];
            [attributedText addAttribute:NSForegroundColorAttributeName value:accentColor range:linkRange];
        }
        
        contentTextView.attributedText = attributedText;
        contentTextView.linkTextAttributes = @{NSForegroundColorAttributeName: accentColor, NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
        
        [cell.contentView addSubview:contentTextView];
        
        [NSLayoutConstraint activateConstraints:@[
            [contentTextView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [contentTextView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [contentTextView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [contentTextView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-16]
        ]];
        
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case CFSettingsSectionAccounts:
            return @"CLOUDFLARE ACCOUNTS";
        case CFSettingsSectionActions:
            return nil;
        case CFSettingsSectionHelp:
            return @"How to Get API Token";
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == CFSettingsSectionAccounts && self.accounts.count > 0) {
        return @"Tap an account to switch. Swipe left to delete.";
    }
    return nil;
}

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

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        if (@available(iOS 26.0, *)) {
            header.textLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            header.textLabel.textColor = [UIColor cf_secondaryTextColor];
        }
        header.textLabel.font = [UIFont systemFontOfSize:13];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
        if (@available(iOS 26.0, *)) {
            footer.textLabel.textColor = [UIColor tertiaryLabelColor];
        } else {
            footer.textLabel.textColor = [UIColor cf_tertiaryTextColor];
        }
        footer.textLabel.font = [UIFont systemFontOfSize:12];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == CFSettingsSectionAccounts) {
        CFAccount *account = self.accounts[indexPath.row];
        [self switchToAccount:account];
    } else if (indexPath.section == CFSettingsSectionActions) {
        if (indexPath.row == 0) {
            [self addAccountTappedFromView:[tableView cellForRowAtIndexPath:indexPath]];
        } else {
            [self logoutAllAccounts];
        }
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == CFSettingsSectionAccounts) {
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            CFAccount *account = self.accounts[indexPath.row];
            [self deleteAccount:account];
            completionHandler(YES);
        }];

        deleteAction.backgroundColor = [UIColor cf_redColor];

        return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    }

    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == CFSettingsSectionHelp) {
        return UITableViewAutomaticDimension;
    }
    return 50;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == CFSettingsSectionHelp) {
        return 120;
    }
    return 50;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction {
    // Open URL in Safari
    [[UIApplication sharedApplication] openURL:URL options:@{} completionHandler:nil];
    return NO; // Don't use default behavior
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
