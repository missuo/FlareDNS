//
//  CFDNSRecordCell.m
//  FlareDNS
//
//  Created by Vincent Yang on 1/21/26.
//

#import "CFDNSRecordCell.h"
#import "UIColor+FlareDNS.h"

@interface CFDNSRecordCell ()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *typeLabel;
@property (nonatomic, strong) UIImageView *proxyStatusIcon;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation CFDNSRecordCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // Adapt colors based on iOS version
    UIColor *primaryText;
    UIColor *secondaryText;
    
    if (@available(iOS 26.0, *)) {
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        primaryText = [UIColor labelColor];
        secondaryText = [UIColor secondaryLabelColor];
    } else {
        self.backgroundColor = [UIColor cf_secondaryBackgroundColor];
        primaryText = [UIColor cf_primaryTextColor];
        secondaryText = [UIColor cf_secondaryTextColor];
    }
    
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    // Name label
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [UIFont systemFontOfSize:17];
    self.nameLabel.textColor = primaryText;
    [self.contentView addSubview:self.nameLabel];
    
    // Content label
    self.contentLabel = [[UILabel alloc] init];
    self.contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentLabel.font = [UIFont systemFontOfSize:15];
    self.contentLabel.textColor = secondaryText;
    [self.contentView addSubview:self.contentLabel];
    
    // Proxy status icon
    self.proxyStatusIcon = [[UIImageView alloc] init];
    self.proxyStatusIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.proxyStatusIcon.image = [UIImage systemImageNamed:@"shield.fill"];
    self.proxyStatusIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:self.proxyStatusIcon];
    
    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = secondaryText;
    [self.contentView addSubview:self.statusLabel];
    
    // Type label - use a wrapper view for consistent sizing
    self.typeLabel = [[UILabel alloc] init];
    self.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.typeLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold];
    self.typeLabel.textColor = [UIColor systemBlueColor];
    self.typeLabel.textAlignment = NSTextAlignmentCenter;
    self.typeLabel.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.12];
    self.typeLabel.layer.cornerRadius = 6;
    self.typeLabel.clipsToBounds = YES;
    [self.contentView addSubview:self.typeLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        // Name label
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.typeLabel.leadingAnchor constant:-12],
        
        // Content label
        [self.contentLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],
        [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.contentLabel.trailingAnchor constraintEqualToAnchor:self.typeLabel.leadingAnchor constant:-12],
        
        // Proxy status icon
        [self.proxyStatusIcon.topAnchor constraintEqualToAnchor:self.contentLabel.bottomAnchor constant:4],
        [self.proxyStatusIcon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.proxyStatusIcon.widthAnchor constraintEqualToConstant:14],
        [self.proxyStatusIcon.heightAnchor constraintEqualToConstant:14],
        [self.proxyStatusIcon.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        
        // Status label
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.proxyStatusIcon.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.proxyStatusIcon.trailingAnchor constant:6],
        
        // Type label - fixed width for consistency
        [self.typeLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.typeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.typeLabel.widthAnchor constraintEqualToConstant:56],
        [self.typeLabel.heightAnchor constraintEqualToConstant:24]
    ]];
}

- (void)configureWithRecord:(CFDNSRecord *)record {
    self.nameLabel.text = record.name;
    self.contentLabel.text = record.content;
    self.typeLabel.text = [CFDNSRecord stringFromType:record.type];
    
    if (record.proxied) {
        self.proxyStatusIcon.tintColor = [UIColor cf_orangeColor];
        self.statusLabel.text = [NSString stringWithFormat:@"Proxied  TTL: %@", record.ttl == 1 ? @"Auto" : [NSString stringWithFormat:@"%ld", (long)record.ttl]];
    } else {
        self.proxyStatusIcon.tintColor = [UIColor cf_secondaryTextColor];
        self.statusLabel.text = [NSString stringWithFormat:@"DNS only  TTL: %@", record.ttl == 1 ? @"Auto" : [NSString stringWithFormat:@"%ld", (long)record.ttl]];
    }
}

@end
