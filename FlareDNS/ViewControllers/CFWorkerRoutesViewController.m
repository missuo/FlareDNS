//
//  CFWorkerRoutesViewController.m
//  FlareDNS
//

#import "CFWorkerRoutesViewController.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

@interface CFWorkerRoutesViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) CFZone *zone;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, copy) NSArray<CFWorkerRoute *> *routes;
@property (nonatomic, copy) NSArray<CFWorkerScript *> *scripts;   // account scripts, used to suggest a name when adding

@end

@implementation CFWorkerRoutesViewController

- (instancetype)initWithZone:(CFZone *)zone {
    self = [super init];
    if (self) {
        _zone = zone;
        _routes = @[];
        _scripts = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Worker Routes";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addRouteTapped)];
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

- (void)loadData {
    [self.activityIndicator startAnimating];
    dispatch_group_t group = dispatch_group_create();
    __block NSError *firstError = nil;

    dispatch_group_enter(group);
    [[CFAPIService shared] fetchWorkerRoutesForZoneID:self.zone.zoneID completion:^(NSArray<CFWorkerRoute *> * _Nullable routes, NSError * _Nullable error) {
        if (!error) {
            self.routes = routes ?: @[];
        } else if (!firstError) {
            firstError = error;
        }
        dispatch_group_leave(group);
    }];

    // Account scripts are only used to pre-fill the script field when adding a
    // route; failure here is non-fatal.
    if (self.zone.accountID.length > 0) {
        dispatch_group_enter(group);
        [[CFAPIService shared] fetchWorkerScriptsForAccountID:self.zone.accountID completion:^(NSArray<CFWorkerScript *> * _Nullable scripts, NSError * _Nullable error) {
            if (!error) {
                self.scripts = scripts ?: @[];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self.activityIndicator stopAnimating];
        [self.tableView reloadData];
        if (firstError) {
            [self showAlertWithTitle:@"Error" message:firstError.localizedDescription];
        }
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(self.routes.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"WORKER ROUTES";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Routes bind URL patterns on this zone to Worker scripts. Swipe a route to delete it.";
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

    if (self.routes.count == 0) {
        cell.textLabel.text = @"No routes";
        cell.detailTextLabel.text = @"Use + to bind a pattern to a Worker.";
        cell.imageView.image = nil;
        return cell;
    }

    CFWorkerRoute *route = self.routes[indexPath.row];
    cell.textLabel.text = route.pattern;
    cell.detailTextLabel.text = route.scriptName.length > 0 ? route.scriptName : @"No script";
    cell.imageView.image = [UIImage systemImageNamed:@"point.3.connected.trianglepath.dotted"];
    cell.imageView.tintColor = [UIColor systemBlueColor];
    return cell;
}

#pragma mark - UITableViewDelegate

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.routes.count) {
        return nil;
    }

    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(__unused UIContextualAction * _Nonnull action, __unused UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        CFWorkerRoute *route = self.routes[indexPath.row];
        [[CFAPIService shared] deleteWorkerRouteWithID:route.routeID forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
            if (error) {
                [self showAlertWithTitle:@"Error" message:error.localizedDescription];
                completionHandler(NO);
            } else {
                [self loadData];
                completionHandler(YES);
            }
        }];
    }];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma mark - Actions

- (void)addRouteTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add Worker Route"
                                                                   message:@"Bind a URL pattern to a Worker script."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = [NSString stringWithFormat:@"%@/*", self.zone.name];
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = self.scripts.firstObject.name ?: @"worker-script-name";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
        NSString *pattern = [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *scriptName = [alert.textFields[1].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (pattern.length == 0 || scriptName.length == 0) {
            [self showAlertWithTitle:@"Error" message:@"Pattern and script name are required."];
            return;
        }

        [[CFAPIService shared] createWorkerRouteForZoneID:self.zone.zoneID pattern:pattern scriptName:scriptName completion:^(CFWorkerRoute * _Nullable route, NSError * _Nullable error) {
            if (error) {
                [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            } else {
                [self loadData];
            }
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
