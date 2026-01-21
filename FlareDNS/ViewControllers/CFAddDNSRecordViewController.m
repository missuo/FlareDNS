//
//  CFAddDNSRecordViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFAddDNSRecordViewController.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

@interface CFAddDNSRecordViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) CFZone *zone;
@property (nonatomic, strong, nullable) CFDNSRecord *existingRecord;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

// Form fields
@property (nonatomic, assign) CFDNSRecordType recordType;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) NSInteger ttl;
@property (nonatomic, assign) BOOL proxied;

@end

@implementation CFAddDNSRecordViewController

- (instancetype)initWithZone:(CFZone *)zone record:(nullable CFDNSRecord *)record {
    self = [super init];
    if (self) {
        _zone = zone;
        _existingRecord = record;
        
        if (record) {
            _recordType = record.type;
            _content = record.content;
            _ttl = record.ttl;
            _proxied = record.proxied;
            
            // Strip domain suffix from name for display
            // e.g., "auth.owo.nz" -> "auth", "owo.nz" -> "@"
            NSString *fullName = record.name;
            NSString *zoneName = zone.name;
            
            if ([fullName isEqualToString:zoneName]) {
                // Root domain
                _name = @"@";
            } else if ([fullName hasSuffix:[NSString stringWithFormat:@".%@", zoneName]]) {
                // Subdomain - strip the suffix
                _name = [fullName substringToIndex:fullName.length - zoneName.length - 1];
            } else {
                // Fallback - use full name
                _name = fullName;
            }
        } else {
            _recordType = CFDNSRecordTypeA;
            _name = @"";
            _content = @"";
            _ttl = 1; // Auto
            _proxied = YES;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)setupUI {
    // Adapt colors based on iOS version
    // Use grouped background so cells stand out
    UIColor *backgroundColor;
    
    if (@available(iOS 26.0, *)) {
        backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        backgroundColor = [UIColor cf_primaryBackgroundColor];
    }
    
    self.view.backgroundColor = backgroundColor;
    
    self.title = self.existingRecord ? @"Edit DNS Record" : @"Add DNS Record";
    
    // Cancel button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(cancelButtonTapped)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    // Add/Save button
    NSString *saveTitle = self.existingRecord ? @"Save" : @"Add";
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:saveTitle
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(saveButtonTapped)];
    self.navigationItem.rightBarButtonItem = saveButton;
    
    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = backgroundColor;
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

#pragma mark - Actions

- (void)cancelButtonTapped {
    [self.delegate addDNSRecordViewControllerDidCancel:self];
}

- (void)saveButtonTapped {
    if (self.content.length == 0) {
        [self showAlertWithTitle:@"Error" message:@"Please fill in the content field."];
        return;
    }
    
    [self.activityIndicator startAnimating];
    self.view.userInteractionEnabled = NO;
    
    // Construct full name from subdomain input
    // "@" or empty -> zone name (root domain)
    // "subdomain" -> "subdomain.zone.name"
    NSString *fullName;
    NSString *inputName = [self.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (inputName.length == 0 || [inputName isEqualToString:@"@"]) {
        fullName = self.zone.name;
    } else {
        fullName = [NSString stringWithFormat:@"%@.%@", inputName, self.zone.name];
    }
    
    CFDNSRecord *record = [[CFDNSRecord alloc] init];
    record.type = self.recordType;
    record.name = fullName;
    record.content = self.content;
    record.ttl = self.ttl;
    record.proxied = self.proxied;
    
    if (self.existingRecord) {
        record.recordID = self.existingRecord.recordID;
        [[CFAPIService shared] updateDNSRecord:record forZoneID:self.zone.zoneID completion:^(CFDNSRecord * _Nullable result, NSError * _Nullable error) {
            [self.activityIndicator stopAnimating];
            self.view.userInteractionEnabled = YES;
            
            if (error) {
                [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            } else {
                [self.delegate addDNSRecordViewControllerDidSave:self];
            }
        }];
    } else {
        [[CFAPIService shared] createDNSRecord:record forZoneID:self.zone.zoneID completion:^(CFDNSRecord * _Nullable result, NSError * _Nullable error) {
            [self.activityIndicator stopAnimating];
            self.view.userInteractionEnabled = YES;
            
            if (error) {
                [self showAlertWithTitle:@"Error" message:error.localizedDescription];
            } else {
                [self.delegate addDNSRecordViewControllerDidSave:self];
            }
        }];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 5;
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
    
    switch (indexPath.row) {
        case 0: // Record Type
            [self configureRecordTypeCell:cell];
            break;
        case 1: // Name
            [self configureNameCell:cell];
            break;
        case 2: // Content
            [self configureContentCell:cell];
            break;
        case 3: // TTL
            [self configureTTLCell:cell];
            break;
        case 4: // Proxy Status
            [self configureProxyCell:cell];
            break;
    }
    
    return cell;
}

- (void)configureRecordTypeCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Record Type";
    cell.detailTextLabel.text = [CFDNSRecord stringFromType:self.recordType];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)configureNameCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Name";
    
    // Domain suffix label
    UILabel *suffixLabel = [[UILabel alloc] init];
    suffixLabel.translatesAutoresizingMaskIntoConstraints = NO;
    suffixLabel.text = [NSString stringWithFormat:@".%@", self.zone.name];
    suffixLabel.font = [UIFont systemFontOfSize:16];
    if (@available(iOS 26.0, *)) {
        suffixLabel.textColor = [UIColor tertiaryLabelColor];
    } else {
        suffixLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    [cell.contentView addSubview:suffixLabel];
    
    // Text field for subdomain
    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.text = [self.name isEqualToString:@"@"] ? @"" : self.name;
    textField.placeholder = @"@ for root";
    if (@available(iOS 26.0, *)) {
        textField.textColor = [UIColor labelColor];
    } else {
        textField.textColor = [UIColor cf_primaryTextColor];
    }
    textField.textAlignment = NSTextAlignmentRight;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.tag = 1;
    [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UIColor *placeholderColor;
    if (@available(iOS 26.0, *)) {
        placeholderColor = [UIColor tertiaryLabelColor];
    } else {
        placeholderColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"@ for root" attributes:@{NSForegroundColorAttributeName: placeholderColor}];
    
    [cell.contentView addSubview:textField];
    
    [NSLayoutConstraint activateConstraints:@[
        [suffixLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [suffixLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        
        [textField.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:suffixLabel.leadingAnchor constant:-2],
        [textField.widthAnchor constraintEqualToConstant:120]
    ]];
}

- (void)configureContentCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Content";
    
    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.text = self.content;
    textField.placeholder = @"IP address or value";
    if (@available(iOS 26.0, *)) {
        textField.textColor = [UIColor labelColor];
    } else {
        textField.textColor = [UIColor cf_primaryTextColor];
    }
    textField.textAlignment = NSTextAlignmentRight;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.tag = 2;
    [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UIColor *placeholderColor;
    if (@available(iOS 26.0, *)) {
        placeholderColor = [UIColor tertiaryLabelColor];
    } else {
        placeholderColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"IP address or value" attributes:@{NSForegroundColorAttributeName: placeholderColor}];
    
    [cell.contentView addSubview:textField];
    
    [NSLayoutConstraint activateConstraints:@[
        [textField.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [textField.widthAnchor constraintEqualToConstant:200]
    ]];
}

- (void)configureTTLCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"TTL";
    cell.detailTextLabel.text = (self.ttl == 1) ? @"Auto" : [NSString stringWithFormat:@"%ld", (long)self.ttl];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)configureProxyCell:(UITableViewCell *)cell {
    cell.textLabel.text = @"Proxy Status";
    
    UISwitch *proxySwitch = [[UISwitch alloc] init];
    proxySwitch.on = self.proxied;
    proxySwitch.onTintColor = [UIColor cf_greenColor];
    [proxySwitch addTarget:self action:@selector(proxySwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = proxySwitch;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        [self showRecordTypePicker];
    } else if (indexPath.row == 3) {
        [self showTTLPicker];
    }
}

#pragma mark - Pickers

- (void)showRecordTypePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Record Type" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *types = [CFDNSRecord allRecordTypeStrings];
    for (NSString *typeStr in types) {
        CFDNSRecordType type = [CFDNSRecord typeFromString:typeStr];
        UIAlertAction *action = [UIAlertAction actionWithTitle:typeStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.recordType = type;
            [self.tableView reloadData];
        }];
        
        if (type == self.recordType) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showTTLPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"TTL" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *ttlValues = @[@1, @60, @120, @300, @600, @900, @1800, @3600, @7200, @18000, @43200, @86400];
    NSArray *ttlLabels = @[@"Auto", @"1 min", @"2 min", @"5 min", @"10 min", @"15 min", @"30 min", @"1 hr", @"2 hr", @"5 hr", @"12 hr", @"1 day"];
    
    for (NSInteger i = 0; i < ttlValues.count; i++) {
        NSInteger ttlValue = [ttlValues[i] integerValue];
        UIAlertAction *action = [UIAlertAction actionWithTitle:ttlLabels[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.ttl = ttlValue;
            [self.tableView reloadData];
        }];
        
        if (ttlValue == self.ttl) {
            [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
        }
        
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Text Field

- (void)textFieldDidChange:(UITextField *)textField {
    if (textField.tag == 1) {
        self.name = textField.text;
    } else if (textField.tag == 2) {
        self.content = textField.text;
    }
}

#pragma mark - Switch

- (void)proxySwitchChanged:(UISwitch *)sender {
    self.proxied = sender.on;
}

#pragma mark - Helpers

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
