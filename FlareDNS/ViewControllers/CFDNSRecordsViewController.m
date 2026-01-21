//
//  CFDNSRecordsViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFDNSRecordsViewController.h"
#import "CFAddDNSRecordViewController.h"
#import "CFDNSRecordCell.h"
#import "CFAPIService.h"
#import "CFDNSRecord.h"
#import "UIColor+FlareDNS.h"

static NSString *const kRecordCellIdentifier = @"RecordCell";

@interface CFDNSRecordsViewController () <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UISearchBarDelegate, CFAddDNSRecordViewControllerDelegate>

@property (nonatomic, strong) CFZone *zone;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) NSArray<CFDNSRecord *> *records;
@property (nonatomic, strong) NSArray<CFDNSRecord *> *filteredRecords;
@property (nonatomic, assign) BOOL isSearching;

@end

@implementation CFDNSRecordsViewController

- (instancetype)initWithZone:(CFZone *)zone {
    self = [super init];
    if (self) {
        _zone = zone;
        _records = @[];
        _filteredRecords = @[];
        _isSearching = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupUI];
    [self loadRecords];
}

- (void)setupNavigationBar {
    // Use standard navigation bar (gets Liquid Glass on iOS 26+)
    self.title = @"DNS Records";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    
    // Add button (right)
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(addButtonTapped)];
    self.navigationItem.rightBarButtonItem = addItem;
    
    // Search controller
    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    searchController.searchBar.placeholder = @"Search records";
    searchController.searchBar.delegate = self;
    self.navigationItem.searchController = searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
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
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80;
    [self.tableView registerClass:[CFDNSRecordCell class] forCellReuseIdentifier:kRecordCellIdentifier];
    [self.view addSubview:self.tableView];
    
    // Refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadRecords) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;
    
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

- (void)loadRecords {
    if (self.records.count == 0) {
        [self.activityIndicator startAnimating];
    }
    
    [[CFAPIService shared] fetchDNSRecordsForZoneID:self.zone.zoneID completion:^(NSArray<CFDNSRecord *> * _Nullable records, NSError * _Nullable error) {
        [self.activityIndicator stopAnimating];
        [self.refreshControl endRefreshing];
        
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            return;
        }
        
        self.records = records ?: @[];
        self.filteredRecords = self.records;
        [self.tableView reloadData];
    }];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    
    if (searchText.length == 0) {
        self.filteredRecords = self.records;
        self.isSearching = NO;
    } else {
        self.isSearching = YES;
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(CFDNSRecord *record, NSDictionary *bindings) {
            // Search by name, content, or type
            NSString *typeString = [CFDNSRecord stringFromType:record.type];
            return [record.name localizedCaseInsensitiveContainsString:searchText] ||
                   [record.content localizedCaseInsensitiveContainsString:searchText] ||
                   [typeString localizedCaseInsensitiveContainsString:searchText];
        }];
        self.filteredRecords = [self.records filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)backButtonTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)addButtonTapped {
    CFAddDNSRecordViewController *addVC = [[CFAddDNSRecordViewController alloc] initWithZone:self.zone record:nil];
    addVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:addVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CFDNSRecordCell *cell = [tableView dequeueReusableCellWithIdentifier:kRecordCellIdentifier forIndexPath:indexPath];
    CFDNSRecord *record = self.filteredRecords[indexPath.row];
    [cell configureWithRecord:record];
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
    
    CFDNSRecord *record = self.filteredRecords[indexPath.row];
    CFAddDNSRecordViewController *editVC = [[CFAddDNSRecordViewController alloc] initWithZone:self.zone record:record];
    editVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [self deleteRecordAtIndexPath:indexPath];
        completionHandler(YES);
    }];
    
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.01;
}

#pragma mark - CFAddDNSRecordViewControllerDelegate

- (void)addDNSRecordViewControllerDidSave:(CFAddDNSRecordViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
    [self loadRecords];
}

- (void)addDNSRecordViewControllerDidCancel:(CFAddDNSRecordViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Private Methods

- (void)deleteRecordAtIndexPath:(NSIndexPath *)indexPath {
    CFDNSRecord *record = self.filteredRecords[indexPath.row];
    
    [[CFAPIService shared] deleteDNSRecordWithID:record.recordID forZoneID:self.zone.zoneID completion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            [self showAlertWithTitle:@"Error" message:error.localizedDescription];
        } else {
            // Remove from both arrays
            NSMutableArray *mutableRecords = [self.records mutableCopy];
            [mutableRecords removeObject:record];
            self.records = mutableRecords;
            
            NSMutableArray *mutableFiltered = [self.filteredRecords mutableCopy];
            [mutableFiltered removeObjectAtIndex:indexPath.row];
            self.filteredRecords = mutableFiltered;
            
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
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
