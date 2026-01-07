//
//  FloatingButtonManager.h
//  CookieManager
//  Floating button manager for easy menu access
//

#import <UIKit/UIKit.h>

@interface FloatingButtonManager : NSObject

+ (instancetype)sharedManager;

- (void)showFloatingButton;
- (void)hideFloatingButton;
- (BOOL)isFloatingButtonVisible;
- (void)toggleFloatingButton;

@end

