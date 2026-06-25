//
//  CFWorkerScriptsViewController.m
//  FlareDNS
//

#import "CFWorkerScriptsViewController.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

@interface CFWorkerScriptsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, copy) NSArray<NSDictionary *> *accounts;          // [{id,name}]
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<CFWorkerScript *> *> *scriptsByAccount;

@end

@implementation CFWorkerScriptsViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _accounts = @[];
        _scriptsByAccount = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Workers";
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
        [self.scriptsByAccount removeAllObjects];

        dispatch_group_t group = dispatch_group_create();
        for (NSDictionary *account in accounts) {
            NSString *accountID = account[@"id"];
            dispatch_group_enter(group);
            [[CFAPIService shared] fetchWorkerScriptsForAccountID:accountID completion:^(NSArray<CFWorkerScript *> * _Nullable scripts, NSError * _Nullable scriptsError) {
                self.scriptsByAccount[accountID] = scriptsError ? @[] : (scripts ?: @[]);
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

- (NSArray<CFWorkerScript *> *)scriptsForSection:(NSInteger)section {
    if (section >= (NSInteger)self.accounts.count) {
        return @[];
    }
    NSString *accountID = self.accounts[section][@"id"];
    return self.scriptsByAccount[accountID] ?: @[];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.accounts.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX([self scriptsForSection:section].count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < (NSInteger)self.accounts.count) {
        return [self.accounts[section][@"name"] uppercaseString];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (@available(iOS 26.0, *)) {
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        cell.backgroundColor = [UIColor cf_secondaryBackgroundColor];
        cell.textLabel.textColor = [UIColor cf_primaryTextColor];
        cell.detailTextLabel.textColor = [UIColor cf_secondaryTextColor];
    }

    NSArray<CFWorkerScript *> *scripts = [self scriptsForSection:indexPath.section];
    if (scripts.count == 0) {
        cell.textLabel.text = @"No Worker scripts";
        cell.detailTextLabel.text = @"Create scripts in Cloudflare or deploy with Wrangler.";
        cell.imageView.image = nil;
        return cell;
    }

    CFWorkerScript *script = scripts[indexPath.row];
    cell.textLabel.text = script.name;
    cell.detailTextLabel.text = script.modifiedOn.length > 0 ? [NSString stringWithFormat:@"Modified %@", script.modifiedOn] : @"Worker script";
    cell.imageView.image = [UIImage systemImageNamed:@"bolt.fill"];
    cell.imageView.tintColor = [UIColor systemOrangeColor];
    return cell;
}

@end
