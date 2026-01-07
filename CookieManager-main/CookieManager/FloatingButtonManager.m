//
//  FloatingButtonManager.m
//  CookieManager
//  Floating button manager for easy menu access
//

#import "FloatingButtonManager.h"
#import "CookieManager.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface FloatingButtonManager ()

@property (strong, nonatomic) UIButton *floatingButton;
@property (strong, nonatomic) UIWindow *buttonWindow;
@property (nonatomic) CGPoint lastPanLocation;
@property (nonatomic) BOOL isDragging;

@end

// Custom window subclass that only captures touches on the button
@interface PassThroughWindow : UIWindow
@property (weak, nonatomic) UIButton *buttonToCapture;
@end

@implementation PassThroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Only handle touches on the button
    if (self.buttonToCapture && !self.buttonToCapture.hidden) {
        // Convert point to button's coordinate system
        CGPoint buttonPoint = [self convertPoint:point toView:self.buttonToCapture];
        
        // Check if point is inside the circular button
        CGRect buttonFrame = self.buttonToCapture.frame;
        CGFloat radius = buttonFrame.size.width / 2.0;
        CGPoint buttonCenter = CGPointMake(buttonFrame.origin.x + radius, buttonFrame.origin.y + radius);
        CGFloat distance = sqrt(pow(point.x - buttonCenter.x, 2) + pow(point.y - buttonCenter.y, 2));
        
        if (distance <= radius) {
            // Touch is inside button - let button handle it
            return [self.buttonToCapture hitTest:buttonPoint withEvent:event];
        }
    }
    
    // Touch is outside button - return nil to pass through to underlying window/app
    return nil;
}

@end

@implementation FloatingButtonManager

+ (instancetype)sharedManager {
    static FloatingButtonManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FloatingButtonManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isDragging = NO;
        [self setupFloatingButton];
    }
    return self;
}

- (void)setupFloatingButton {
    // Create custom pass-through window
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = scene;
                break;
            }
        }
        if (windowScene) {
            self.buttonWindow = [[PassThroughWindow alloc] initWithWindowScene:windowScene];
        } else {
            self.buttonWindow = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
    } else {
        self.buttonWindow = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    PassThroughWindow *passThroughWindow = (PassThroughWindow *)self.buttonWindow;
    
    self.buttonWindow.windowLevel = UIWindowLevelStatusBar + 1;
    self.buttonWindow.backgroundColor = [UIColor clearColor];
    self.buttonWindow.userInteractionEnabled = YES;
    self.buttonWindow.hidden = NO;
    
    // Create floating button
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(0, 0, 60, 60);
    self.floatingButton.layer.cornerRadius = 30;
    self.floatingButton.layer.masksToBounds = YES;
    self.floatingButton.userInteractionEnabled = YES;
    
    // Gradient background
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.floatingButton.bounds;
    gradientLayer.cornerRadius = 30;
    gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0].CGColor
    ];
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint = CGPointMake(1, 1);
    [self.floatingButton.layer insertSublayer:gradientLayer atIndex:0];
    
    // Shadow
    self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 3);
    self.floatingButton.layer.shadowRadius = 8;
    self.floatingButton.layer.shadowOpacity = 0.3;
    
    // Icon
    [self.floatingButton setTitle:@"🍪" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:28];
    
    // Button action - tap to open menu
    [self.floatingButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Load saved position or use default
    CGPoint savedPosition = [self loadButtonPosition];
    self.floatingButton.center = savedPosition;
    
    // Set button reference for window hit testing
    passThroughWindow.buttonToCapture = self.floatingButton;
    
    // Add button to window
    [self.buttonWindow addSubview:self.floatingButton];
    
    // Setup pan gesture for dragging
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panGesture.cancelsTouchesInView = NO; // Don't cancel button taps
    [self.floatingButton addGestureRecognizer:panGesture];
    
    // Setup long press gesture for hide/show
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPressGesture.minimumPressDuration = 1.0;
    longPressGesture.cancelsTouchesInView = NO;
    [longPressGesture requireGestureRecognizerToFail:panGesture];
    [self.floatingButton addGestureRecognizer:longPressGesture];
    
    // Monitor app state
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)buttonTapped:(UIButton *)button {
    // Only open menu if we're not dragging
    if (!self.isDragging) {
        // Use a small delay to ensure tap is complete
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!self.isDragging) {
                [[CookieManager sharedManager] showMenu];
            }
        });
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.buttonWindow];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.lastPanLocation = self.floatingButton.center;
        self.isDragging = NO; // Don't set immediately
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        // Check if we've moved enough to consider it a drag
        CGFloat distance = sqrt(translation.x * translation.x + translation.y * translation.y);
        
        if (!self.isDragging && distance >= 10.0) {
            // Started dragging
            self.isDragging = YES;
            
            // Visual feedback
            [UIView animateWithDuration:0.2 animations:^{
                self.floatingButton.transform = CGAffineTransformMakeScale(1.1, 1.1);
            }];
        }
        
        if (self.isDragging) {
            // Move button
            CGPoint newCenter = CGPointMake(self.lastPanLocation.x + translation.x,
                                           self.lastPanLocation.y + translation.y);
            
            // Keep within bounds
            CGRect screenBounds = self.buttonWindow.bounds;
            CGFloat radius = 30;
            newCenter.x = MAX(radius, MIN(screenBounds.size.width - radius, newCenter.x));
            newCenter.y = MAX(radius, MIN(screenBounds.size.height - radius, newCenter.y));
            
            self.floatingButton.center = newCenter;
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled) {
        BOOL wasDragging = self.isDragging;
        self.isDragging = NO;
        
        if (wasDragging) {
            // Snap to nearest edge
            [self snapToNearestEdge];
            
            // Save position
            [self saveButtonPosition:self.floatingButton.center];
            
            // Scale back
            [UIView animateWithDuration:0.2 animations:^{
                self.floatingButton.transform = CGAffineTransformIdentity;
            }];
        }
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self toggleFloatingButton];
    }
}

- (void)snapToNearestEdge {
    CGRect screenBounds = self.buttonWindow.bounds;
    CGPoint center = self.floatingButton.center;
    CGFloat radius = 30;
    
    CGFloat distanceToLeft = center.x;
    CGFloat distanceToRight = screenBounds.size.width - center.x;
    CGFloat distanceToTop = center.y;
    CGFloat distanceToBottom = screenBounds.size.height - center.y;
    
    CGFloat minDistance = MIN(MIN(distanceToLeft, distanceToRight), MIN(distanceToTop, distanceToBottom));
    
    CGPoint newCenter = center;
    if (minDistance == distanceToLeft) {
        newCenter.x = radius + 10;
    } else if (minDistance == distanceToRight) {
        newCenter.x = screenBounds.size.width - radius - 10;
    } else if (minDistance == distanceToTop) {
        newCenter.y = radius + 10;
    } else {
        newCenter.y = screenBounds.size.height - radius - 10;
    }
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.floatingButton.center = newCenter;
    } completion:nil];
}

- (void)saveButtonPosition:(CGPoint)position {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:position.x forKey:@"CookieManager_FloatingButton_X"];
    [defaults setFloat:position.y forKey:@"CookieManager_FloatingButton_Y"];
    [defaults synchronize];
}

- (CGPoint)loadButtonPosition {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat x = [defaults floatForKey:@"CookieManager_FloatingButton_X"];
    CGFloat y = [defaults floatForKey:@"CookieManager_FloatingButton_Y"];
    
    if (x == 0 && y == 0) {
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        x = screenBounds.size.width - 40;
        y = screenBounds.size.height - 100;
    }
    
    return CGPointMake(x, y);
}

- (void)showFloatingButton {
    if (self.buttonWindow) {
        self.buttonWindow.hidden = NO;
    } else {
        [self setupFloatingButton];
    }
}

- (void)hideFloatingButton {
    if (self.buttonWindow) {
        self.buttonWindow.hidden = YES;
    }
}

- (BOOL)isFloatingButtonVisible {
    return self.buttonWindow && !self.buttonWindow.hidden;
}

- (void)toggleFloatingButton {
    if ([self isFloatingButtonVisible]) {
        [self hideFloatingButton];
    } else {
        [self showFloatingButton];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.buttonWindow) {
        self.buttonWindow.frame = [UIScreen mainScreen].bounds;
        
        if (@available(iOS 13.0, *)) {
            UIWindowScene *windowScene = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    windowScene = scene;
                    break;
                }
            }
            if (windowScene && self.buttonWindow.windowScene != windowScene) {
                CGPoint savedCenter = self.floatingButton.center;
                [self setupFloatingButton];
                self.floatingButton.center = savedCenter;
            }
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

