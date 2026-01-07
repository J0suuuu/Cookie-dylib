//
//  CookieDeletionService.h
//  CookieManager
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CookieDeletionService : NSObject

+ (instancetype)sharedService;
- (void)deleteAllCookies;
- (void)deleteCookiesForDomain:(NSString *)domain;
- (NSArray<NSHTTPCookie *> *)getAllCookies;
- (NSInteger)getCookieCount;

// App data deletion methods (app-scoped)
- (void)deleteAllAppData;
- (void)deleteAppCaches;
- (void)deleteAppDocuments;
- (void)deleteAppPreferences;
- (NSUInteger)getAppDataSize;

@end

NS_ASSUME_NONNULL_END

