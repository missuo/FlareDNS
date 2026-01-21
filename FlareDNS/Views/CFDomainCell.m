//
//  CFDomainCell.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFDomainCell.h"
#import "UIColor+FlareDNS.h"

@interface CFDomainCell ()

@property (nonatomic, strong, readwrite) UIImageView *globeImageView;
@property (nonatomic, strong, readwrite) UILabel *domainLabel;

@end

@implementation CFDomainCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // Adapt colors based on iOS version
    if (@available(iOS 26.0, *)) {
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        self.backgroundColor = [UIColor cf_secondaryBackgroundColor];
    }
    
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    // Globe icon
    self.globeImageView = [[UIImageView alloc] init];
    self.globeImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.globeImageView.image = [UIImage systemImageNamed:@"globe"];
    self.globeImageView.tintColor = [UIColor systemBlueColor];
    self.globeImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.globeImageView];
    
    // Domain label
    self.domainLabel = [[UILabel alloc] init];
    self.domainLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.domainLabel.font = [UIFont systemFontOfSize:17];
    if (@available(iOS 26.0, *)) {
        self.domainLabel.textColor = [UIColor labelColor];
    } else {
        self.domainLabel.textColor = [UIColor cf_primaryTextColor];
    }
    [self.contentView addSubview:self.domainLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.globeImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.globeImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.globeImageView.widthAnchor constraintEqualToConstant:28],
        [self.globeImageView.heightAnchor constraintEqualToConstant:28],
        
        [self.domainLabel.leadingAnchor constraintEqualToAnchor:self.globeImageView.trailingAnchor constant:14],
        [self.domainLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.domainLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8]
    ]];
    
}

- (void)configureWithZone:(CFZone *)zone {
    self.domainLabel.text = zone.name;
}

@end
