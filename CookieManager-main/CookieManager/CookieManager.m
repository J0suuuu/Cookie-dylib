//
//  CookieManager.m
//  CookieManager
//

#import "CookieManager.h"
#import "CookieMenuViewController.h"
#import "CookieDeletionService.h"
#import "FloatingButtonManager.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static CookieManager *sharedInstance = nil;

@implementation CookieManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CookieManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupMenu];
        });
    }
    return self;
}

- (void)setupMenu {
    // Menu will be created when needed
}

- (void)showFloatingButton {
    [[FloatingButtonManager sharedManager] showFloatingButton];
}

- (void)hideFloatingButton {
    [[FloatingButtonManager sharedManager] hideFloatingButton];
}

- (void)toggleFloatingButton {
    [[FloatingButtonManager sharedManager] toggleFloatingButton];
}

- (BOOL)isFloatingButtonVisible {
    return [[FloatingButtonManager sharedManager] isFloatingButtonVisible];
}

- (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [self getKeyWindow];
        UIViewController *topVC = nil;
        
        if (keyWindow) {
            UIViewController *rootVC = keyWindow.rootViewController;
            topVC = [self topViewControllerFrom:rootVC];
            
            // Check if menu is already presented
            if (topVC && topVC.presentedViewController && [topVC.presentedViewController isKindOfClass:[CookieMenuViewController class]]) {
                return; // Already showing
            }
        }
        
        // If we couldn't find a view controller, try all windows
        if (!topVC) {
            NSArray<UIWindow *> *windows = [UIApplication sharedApplication].windows;
            for (UIWindow *window in windows) {
                if (window.windowLevel == UIWindowLevelNormal && window.rootViewController) {
                    topVC = [self topViewControllerFrom:window.rootViewController];
                    if (topVC && !topVC.presentedViewController) {
                        break;
                    }
                }
            }
        }
        
        // Create and present menu
        if (topVC) {
            CookieMenuViewController *menuVC = [[CookieMenuViewController alloc] init];
            menuVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            menuVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            [topVC presentViewController:menuVC animated:YES completion:nil];
        }
    });
}

- (void)hideMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [self getKeyWindow];
        if (keyWindow) {
            UIViewController *rootVC = keyWindow.rootViewController;
            UIViewController *topVC = [self topViewControllerFrom:rootVC];
            if (topVC.presentedViewController && [topVC.presentedViewController isKindOfClass:[CookieMenuViewController class]]) {
                [topVC dismissViewControllerAnimated:YES completion:nil];
            }
        }
    });
}

- (UIWindow *)getKeyWindow {
    // Forward compatible for iOS 13.0 through iOS 26+
    if (@available(iOS 13.0, *)) {
        UIApplication *app = [UIApplication sharedApplication];
        NSSet<UIScene *> *connectedScenes = app.connectedScenes;
        
        if (connectedScenes && connectedScenes.count > 0) {
            for (UIScene *scene in connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    // Check activation state with forward compatibility
                    if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *window in windowScene.windows) {
                            if (window.isKeyWindow) {
                                return window;
                            }
                        }
                        // If no key window, return first window
                        if (windowScene.windows.count > 0) {
                            return windowScene.windows.firstObject;
                        }
                    }
                }
            }
        }
    }
    
    // Fallback for iOS 12 and below, or if no scene found
    return [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
}

- (UIViewController *)topViewControllerFrom:(UIViewController *)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return [self topViewControllerFrom:[(UINavigationController *)vc visibleViewController]];
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        return [self topViewControllerFrom:[(UITabBarController *)vc selectedViewController]];
    } else if (vc.presentedViewController) {
        return [self topViewControllerFrom:vc.presentedViewController];
    }
    return vc;
}

- (void)deleteAllCookies {
    [[CookieDeletionService sharedService] deleteAllCookies];
}

- (void)deleteCookiesForDomain:(NSString *)domain {
    [[CookieDeletionService sharedService] deleteCookiesForDomain:domain];
}

- (NSArray<NSHTTPCookie *> *)getAllCookies {
    return [[CookieDeletionService sharedService] getAllCookies];
}

- (NSInteger)getCookieCount {
    return [[CookieDeletionService sharedService] getCookieCount];
}

- (void)deleteAllAppData {
    [[CookieDeletionService sharedService] deleteAllAppData];
}

- (void)deleteAppCaches {
    [[CookieDeletionService sharedService] deleteAppCaches];
}

- (void)deleteAppDocuments {
    [[CookieDeletionService sharedService] deleteAppDocuments];
}

- (void)deleteAppPreferences {
    [[CookieDeletionService sharedService] deleteAppPreferences];
}

- (NSUInteger)getAppDataSize {
    return [[CookieDeletionService sharedService] getAppDataSize];
}

// Helper method to setup gesture recognizer with retry
- (void)setupGestureRecognizerWithRetry:(NSInteger)retryCount {
    UIWindow *keyWindow = [self getKeyWindow];
    
    if (!keyWindow && retryCount < 10) {
        // Retry after delay if window isn't ready yet (increased retries for sideloaded apps)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self setupGestureRecognizerWithRetry:retryCount + 1];
        });
        return;
    }
    
    if (keyWindow) {
        // Check if gesture already exists to avoid duplicates
        // Use associated object to mark gestures we've added
        static const char kCookieManagerGestureKey;
        BOOL gestureExists = NO;
        for (UIGestureRecognizer *gesture in keyWindow.gestureRecognizers) {
            if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                UITapGestureRecognizer *tapGesture = (UITapGestureRecognizer *)gesture;
                if (tapGesture.numberOfTapsRequired == 3 && tapGesture.numberOfTouchesRequired == 2) {
                    // Check if this is our gesture using associated object
                    if (objc_getAssociatedObject(gesture, &kCookieManagerGestureKey) != nil) {
                        gestureExists = YES;
                        break;
                    }
                }
            }
        }
        
        if (!gestureExists) {
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showMenu)];
            tapGesture.numberOfTapsRequired = 3;
            tapGesture.numberOfTouchesRequired = 2;
            tapGesture.cancelsTouchesInView = NO;
            // Mark this gesture as ours using associated object
            objc_setAssociatedObject(tapGesture, &kCookieManagerGestureKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [keyWindow addGestureRecognizer:tapGesture];
        }
    }
}

@end

// Constructor - automatically called when dylib is loaded
__attribute__((constructor))
static void initializeCookieManager() {
    // Initialize the manager immediately
    CookieManager *manager = [CookieManager sharedManager];
    
    // Always setup gesture - try multiple times with increasing delays
    // This ensures it works even if called early in app lifecycle
    dispatch_async(dispatch_get_main_queue(), ^{
        // Try immediately
        [manager setupGestureRecognizerWithRetry:0];
        
        // Also try after 1 second
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [manager setupGestureRecognizerWithRetry:0];
        });
        
        // Also try after 3 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [manager setupGestureRecognizerWithRetry:0];
        });
    });
    
    // Setup when app becomes active (store observer to prevent deallocation)
    static id observer = nil;
    observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                 object:nil
                                                                  queue:[NSOperationQueue mainQueue]
                                                             usingBlock:^(NSNotification *note) {
        [manager setupGestureRecognizerWithRetry:0];
    }];
    
    // Also try when key window becomes available
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            // Wait for window
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [manager setupGestureRecognizerWithRetry:0];
            });
        }
    });
    
    // Setup floating button
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[FloatingButtonManager sharedManager] showFloatingButton];
    });
}

