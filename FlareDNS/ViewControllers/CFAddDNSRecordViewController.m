//
//  CFAddDNSRecordViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFAddDNSRecordViewController.h"
#import "CFAPIService.h"
#import "UIColor+FlareDNS.h"

@interface CFAddDNSRecordViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) CFZone *zone;
@property (nonatomic, strong, nullable) CFDNSRecord *existingRecord;
@property (nonatomic, strong) NSArray<CFDNSRecord *> *existingRecords;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

// Form fields
@property (nonatomic, assign) CFDNSRecordType recordType;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) NSInteger ttl;
@property (nonatomic, assign) BOOL proxied;

// Suggestions
@property (nonatomic, strong) NSArray<NSDictionary *> *suggestions;

@end

@implementation CFAddDNSRecordViewController

- (instancetype)initWithZone:(CFZone *)zone record:(nullable CFDNSRecord *)record existingRecords:(NSArray<CFDNSRecord *> *)existingRecords {
    self = [super init];
    if (self) {
        _zone = zone;
        _existingRecord = record;
        _existingRecords = existingRecords ?: @[];
        _suggestions = @[];

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
    [self rebuildSuggestions];

    // Add tap gesture to dismiss keyboard
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
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
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
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
    return (self.suggestions.count > 0) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 1) {
        return self.suggestions.count;
    }
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

    if (indexPath.section == 1) {
        // Suggestions section
        NSDictionary *suggestion = self.suggestions[indexPath.row];
        cell.textLabel.text = suggestion[@"content"];
        cell.detailTextLabel.text = nil;

        // Styled percentage badge
        CGFloat percentage = [suggestion[@"percentage"] doubleValue];
        NSString *percentText = [NSString stringWithFormat:@"%.0f%%", percentage];

        UILabel *badgeLabel = [[UILabel alloc] init];
        badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        badgeLabel.text = percentText;
        badgeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
        badgeLabel.textAlignment = NSTextAlignmentCenter;

        if (@available(iOS 26.0, *)) {
            badgeLabel.textColor = [UIColor secondaryLabelColor];
            badgeLabel.backgroundColor = [UIColor tertiarySystemFillColor];
        } else {
            badgeLabel.textColor = [UIColor cf_secondaryTextColor];
            badgeLabel.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.12];
        }
        badgeLabel.layer.cornerRadius = 4;
        badgeLabel.clipsToBounds = YES;

        // Intrinsic content size + padding
        badgeLabel.layer.sublayerTransform = CATransform3DIdentity;
        [cell.contentView addSubview:badgeLabel];

        [NSLayoutConstraint activateConstraints:@[
            [badgeLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [badgeLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:36],
            [badgeLabel.heightAnchor constraintEqualToConstant:22]
        ]];

        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

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
    
    // Text field for subdomain (only accepts subdomain or @)
    UITextField *textField = [[UITextField alloc] init];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.text = [self.name isEqualToString:@"@"] ? @"" : self.name;
    textField.placeholder = @"@ or subdomain";
    if (@available(iOS 26.0, *)) {
        textField.textColor = [UIColor labelColor];
    } else {
        textField.textColor = [UIColor cf_primaryTextColor];
    }
    textField.textAlignment = NSTextAlignmentRight;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.returnKeyType = UIReturnKeyNext;
    textField.delegate = self;
    textField.tag = 1;
    [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    UIColor *placeholderColor;
    if (@available(iOS 26.0, *)) {
        placeholderColor = [UIColor tertiaryLabelColor];
    } else {
        placeholderColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"@ or subdomain" attributes:@{NSForegroundColorAttributeName: placeholderColor}];
    
    [cell.contentView addSubview:textField];
    
    // Full domain preview label (below text field)
    UILabel *previewLabel = [[UILabel alloc] init];
    previewLabel.translatesAutoresizingMaskIntoConstraints = NO;
    previewLabel.tag = 100; // Tag to find it later for updates
    previewLabel.font = [UIFont systemFontOfSize:12];
    if (@available(iOS 26.0, *)) {
        previewLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        previewLabel.textColor = [UIColor cf_secondaryTextColor];
    }
    previewLabel.textAlignment = NSTextAlignmentRight;
    [cell.contentView addSubview:previewLabel];
    
    // Update preview
    [self updateNamePreview:previewLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [textField.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor constant:-8],
        [textField.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [textField.leadingAnchor constraintGreaterThanOrEqualToAnchor:cell.textLabel.trailingAnchor constant:16],
        
        [previewLabel.topAnchor constraintEqualToAnchor:textField.bottomAnchor constant:4],
        [previewLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [previewLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:cell.textLabel.trailingAnchor constant:16]
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
    textField.returnKeyType = UIReturnKeyDone;
    textField.delegate = self;
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return @"Suggestions";
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        // Tapped a suggestion — fill content field
        NSDictionary *suggestion = self.suggestions[indexPath.row];
        self.content = suggestion[@"content"];

        // Update the content text field in the form
        NSIndexPath *contentIndexPath = [NSIndexPath indexPathForRow:2 inSection:0];
        UITableViewCell *contentCell = [self.tableView cellForRowAtIndexPath:contentIndexPath];
        if (contentCell) {
            for (UIView *subview in contentCell.contentView.subviews) {
                if ([subview isKindOfClass:[UITextField class]] && ((UITextField *)subview).tag == 2) {
                    ((UITextField *)subview).text = self.content;
                    break;
                }
            }
        }
        return;
    }

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
            [self rebuildSuggestions];
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
        NSString *input = textField.text;
        
        // Auto-remove domain suffix if user accidentally includes it
        NSString *zoneSuffix = [NSString stringWithFormat:@".%@", self.zone.name];
        if ([input hasSuffix:zoneSuffix]) {
            input = [input substringToIndex:input.length - zoneSuffix.length];
            textField.text = input;
        }
        
        // If input equals zone name, treat as root domain
        if ([input isEqualToString:self.zone.name]) {
            input = @"@";
            textField.text = @"@";
        }
        
        self.name = input;
        
        // Update preview label
        UITableViewCell *nameCell = (UITableViewCell *)textField.superview.superview;
        if ([nameCell isKindOfClass:[UITableViewCell class]]) {
            UILabel *previewLabel = [nameCell.contentView viewWithTag:100];
            if (previewLabel) {
                [self updateNamePreview:previewLabel];
            }
        }
    } else if (textField.tag == 2) {
        self.content = textField.text;
    }
}

- (void)updateNamePreview:(UILabel *)previewLabel {
    NSString *inputName = [self.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *fullName;
    
    if (inputName.length == 0 || [inputName isEqualToString:@"@"]) {
        fullName = self.zone.name;
    } else {
        fullName = [NSString stringWithFormat:@"%@.%@", inputName, self.zone.name];
    }
    
    previewLabel.text = [NSString stringWithFormat:@"→ %@", fullName];
}

#pragma mark - Switch

- (void)proxySwitchChanged:(UISwitch *)sender {
    self.proxied = sender.on;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.tag == 1) {
        // Name field - move to Content field
        // Find Content textField in the table view
        NSIndexPath *contentIndexPath = [NSIndexPath indexPathForRow:2 inSection:0];
        UITableViewCell *contentCell = [self.tableView cellForRowAtIndexPath:contentIndexPath];
        if (contentCell) {
            UITextField *contentTextField = nil;
            for (UIView *subview in contentCell.contentView.subviews) {
                if ([subview isKindOfClass:[UITextField class]] && ((UITextField *)subview).tag == 2) {
                    contentTextField = (UITextField *)subview;
                    break;
                }
            }
            if (contentTextField) {
                [contentTextField becomeFirstResponder];
            } else {
                [textField resignFirstResponder];
            }
        } else {
            [textField resignFirstResponder];
        }
    } else if (textField.tag == 2) {
        // Content field - dismiss keyboard
        [textField resignFirstResponder];
    }
    return YES;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - Suggestions

- (void)rebuildSuggestions {
    // Only show suggestions for A, AAAA, and CNAME record types
    if (self.recordType != CFDNSRecordTypeA && self.recordType != CFDNSRecordTypeAAAA && self.recordType != CFDNSRecordTypeCNAME) {
        self.suggestions = @[];
        return;
    }

    // Count occurrences of each content value for the current record type
    NSCountedSet *contentCounts = [[NSCountedSet alloc] init];
    for (CFDNSRecord *record in self.existingRecords) {
        if (record.type == self.recordType && record.content.length > 0) {
            [contentCounts addObject:record.content];
        }
    }

    if (contentCounts.count == 0) {
        self.suggestions = @[];
        return;
    }

    // Calculate total count for percentage
    NSUInteger totalCount = 0;
    for (NSString *content in contentCounts) {
        totalCount += [contentCounts countForObject:content];
    }

    // Build array of {content, percentage} dictionaries sorted by percentage descending
    NSMutableArray<NSDictionary *> *results = [NSMutableArray array];
    for (NSString *content in contentCounts) {
        NSUInteger count = [contentCounts countForObject:content];
        CGFloat percentage = (totalCount > 0) ? (count * 100.0 / totalCount) : 0;
        [results addObject:@{
            @"content": content,
            @"percentage": @(percentage)
        }];
    }

    [results sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"percentage"] compare:a[@"percentage"]];
    }];

    self.suggestions = [results copy];
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
