//
//  CookieMenuViewController.m
//  CookieManager
//  Beautiful menu UI for cookie management
//

#import "CookieMenuViewController.h"
#import "CookieManager.h"
#import "CookieDeletionService.h"
#import <objc/runtime.h>

@interface CookieMenuViewController ()

@property (strong, nonatomic) UIView *containerView;
@property (strong, nonatomic) UIView *blurBackground;
@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *cookieCountLabel;
@property (strong, nonatomic) UIButton *deleteAllButton;
@property (strong, nonatomic) UIButton *closeButton;
@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) UIStackView *contentStackView;
@property (strong, nonatomic) NSArray<NSHTTPCookie *> *cookies;
@property (strong, nonatomic) UIButton *deleteAppDataButton;
@property (strong, nonatomic) UILabel *appDataSizeLabel;

@end

@implementation CookieMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self loadCookies];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];
    
    // Blur background with forward compatibility for iOS 26+
    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
        self.blurBackground = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    } else if (@available(iOS 10.0, *)) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        self.blurBackground = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    } else {
        self.blurBackground = [[UIView alloc] init];
        self.blurBackground.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    }
    self.blurBackground.frame = self.view.bounds;
    self.blurBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.blurBackground];
    
    // Tap to dismiss
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeButtonTapped)];
    [self.blurBackground addGestureRecognizer:tapGesture];
    
    // Container view with shadow and better styling
    self.containerView = [[UIView alloc] init];
    self.containerView.layer.cornerRadius = 20;
    self.containerView.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        self.containerView.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.containerView.backgroundColor = [UIColor whiteColor];
    }
    
    // Add shadow for depth
    self.containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.containerView.layer.shadowOffset = CGSizeMake(0, 4);
    self.containerView.layer.shadowRadius = 12;
    self.containerView.layer.shadowOpacity = 0.3;
    
    [self.view addSubview:self.containerView];
    
    // Scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.containerView addSubview:self.scrollView];
    
    // Stack view for content
    self.contentStackView = [[UIStackView alloc] init];
    self.contentStackView.axis = UILayoutConstraintAxisVertical;
    self.contentStackView.spacing = 16;
    self.contentStackView.alignment = UIStackViewAlignmentFill;
    [self.scrollView addSubview:self.contentStackView];
    
    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"🍪 Cookie Manager";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:28];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        self.titleLabel.textColor = [UIColor labelColor];
    } else {
        self.titleLabel.textColor = [UIColor blackColor];
    }
    [self.contentStackView addArrangedSubview:self.titleLabel];
    
    // Cookie count label with better styling
    self.cookieCountLabel = [[UILabel alloc] init];
    self.cookieCountLabel.font = [UIFont boldSystemFontOfSize:17];
    self.cookieCountLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        self.cookieCountLabel.textColor = [UIColor labelColor];
    } else {
        self.cookieCountLabel.textColor = [UIColor blackColor];
    }
    self.cookieCountLabel.text = @"Loading cookies...";
    [self.contentStackView addArrangedSubview:self.cookieCountLabel];
    
    // App data size label with better styling
    self.appDataSizeLabel = [[UILabel alloc] init];
    self.appDataSizeLabel.font = [UIFont boldSystemFontOfSize:15];
    self.appDataSizeLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        self.appDataSizeLabel.textColor = [UIColor systemBlueColor];
    } else {
        self.appDataSizeLabel.textColor = [UIColor blueColor];
    }
    self.appDataSizeLabel.text = @"Loading...";
    [self.contentStackView addArrangedSubview:self.appDataSizeLabel];
    
    // Separator view
    UIView *separatorView = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        separatorView.backgroundColor = [UIColor separatorColor];
    } else {
        separatorView.backgroundColor = [UIColor lightGrayColor];
    }
    separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [separatorView.heightAnchor constraintEqualToConstant:1].active = YES;
    [self.contentStackView addArrangedSubview:separatorView];
    
    // Delete all cookies button
    self.deleteAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.deleteAllButton setTitle:@"🗑️ Delete All Cookies" forState:UIControlStateNormal];
    self.deleteAllButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.deleteAllButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        self.deleteAllButton.backgroundColor = [UIColor systemRedColor];
    } else {
        self.deleteAllButton.backgroundColor = [UIColor redColor];
    }
    self.deleteAllButton.layer.cornerRadius = 12;
    self.deleteAllButton.contentEdgeInsets = UIEdgeInsetsMake(14, 20, 14, 20);
    [self.deleteAllButton addTarget:self action:@selector(deleteAllButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentStackView addArrangedSubview:self.deleteAllButton];
    
    // Delete all app data button
    self.deleteAppDataButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.deleteAppDataButton setTitle:@"🗑️ Delete All App Data" forState:UIControlStateNormal];
    self.deleteAppDataButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.deleteAppDataButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        self.deleteAppDataButton.backgroundColor = [UIColor systemOrangeColor];
    } else {
        self.deleteAppDataButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1.0];
    }
    self.deleteAppDataButton.layer.cornerRadius = 12;
    self.deleteAppDataButton.contentEdgeInsets = UIEdgeInsetsMake(14, 20, 14, 20);
    [self.deleteAppDataButton addTarget:self action:@selector(deleteAppDataButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentStackView addArrangedSubview:self.deleteAppDataButton];
    

    // Import all app data button
    UIButton *importCookiesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [importCookiesButton setTitle:@"📥 Import Cookies" forState:UIControlStateNormal];
    importCookiesButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [importCookiesButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    importCookiesButton.backgroundColor = [UIColor systemBlueColor];
    importCookiesButton.layer.cornerRadius = 12;
    importCookiesButton.contentEdgeInsets = UIEdgeInsetsMake(14, 20, 14, 20);
    [importCookiesButton addTarget:self
                        action:@selector(importCookiesTapped)
              forControlEvents:UIControlEventTouchUpInside];

    [self.contentStackView addArrangedSubview:importCookiesButton];

    // keychain
    UIButton *keychainButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [keychainButton setTitle:@"🔐 Keychain" forState:UIControlStateNormal];
    keychainButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [keychainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    keychainButton.backgroundColor = [UIColor systemOrangeColor];
    keychainButton.layer.cornerRadius = 12;
    keychainButton.contentEdgeInsets = UIEdgeInsetsMake(14, 20, 14, 20);
    [keychainButton addTarget:self
                   action:@selector(openKeychainManager)
         forControlEvents:UIControlEventTouchUpInside];

    [self.contentStackView addArrangedSubview:keychainButton];


    // Close button with better styling
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"✕ Close" forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    if (@available(iOS 13.0, *)) {
        [self.closeButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateNormal];
    } else {
        [self.closeButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    }
    self.closeButton.contentEdgeInsets = UIEdgeInsetsMake(12, 20, 12, 20);
    [self.closeButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentStackView addArrangedSubview:self.closeButton];
    
    // Setup constraints
    [self setupConstraints];
}

- (void)setupConstraints {
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Calculate max height (85% of screen height for better use of space)
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat maxHeight = screenHeight * 0.85;
    CGFloat minHeight = 250.0; // Minimum height for small content
    
    // Dynamic width based on screen size (but not too wide on iPad)
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat containerWidth = MIN(380, screenWidth * 0.9);
    
    [NSLayoutConstraint activateConstraints:@[
        // Container view - dynamically sized, centered
        [self.containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.containerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.containerView.widthAnchor constraintEqualToConstant:containerWidth],
        [self.containerView.heightAnchor constraintLessThanOrEqualToConstant:maxHeight],
        [self.containerView.heightAnchor constraintGreaterThanOrEqualToConstant:minHeight],
        
        // Scroll view - proper padding with dynamic content
        [self.scrollView.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:24],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:20],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-20],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-24],
        
        // Stack view - expands with content
        [self.contentStackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentStackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor]
    ]];
    
    // Update container height based on content after layout
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateContainerHeight];
    });
}

- (void)updateContainerHeight {
    // Calculate content height
    [self.contentStackView layoutIfNeeded];
    CGFloat contentHeight = self.contentStackView.frame.size.height;
    
    // Add padding (top + bottom)
    CGFloat totalHeight = contentHeight + 48; // 24 top + 24 bottom
    
    // Get constraints
    CGFloat maxHeight = [UIScreen mainScreen].bounds.size.height * 0.85;
    CGFloat minHeight = 250.0;
    
    // Update height constraint dynamically
    for (NSLayoutConstraint *constraint in self.containerView.constraints) {
        if (constraint.firstAttribute == NSLayoutAttributeHeight && 
            constraint.relation == NSLayoutRelationEqual) {
            [self.containerView removeConstraint:constraint];
        }
    }
    
    // Set new height based on content, but within bounds
    CGFloat newHeight = MAX(minHeight, MIN(totalHeight, maxHeight));
    [self.containerView.heightAnchor constraintEqualToConstant:newHeight].active = YES;
    
    [self.view layoutIfNeeded];
}

- (void)loadCookies {
    self.cookies = [[CookieManager sharedManager] getAllCookies];
    NSInteger count = self.cookies.count;
    
    if (count == 0) {
        self.cookieCountLabel.text = @"No cookies found";
        self.cookieCountLabel.textColor = [UIColor systemGrayColor];
        // Add helpful message
        [self addNoCookiesMessage];
    } else {
        if (@available(iOS 13.0, *)) {
            self.cookieCountLabel.textColor = [UIColor labelColor];
        } else {
            self.cookieCountLabel.textColor = [UIColor blackColor];
        }
        self.cookieCountLabel.text = [NSString stringWithFormat:@"Found %ld cookie%@", (long)count, count == 1 ? @"" : @"s"];
        // Add cookie list if there are cookies
        [self addCookieList];
    }
    
    // Load app data size
    [self updateAppDataSize];
    
    // Update container height after content loads
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateContainerHeight];
    });
}

- (void)addNoCookiesMessage {
    // Remove existing message if any
    for (UIView *view in self.contentStackView.arrangedSubviews) {
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            if ([label.text containsString:@"No cookies"] && label != self.cookieCountLabel) {
                [self.contentStackView removeArrangedSubview:view];
                [view removeFromSuperview];
                break;
            }
        }
    }
    
    UILabel *noCookiesLabel = [[UILabel alloc] init];
    noCookiesLabel.text = @"✅ No cookies stored in this app";
    noCookiesLabel.font = [UIFont systemFontOfSize:15];
    noCookiesLabel.textAlignment = NSTextAlignmentCenter;
    noCookiesLabel.numberOfLines = 0;
    if (@available(iOS 13.0, *)) {
        noCookiesLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        noCookiesLabel.textColor = [UIColor grayColor];
    }
    
    // Insert before close button
    NSInteger insertIndex = MAX(0, self.contentStackView.arrangedSubviews.count - 1);
    [self.contentStackView insertArrangedSubview:noCookiesLabel atIndex:insertIndex];
}

- (void)updateAppDataSize {
    NSUInteger dataSize = [[CookieManager sharedManager] getAppDataSize];
    NSString *sizeString = [self formatBytes:dataSize];
    self.appDataSizeLabel.text = [NSString stringWithFormat:@"App Data: %@", sizeString];
}

- (NSString *)formatBytes:(NSUInteger)bytes {
    double size = (double)bytes;
    NSArray<NSString *> *units = @[@"B", @"KB", @"MB", @"GB"];
    NSInteger unitIndex = 0;
    
    while (size >= 1024.0 && unitIndex < units.count - 1) {
        size /= 1024.0;
        unitIndex++;
    }
    
    if (unitIndex == 0) {
        return [NSString stringWithFormat:@"%lu %@", (unsigned long)bytes, units[unitIndex]];
    } else {
        return [NSString stringWithFormat:@"%.2f %@", size, units[unitIndex]];
    }
}

- (void)addCookieList {
    // Only add if we haven't already added the list
    // Check if header already exists
    BOOL headerExists = NO;
    for (UIView *view in self.contentStackView.arrangedSubviews) {
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            if ([label.text isEqualToString:@"Cookies by Domain:"]) {
                headerExists = YES;
                break;
            }
        }
    }
    
    if (headerExists) {
        return; // Already added
    }
    
    // Header with better styling
    UILabel *listHeader = [[UILabel alloc] init];
    listHeader.text = @"📋 Cookies by Domain:";
    listHeader.font = [UIFont boldSystemFontOfSize:18];
    if (@available(iOS 13.0, *)) {
        listHeader.textColor = [UIColor labelColor];
    } else {
        listHeader.textColor = [UIColor blackColor];
    }
    
    // Find the right index to insert (before close button)
    NSInteger insertIndex = self.contentStackView.arrangedSubviews.count - 1;
    [self.contentStackView insertArrangedSubview:listHeader atIndex:insertIndex];
    
    // Group cookies by domain
    NSMutableDictionary<NSString *, NSMutableArray<NSHTTPCookie *> *> *domainCookies = [NSMutableDictionary dictionary];
    for (NSHTTPCookie *cookie in self.cookies) {
        NSString *domain = cookie.domain ?: @"Unknown";
        if (!domainCookies[domain]) {
            domainCookies[domain] = [NSMutableArray array];
        }
        [domainCookies[domain] addObject:cookie];
    }
    
    // Add domain sections
    NSArray<NSString *> *sortedDomains = [[domainCookies allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *domain in sortedDomains) {
        UIView *domainView = [self createDomainView:domain cookies:domainCookies[domain]];
        [self.contentStackView insertArrangedSubview:domainView atIndex:self.contentStackView.arrangedSubviews.count - 1];
    }
}

- (UIView *)createDomainView:(NSString *)domain cookies:(NSArray<NSHTTPCookie *> *)cookies {
    UIView *container = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        container.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        container.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    }
    container.layer.cornerRadius = 12;
    container.layer.masksToBounds = YES;
    container.layer.borderWidth = 0.5;
    if (@available(iOS 13.0, *)) {
        container.layer.borderColor = [UIColor separatorColor].CGColor;
    } else {
        container.layer.borderColor = [UIColor lightGrayColor].CGColor;
    }
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 8;
    stackView.layoutMargins = UIEdgeInsetsMake(12, 12, 12, 12);
    stackView.layoutMarginsRelativeArrangement = YES;
    [container addSubview:stackView];
    
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    
    // Domain label
    UILabel *domainLabel = [[UILabel alloc] init];
    domainLabel.text = domain;
    domainLabel.font = [UIFont boldSystemFontOfSize:14];
    if (@available(iOS 13.0, *)) {
        domainLabel.textColor = [UIColor labelColor];
    } else {
        domainLabel.textColor = [UIColor blackColor];
    }
    [stackView addArrangedSubview:domainLabel];
    
    // Cookie count
    UILabel *countLabel = [[UILabel alloc] init];
    countLabel.text = [NSString stringWithFormat:@"%lu cookie%@", (unsigned long)cookies.count, cookies.count == 1 ? @"" : @"s"];
    countLabel.font = [UIFont systemFontOfSize:12];
    if (@available(iOS 13.0, *)) {
        countLabel.textColor = [UIColor secondaryLabelColor];
    } else {
        countLabel.textColor = [UIColor grayColor];
    }
    [stackView addArrangedSubview:countLabel];
    
    // Delete button for domain with better styling
    UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [deleteButton setTitle:@"🗑️ Delete Domain" forState:UIControlStateNormal];
    deleteButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    if (@available(iOS 13.0, *)) {
        [deleteButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        deleteButton.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.1];
    } else {
        [deleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        deleteButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.1];
    }
    deleteButton.layer.cornerRadius = 8;
    deleteButton.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 12);
    [deleteButton addTarget:self action:@selector(deleteDomainCookies:) forControlEvents:UIControlEventTouchUpInside];
    deleteButton.tag = [domain hash]; // Store domain identifier
    objc_setAssociatedObject(deleteButton, "domain", domain, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [stackView addArrangedSubview:deleteButton];
    
    return container;
}

- (void)deleteDomainCookies:(UIButton *)sender {
    NSString *domain = objc_getAssociatedObject(sender, "domain");
    if (domain) {
        [[CookieManager sharedManager] deleteCookiesForDomain:domain];
        
        // Show confirmation
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" 
                                                                       message:[NSString stringWithFormat:@"Deleted cookies for %@", domain]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self loadCookies]; // Reload to update UI
            [self updateContainerHeight]; // Update height
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)deleteAllButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete All Cookies" 
                                                                   message:@"Are you sure you want to delete all cookies? This action cannot be undone."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[CookieManager sharedManager] deleteAllCookies];
        
        // Show success
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"Success" 
                                                                              message:@"All cookies have been deleted"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self loadCookies]; // Reload to update UI
            [self updateContainerHeight]; // Update height
        }]];
        [self presentViewController:successAlert animated:YES completion:nil];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteAppDataButtonTapped {
    NSString *dataSize = [self formatBytes:[[CookieManager sharedManager] getAppDataSize]];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Delete All App Data" 
                                                                   message:[NSString stringWithFormat:@"This will delete ALL data for this app including:\n\n• All cookies\n• Cache files (%@)\n• Documents\n• Preferences\n• Temporary files\n• Website data\n\nThis action CANNOT be undone. The app may need to restart.\n\nContinue?", dataSize]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete All" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // Show confirmation again for destructive operation
        UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"Final Confirmation" 
                                                                              message:@"This will permanently delete ALL app data. Are you absolutely sure?"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        
        [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [confirmAlert addAction:[UIAlertAction actionWithTitle:@"Yes, Delete Everything" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            // Perform deletion
            [[CookieManager sharedManager] deleteAllAppData];
            
            // Show success message
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"✅ Success" 
                                                                                  message:@"All app data has been deleted. The app may behave differently until you use it again."
                                                                           preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self loadCookies]; // Reload to update UI
                [self updateContainerHeight]; // Update height
            }]];
            [self presentViewController:successAlert animated:YES completion:nil];
        }]];
        
        [self presentViewController:confirmAlert animated:YES completion:nil];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)importCookiesTapped {
    NSString *text = UIPasteboard.generalPasteboard.string;

    if (!text || text.length == 0) {
        NSLog(@"❌ Portapapeles vacío");
        return;
    }

    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *cookiesArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];

    if (![cookiesArray isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ Formato inválido");
        return;
    }

    for (NSDictionary *dict in cookiesArray) {
        NSMutableDictionary *props = [NSMutableDictionary dictionary];
        props[NSHTTPCookieName] = dict[@"name"];
        props[NSHTTPCookieValue] = dict[@"value"];
        props[NSHTTPCookieDomain] = dict[@"domain"];
        props[NSHTTPCookiePath] = dict[@"path"] ?: @"/";

        if ([dict[@"secure"] boolValue]) {
            props[NSHTTPCookieSecure] = @"TRUE";
        }

        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:props];
        if (cookie) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
    }

    [self loadCookies];
}


- (void)openKeychainManager {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Keychain"
                                                                   message:@"Solo se puede acceder al Keychain de esta app."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Ver items"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        [self listKeychainItems];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}
#import <WebKit/WebKit.h>

- (void)deleteAllWebKitData {
    NSSet *allTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    NSDate *fromDate = [NSDate dateWithTimeIntervalSince1970:0];

    WKWebsiteDataStore *store = [WKWebsiteDataStore defaultDataStore];

    [store removeDataOfTypes:allTypes
               modifiedSince:fromDate
           completionHandler:^{
               NSLog(@"✅ WebKit data fully cleared (cookies, cache, storage, indexedDB, etc)");
           }];
}

- (void)listKeychainItems {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes : @YES,
        (__bridge id)kSecReturnData : @YES,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitAll
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status != errSecSuccess) {
        NSLog(@"Keychain vacío o sin acceso");
        return;
    }

    NSArray *items = (__bridge_transfer NSArray *)result;

    for (NSDictionary *item in items) {
        NSString *account = item[(__bridge id)kSecAttrAccount];
        NSString *service = item[(__bridge id)kSecAttrService];
        NSData *data = item[(__bridge id)kSecValueData];
        NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        NSLog(@"🔐 %@ | %@ = %@", service, account, value);
    }
}

- (void)saveKeychainItem:(NSString *)value
                account:(NSString *)account
                service:(NSString *)service {

    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : account,
        (__bridge id)kSecAttrService : service
    };

    SecItemDelete((__bridge CFDictionaryRef)query);

    NSMutableDictionary *item = [query mutableCopy];
    item[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];

    SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}


@end

