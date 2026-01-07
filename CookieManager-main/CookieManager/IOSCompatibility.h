//
//  IOSCompatibility.h
//  CookieManager
//  iOS version compatibility checks for forward compatibility (iOS 11-26+)
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifndef IOSCompatibility_h
#define IOSCompatibility_h

// iOS version checks with forward compatibility
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

// Convenience macros for common iOS versions
#define IOS_11_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"11.0")
#define IOS_12_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"12.0")
#define IOS_13_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")
#define IOS_14_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"14.0")
#define IOS_15_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")
#define IOS_16_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"16.0")
#define IOS_17_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"17.0")
#define IOS_18_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"18.0")

// Forward compatibility: Any iOS version 26.0 or higher will pass this check
// This ensures the code works on iOS 26, 27, 28, etc.
#define IOS_26_OR_LATER    SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"26.0")

// Check if running on iOS 26 or later
static inline BOOL IsIOS26OrLater(void) {
    if (@available(iOS 26.0, *)) {
        return YES;
    }
    // For forward compatibility beyond iOS 26, also check version string
    if (IOS_26_OR_LATER) {
        return YES;
    }
    return NO;
}

// Safe UIBlurEffect style selection with forward compatibility
static inline UIBlurEffectStyle GetBlurEffectStyle(void) {
    if (@available(iOS 13.0, *)) {
        // iOS 13+ supports system materials, forward compatible through iOS 26+
        return UIBlurEffectStyleSystemMaterialDark;
    } else if (@available(iOS 10.0, *)) {
        return UIBlurEffectStyleDark;
    }
    // iOS 9 and below - will use fallback view
    return UIBlurEffectStyleDark;
}

#endif /* IOSCompatibility_h */

