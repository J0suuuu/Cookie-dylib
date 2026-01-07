//
//  Inject.m
//  CookieManager
//  Injection entry point for runtime loading
//

#import <Foundation/Foundation.h>
#import "CookieManager.h"
#import <objc/runtime.h>

// Forward declaration
@interface CookieManager (Private)
- (void)setupGestureRecognizerWithRetry:(NSInteger)retryCount;
@end

// This function can be called to manually initialize the cookie manager
// It's useful if the constructor doesn't run automatically
void initCookieManager() {
    @autoreleasepool {
        CookieManager *manager = [CookieManager sharedManager];
        // Setup gesture first
        dispatch_async(dispatch_get_main_queue(), ^{
            [manager setupGestureRecognizerWithRetry:0];
        });
        // Show menu after a delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [manager showMenu];
        });
    }
}

// Alternative initialization that doesn't show menu immediately but sets up gesture
void initCookieManagerSilent() {
    @autoreleasepool {
        CookieManager *manager = [CookieManager sharedManager];
        // Setup gesture recognizer after a short delay
        dispatch_async(dispatch_get_main_queue(), ^{
            [manager setupGestureRecognizerWithRetry:0];
        });
    }
}

