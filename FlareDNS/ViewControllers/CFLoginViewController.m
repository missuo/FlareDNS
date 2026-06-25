//
//  CFLoginViewController.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFLoginViewController.h"
#import "CFAPIService.h"
#import "CFKeychainService.h"
#import "UIColor+FlareDNS.h"

@interface CFLoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *formContainerView;
@property (nonatomic, strong) UILabel *accountDetailsLabel;
@property (nonatomic, strong) UILabel *emailLabel;
@property (nonatomic, strong) UITextField *emailTextField;
@property (nonatomic, strong) UILabel *apiKeyLabel;
@property (nonatomic, strong) UITextField *apiKeyTextField;
@property (nonatomic, strong) UILabel *apiKeyHintLabel;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIView *loginContainerView;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *helpButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation CFLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupConstraints];
    [self loadSavedCredentials];
    
    // Add tap gesture to dismiss keyboard
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
}

- (void)setupUI {
    // Determine colors based on iOS version
    UIColor *backgroundColor;
    UIColor *secondaryBackground;
    UIColor *primaryText;
    UIColor *secondaryText;
    
    if (@available(iOS 26.0, *)) {
        backgroundColor = [UIColor systemGroupedBackgroundColor];
        secondaryBackground = [UIColor secondarySystemGroupedBackgroundColor];
        primaryText = [UIColor labelColor];
        secondaryText = [UIColor secondaryLabelColor];
    } else {
        backgroundColor = [UIColor cf_primaryBackgroundColor];
        secondaryBackground = [UIColor cf_secondaryBackgroundColor];
        primaryText = [UIColor cf_primaryTextColor];
        secondaryText = [UIColor cf_secondaryTextColor];
    }
    
    self.view.backgroundColor = backgroundColor;
    
    // Scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];
    
    // Logo
    self.logoImageView = [[UIImageView alloc] init];
    self.logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    NSString *iconName = [[NSBundle mainBundle].infoDictionary[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"] lastObject];
    UIImage *appIcon = iconName ? [UIImage imageNamed:iconName] : [UIImage systemImageNamed:@"cloud.fill"];
    self.logoImageView.image = appIcon;
    self.logoImageView.layer.cornerRadius = 20;
    self.logoImageView.clipsToBounds = YES;
    [self.scrollView addSubview:self.logoImageView];
    
    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"Cloudflare DNS Manager";
    self.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    self.titleLabel.textColor = primaryText;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:self.titleLabel];
    
    // Subtitle
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.text = @"Manage your Cloudflare DNS services";
    self.subtitleLabel.font = [UIFont systemFontOfSize:15];
    self.subtitleLabel.textColor = secondaryText;
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:self.subtitleLabel];
    
    // Account Details Label
    self.accountDetailsLabel = [[UILabel alloc] init];
    self.accountDetailsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.accountDetailsLabel.text = @"ACCOUNT DETAILS";
    self.accountDetailsLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.accountDetailsLabel.textColor = secondaryText;
    [self.scrollView addSubview:self.accountDetailsLabel];
    
    // Form Container
    self.formContainerView = [[UIView alloc] init];
    self.formContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formContainerView.backgroundColor = secondaryBackground;
    self.formContainerView.layer.cornerRadius = 12;
    [self.scrollView addSubview:self.formContainerView];
    
    // Email Label
    self.emailLabel = [[UILabel alloc] init];
    self.emailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emailLabel.text = @"Email";
    self.emailLabel.font = [UIFont systemFontOfSize:13];
    self.emailLabel.textColor = secondaryText;
    [self.formContainerView addSubview:self.emailLabel];
    
    // Email TextField
    self.emailTextField = [[UITextField alloc] init];
    self.emailTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.emailTextField.placeholder = @"Required for Global API Key";
    self.emailTextField.font = [UIFont systemFontOfSize:17];
    self.emailTextField.textColor = primaryText;
    self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailTextField.returnKeyType = UIReturnKeyNext;
    self.emailTextField.delegate = self;
    self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Required for Global API Key" attributes:@{NSForegroundColorAttributeName: secondaryText}];
    [self.formContainerView addSubview:self.emailTextField];
    
    // Separator
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor separatorColor];
    separator.tag = 100;
    [self.formContainerView addSubview:separator];
    
    // API Key Label
    self.apiKeyLabel = [[UILabel alloc] init];
    self.apiKeyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.apiKeyLabel.text = @"API Token or Global API Key";
    self.apiKeyLabel.font = [UIFont systemFontOfSize:13];
    self.apiKeyLabel.textColor = secondaryText;
    [self.formContainerView addSubview:self.apiKeyLabel];
    
    // API Key TextField
    self.apiKeyTextField = [[UITextField alloc] init];
    self.apiKeyTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.apiKeyTextField.placeholder = @"Enter your API Token or API Key";
    self.apiKeyTextField.font = [UIFont systemFontOfSize:17];
    self.apiKeyTextField.textColor = primaryText;
    self.apiKeyTextField.secureTextEntry = YES;
    self.apiKeyTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.apiKeyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.apiKeyTextField.returnKeyType = UIReturnKeyDone;
    self.apiKeyTextField.delegate = self;
    self.apiKeyTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter your API Token or API Key" attributes:@{NSForegroundColorAttributeName: secondaryText}];
    [self.formContainerView addSubview:self.apiKeyTextField];
    
    // Paste Button
    self.pasteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pasteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pasteButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    self.pasteButton.tintColor = [UIColor systemBlueColor];
    [self.pasteButton addTarget:self action:@selector(pasteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.formContainerView addSubview:self.pasteButton];
    
    // API Key Hint
    self.apiKeyHintLabel = [[UILabel alloc] init];
    self.apiKeyHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.apiKeyHintLabel.text = @"Leave email empty when using an API Token. Credentials stay on this device.";
    self.apiKeyHintLabel.font = [UIFont systemFontOfSize:13];
    self.apiKeyHintLabel.textColor = secondaryText;
    [self.formContainerView addSubview:self.apiKeyHintLabel];
    
    // Determine accent color based on iOS version
    UIColor *accentColor;
    UIColor *separatorColor;
    if (@available(iOS 26.0, *)) {
        accentColor = [UIColor systemBlueColor];
        separatorColor = [UIColor separatorColor];
    } else {
        accentColor = [UIColor cf_accentColor];
        separatorColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    }
    
    // Login Container
    self.loginContainerView = [[UIView alloc] init];
    self.loginContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginContainerView.backgroundColor = secondaryBackground;
    self.loginContainerView.layer.cornerRadius = 12;
    [self.scrollView addSubview:self.loginContainerView];
    
    // Login Button
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loginButton setTitle:@"Login" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:accentColor forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont systemFontOfSize:17];
    self.loginButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.loginButton addTarget:self action:@selector(loginButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.loginContainerView addSubview:self.loginButton];
    
    // Arrow for login
    UIImageView *loginArrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.right"]];
    loginArrow.translatesAutoresizingMaskIntoConstraints = NO;
    loginArrow.contentMode = UIViewContentModeScaleAspectFit;
    loginArrow.tintColor = accentColor;
    loginArrow.tag = 101;
    [self.loginContainerView addSubview:loginArrow];
    
    // Separator for login container
    UIView *loginSeparator = [[UIView alloc] init];
    loginSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    loginSeparator.backgroundColor = separatorColor;
    loginSeparator.tag = 102;
    [self.loginContainerView addSubview:loginSeparator];
    
    // Help Button
    self.helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.helpButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSMutableAttributedString *helpText = [[NSMutableAttributedString alloc] init];
    NSTextAttachment *helpIcon = [[NSTextAttachment alloc] init];
    helpIcon.image = [[UIImage systemImageNamed:@"questionmark.circle.fill"] imageWithTintColor:accentColor];
    helpIcon.bounds = CGRectMake(0, -3, 18, 18);
    [helpText appendAttributedString:[NSAttributedString attributedStringWithAttachment:helpIcon]];
    [helpText appendAttributedString:[[NSAttributedString alloc] initWithString:@"  How to Get API Token" attributes:@{NSForegroundColorAttributeName: accentColor, NSFontAttributeName: [UIFont systemFontOfSize:17]}]];
    
    [self.helpButton setAttributedTitle:helpText forState:UIControlStateNormal];
    self.helpButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.helpButton addTarget:self action:@selector(helpButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.loginContainerView addSubview:self.helpButton];
    
    // Help arrow
    UIImageView *helpArrow = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    helpArrow.translatesAutoresizingMaskIntoConstraints = NO;
    helpArrow.contentMode = UIViewContentModeScaleAspectFit;
    helpArrow.tintColor = secondaryText;
    helpArrow.tag = 103;
    [self.loginContainerView addSubview:helpArrow];
    
    // Activity Indicator
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
}

- (void)setupConstraints {
    UIView *separator = [self.formContainerView viewWithTag:100];
    UIImageView *loginArrow = (UIImageView *)[self.loginContainerView viewWithTag:101];
    UIView *loginSeparator = [self.loginContainerView viewWithTag:102];
    UIImageView *helpArrow = (UIImageView *)[self.loginContainerView viewWithTag:103];
    
    [NSLayoutConstraint activateConstraints:@[
        // Scroll View
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Logo
        [self.logoImageView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:80],
        [self.logoImageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoImageView.widthAnchor constraintEqualToConstant:100],
        [self.logoImageView.heightAnchor constraintEqualToConstant:100],
        
        // Title
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.logoImageView.bottomAnchor constant:24],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // Subtitle
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // Account Details Label
        [self.accountDetailsLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:40],
        [self.accountDetailsLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:36],
        
        // Form Container
        [self.formContainerView.topAnchor constraintEqualToAnchor:self.accountDetailsLabel.bottomAnchor constant:8],
        [self.formContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.formContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // Email Label
        [self.emailLabel.topAnchor constraintEqualToAnchor:self.formContainerView.topAnchor constant:12],
        [self.emailLabel.leadingAnchor constraintEqualToAnchor:self.formContainerView.leadingAnchor constant:16],
        
        // Email TextField
        [self.emailTextField.topAnchor constraintEqualToAnchor:self.emailLabel.bottomAnchor constant:4],
        [self.emailTextField.leadingAnchor constraintEqualToAnchor:self.formContainerView.leadingAnchor constant:16],
        [self.emailTextField.trailingAnchor constraintEqualToAnchor:self.formContainerView.trailingAnchor constant:-16],
        [self.emailTextField.heightAnchor constraintEqualToConstant:30],
        
        // Separator
        [separator.topAnchor constraintEqualToAnchor:self.emailTextField.bottomAnchor constant:12],
        [separator.leadingAnchor constraintEqualToAnchor:self.formContainerView.leadingAnchor constant:16],
        [separator.trailingAnchor constraintEqualToAnchor:self.formContainerView.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:0.5],
        
        // API Key Label
        [self.apiKeyLabel.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:12],
        [self.apiKeyLabel.leadingAnchor constraintEqualToAnchor:self.formContainerView.leadingAnchor constant:16],
        
        // API Key TextField
        [self.apiKeyTextField.topAnchor constraintEqualToAnchor:self.apiKeyLabel.bottomAnchor constant:4],
        [self.apiKeyTextField.leadingAnchor constraintEqualToAnchor:self.formContainerView.leadingAnchor constant:16],
        [self.apiKeyTextField.trailingAnchor constraintEqualToAnchor:self.pasteButton.leadingAnchor constant:-8],
        [self.apiKeyTextField.heightAnchor constraintEqualToConstant:30],
        
        // Paste Button
        [self.pasteButton.centerYAnchor constraintEqualToAnchor:self.apiKeyTextField.centerYAnchor],
        [self.pasteButton.trailingAnchor constraintEqualToAnchor:self.formContainerView.trailingAnchor constant:-16],
        [self.pasteButton.widthAnchor constraintEqualToConstant:30],
        [self.pasteButton.heightAnchor constraintEqualToConstant:30],
        
        // API Key Hint
        [self.apiKeyHintLabel.topAnchor constraintEqualToAnchor:self.apiKeyTextField.bottomAnchor constant:8],
        [self.apiKeyHintLabel.leadingAnchor constraintEqualToAnchor:self.formContainerView.leadingAnchor constant:16],
        [self.apiKeyHintLabel.trailingAnchor constraintEqualToAnchor:self.formContainerView.trailingAnchor constant:-16],
        [self.apiKeyHintLabel.bottomAnchor constraintEqualToAnchor:self.formContainerView.bottomAnchor constant:-16],
        
        // Login Container
        [self.loginContainerView.topAnchor constraintEqualToAnchor:self.formContainerView.bottomAnchor constant:24],
        [self.loginContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.loginContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.loginContainerView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-40],
        
        // Login Button
        [self.loginButton.topAnchor constraintEqualToAnchor:self.loginContainerView.topAnchor constant:12],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:self.loginContainerView.leadingAnchor constant:16],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:loginArrow.leadingAnchor constant:-8],
        [self.loginButton.heightAnchor constraintEqualToConstant:30],
        
        // Login Arrow
        [loginArrow.centerYAnchor constraintEqualToAnchor:self.loginButton.centerYAnchor],
        [loginArrow.trailingAnchor constraintEqualToAnchor:self.loginContainerView.trailingAnchor constant:-16],
        [loginArrow.widthAnchor constraintEqualToConstant:20],
        [loginArrow.heightAnchor constraintEqualToConstant:20],
        
        // Login Separator
        [loginSeparator.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:12],
        [loginSeparator.leadingAnchor constraintEqualToAnchor:self.loginContainerView.leadingAnchor constant:16],
        [loginSeparator.trailingAnchor constraintEqualToAnchor:self.loginContainerView.trailingAnchor],
        [loginSeparator.heightAnchor constraintEqualToConstant:0.5],
        
        // Help Button
        [self.helpButton.topAnchor constraintEqualToAnchor:loginSeparator.bottomAnchor constant:12],
        [self.helpButton.leadingAnchor constraintEqualToAnchor:self.loginContainerView.leadingAnchor constant:16],
        [self.helpButton.trailingAnchor constraintEqualToAnchor:helpArrow.leadingAnchor constant:-8],
        [self.helpButton.bottomAnchor constraintEqualToAnchor:self.loginContainerView.bottomAnchor constant:-12],
        [self.helpButton.heightAnchor constraintEqualToConstant:30],
        
        // Help Arrow
        [helpArrow.centerYAnchor constraintEqualToAnchor:self.helpButton.centerYAnchor],
        [helpArrow.trailingAnchor constraintEqualToAnchor:self.loginContainerView.trailingAnchor constant:-16],
        [helpArrow.widthAnchor constraintEqualToConstant:20],
        [helpArrow.heightAnchor constraintEqualToConstant:20],
        
        // Activity Indicator
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)loadSavedCredentials {
    CFKeychainService *keychain = [CFKeychainService shared];
    CFAccount *account = [keychain getCurrentAccount];
    NSString *email = account.email;
    NSString *apiKey = account.apiKey;
    
    if (email) {
        self.emailTextField.text = email;
    }
    if (apiKey) {
        self.apiKeyTextField.text = apiKey;
    }
}

#pragma mark - Actions

- (void)pasteButtonTapped {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (pasteboard.string) {
        self.apiKeyTextField.text = pasteboard.string;
    }
}

- (void)loginButtonTapped {
    NSString *email = [self.emailTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *apiKey = [self.apiKeyTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    CFAuthMode authMode = email.length == 0 ? CFAuthModeAPIToken : CFAuthModeGlobalKey;
    
    if (apiKey.length == 0) {
        [self showAlertWithTitle:@"Error" message:@"Please enter an API Token or Global API Key."];
        return;
    }
    
    [self.activityIndicator startAnimating];
    self.view.userInteractionEnabled = NO;
    
    CFAPIService *api = [CFAPIService shared];
    api.email = email;
    api.apiKey = apiKey;
    api.usesAPIToken = (authMode == CFAuthModeAPIToken);
    
    [api verifyCredentialsWithCompletion:^(BOOL success, NSError * _Nullable error) {
        [self.activityIndicator stopAnimating];
        self.view.userInteractionEnabled = YES;
        
        if (success) {
            CFAccount *account = [[CFAccount alloc] initWithEmail:email apiKey:apiKey authMode:authMode];
            [[CFKeychainService shared] addAccount:account];
            [[CFKeychainService shared] setCurrentAccount:account];
            [[CFAPIService shared] configureWithAccount:account];
            [self.delegate loginViewControllerDidLogin:self];
        } else {
            [self showAlertWithTitle:@"Login Failed" message:error.localizedDescription ?: @"Invalid credentials."];
        }
    }];
}

- (void)helpButtonTapped {
    NSString *linkURL = @"https://dash.cloudflare.com/profile/api-tokens";
    NSString *message = [NSString stringWithFormat:@"1. Open %@\n\n2. Create an API Token with Zone, DNS, Workers and KV permissions as needed.\n\n3. Leave email empty when logging in with the token.", linkURL];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"How to Get API Token"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Open Cloudflare" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
        NSURL *url = [NSURL URLWithString:linkURL];
        if (!url) { return; }
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        } else {
            [weakSelf showAlertWithTitle:@"Error" message:@"Unable to open the link on this device."];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.emailTextField) {
        // Move to API Key field
        [self.apiKeyTextField becomeFirstResponder];
    } else if (textField == self.apiKeyTextField) {
        // Dismiss keyboard and attempt login
        [textField resignFirstResponder];
        [self loginButtonTapped];
    }
    return YES;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

@end
