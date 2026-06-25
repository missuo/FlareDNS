//
//  CFKVNamespacesViewController.m
//  FlareDNS
//

#import "CFKVNamespacesViewController.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

@interface CFKVNamespacesViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, copy) NSArray<NSDictionary *> *accounts;          // [{id,name}]
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<CFKVNamespace *> *> *namespacesByAccount;

@end

@implementation CFKVNamespacesViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _accounts = @[];
        _namespacesByAccount = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"KV";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self setupUI];
    [self loadData];
}

- (void)setupUI {
    if (@available(iOS 26.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor cf_primaryBackgroundColor];
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)loadData {
    [self.activityIndicator startAnimating];
    self.emptyLabel.hidden = YES;

    [[CFAPIService shared] fetchAccountsWithCompletion:^(NSArray<NSDictionary *> * _Nullable accounts, NSError * _Nullable error) {
        if (error || accounts.count == 0) {
            [self.activityIndicator stopAnimating];
            self.accounts = @[];
            [self.tableView reloadData];
            [self showEmptyMessage:error ? error.localizedDescription : @"No Cloudflare accounts are available for this credential."];
            return;
        }

        self.accounts = accounts;
        [self.namespacesByAccount removeAllObjects];

        dispatch_group_t group = dispatch_group_create();
        for (NSDictionary *account in accounts) {
            NSString *accountID = account[@"id"];
            dispatch_group_enter(group);
            [[CFAPIService shared] fetchKVNamespacesForAccountID:accountID completion:^(NSArray<CFKVNamespace *> * _Nullable namespaces, NSError * _Nullable nsError) {
                self.namespacesByAccount[accountID] = nsError ? @[] : (namespaces ?: @[]);
                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            self.emptyLabel.hidden = YES;
            [self.tableView reloadData];
        });
    }];
}

- (void)showEmptyMessage:(NSString *)message {
    self.emptyLabel.text = message;
    self.emptyLabel.hidden = NO;
}

#pragma mark - Helpers

- (NSArray<CFKVNamespace *> *)namespacesForSection:(NSInteger)section {
    if (section >= (NSInteger)self.accounts.count) {
        return @[];
    }
    NSString *accountID = self.accounts[section][@"id"];
    return self.namespacesByAccount[accountID] ?: @[];
}

- (NSString *)accountIDForSection:(NSInteger)section {
    return section < (NSInteger)self.accounts.count ? self.accounts[section][@"id"] : nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.accounts.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX([self namespacesForSection:section].count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < (NSInteger)self.accounts.count) {
        return [self.accounts[section][@"name"] uppercaseString];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    if (@available(iOS 26.0, *)) {
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.backgroundColor = [UIColor cf_secondaryBackgroundColor];
        cell.textLabel.textColor = [UIColor cf_primaryTextColor];
        cell.detailTextLabel.textColor = [UIColor cf_secondaryTextColor];
    }

    NSArray<CFKVNamespace *> *namespaces = [self namespacesForSection:indexPath.section];
    if (namespaces.count == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = @"No KV namespaces";
        cell.detailTextLabel.text = @"KV permissions are required to list namespaces.";
        cell.imageView.image = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    CFKVNamespace *namespace = namespaces[indexPath.row];
    cell.textLabel.text = namespace.title;
    cell.detailTextLabel.text = namespace.namespaceID;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.imageView.image = [UIImage systemImageNamed:@"shippingbox.fill"];
    cell.imageView.tintColor = [UIColor systemPurpleColor];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<CFKVNamespace *> *namespaces = [self namespacesForSection:indexPath.section];
    if (indexPath.row < (NSInteger)namespaces.count) {
        [self showKeysForNamespace:namespaces[indexPath.row] accountID:[self accountIDForSection:indexPath.section]];
    }
}

- (void)showKeysForNamespace:(CFKVNamespace *)namespace accountID:(NSString *)accountID {
    if (accountID.length == 0) {
        return;
    }
    [self.activityIndicator startAnimating];
    [[CFAPIService shared] fetchKVKeysForAccountID:accountID namespaceID:namespace.namespaceID completion:^(NSArray<NSString *> * _Nullable keys, NSError * _Nullable error) {
        [self.activityIndicator stopAnimating];
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            return;
        }

        NSString *message = keys.count > 0 ? [keys componentsJoinedByString:@"\n"] : @"No keys found.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:namespace.title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
