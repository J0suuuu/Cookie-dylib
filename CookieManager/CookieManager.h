//
//  CookieManager.h
//  CookieManager
//
//  Dynamic library for cookie management across all app types
//

#import <Foundation/Foundation.h>

//! Project version number for CookieManager.
FOUNDATION_EXPORT double CookieManagerVersionNumber;

//! Project version string for CookieManager.
FOUNDATION_EXPORT const unsigned char CookieManagerVersionString[];

// Main interface
@interface CookieManager : NSObject

+ (instancetype)sharedManager;
- (void)showMenu;
- (void)hideMenu;
- (void)deleteAllCookies;
- (void)deleteCookiesForDomain:(NSString *)domain;
- (NSArray<NSHTTPCookie *> *)getAllCookies;
- (NSInteger)getCookieCount;

// App data deletion methods (app-scoped - only affects current app)
- (void)deleteAllAppData;
- (void)deleteAppCaches;
- (void)deleteAppDocuments;
- (void)deleteAppPreferences;
- (NSUInteger)getAppDataSize;

// Internal method for gesture setup
- (void)setupGestureRecognizerWithRetry:(NSInteger)retryCount;

// Floating button control
- (void)showFloatingButton;
- (void)hideFloatingButton;
- (void)toggleFloatingButton;
- (BOOL)isFloatingButtonVisible;

@end

