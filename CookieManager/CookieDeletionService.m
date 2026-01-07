//
//  CookieDeletionService.m
//  CookieManager
//  Comprehensive app-scoped cookie deletion service for all app types
//

#import "CookieDeletionService.h"
#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>

@interface CookieDeletionService ()

@property (strong, nonatomic) NSMutableArray<NSHTTPCookie *> *cachedCookies;
@property (strong, nonatomic) NSString *appBundleIdentifier;

@end

@implementation CookieDeletionService

+ (instancetype)sharedService {
    static CookieDeletionService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CookieDeletionService alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.cachedCookies = [NSMutableArray array];
        // Store app bundle identifier to ensure we only work with this app's cookies
        self.appBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    }
    return self;
}

- (NSArray<NSHTTPCookie *> *)getAllCookies {
    NSMutableArray<NSHTTPCookie *> *allCookies = [NSMutableArray array];
    
    // All cookie storage mechanisms in iOS are automatically app-scoped by the system
    // We don't need to filter by app because the system enforces app sandboxing
    
    // 1. HTTP Cookie Storage (Native iOS apps, Swift, Objective-C)
    // NOTE: sharedHTTPCookieStorage is app-scoped by iOS sandbox - only returns this app's cookies
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *httpCookies = cookieStorage.cookies;
    if (httpCookies) {
        [allCookies addObjectsFromArray:httpCookies];
    }
    
    // 2. WKWebView Cookies (WebKit - React, Next.js, Flutter WebView)
    // NOTE: defaultDataStore is app-scoped by iOS sandbox - only returns this app's cookies
    WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
    WKHTTPCookieStore *cookieStore = dataStore.httpCookieStore;
    
    // Use semaphore to wait for async cookie retrieval
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSMutableArray<NSHTTPCookie *> *webKitCookies = [NSMutableArray array];
    
    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        if (cookies) {
            [webKitCookies addObjectsFromArray:cookies];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Wait up to 2 seconds for async operation
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC));
    [allCookies addObjectsFromArray:webKitCookies];
    
    // 3. URLSession Cookies (Network layer)
    // NOTE: URLSessionConfiguration uses app-scoped cookie storage
    NSURLSessionConfiguration *defaultConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSHTTPCookieStorage *urlSessionCookieStorage = defaultConfig.HTTPCookieStorage;
    // Check if it's the same instance as sharedHTTPCookieStorage to avoid duplicates
    if (urlSessionCookieStorage != cookieStorage) {
        NSArray<NSHTTPCookie *> *urlSessionCookies = urlSessionCookieStorage.cookies;
        if (urlSessionCookies) {
            for (NSHTTPCookie *cookie in urlSessionCookies) {
                // Avoid duplicates
                BOOL exists = NO;
                for (NSHTTPCookie *existingCookie in allCookies) {
                    if ([existingCookie.name isEqualToString:cookie.name] &&
                        [existingCookie.domain isEqualToString:cookie.domain] &&
                        [existingCookie.path isEqualToString:cookie.path]) {
                        exists = YES;
                        break;
                    }
                }
                if (!exists) {
                    [allCookies addObject:cookie];
                }
            }
        }
    }
    
    // 4. Ephemeral session cookies (in-memory only, app-scoped by definition)
    // These are typically already covered above, but we check for completeness
    
    // 5. Flutter WebView specific handling
    // Flutter uses WKWebView, so cookies are already captured above via WKWebsiteDataStore
    
    return [allCookies copy];
}

- (NSInteger)getCookieCount {
    return [self getAllCookies].count;
}

- (void)deleteAllCookies {
    // IMPORTANT: All cookie storage in iOS is app-scoped by the sandbox
    // We only delete cookies belonging to the current app, not other apps
    
    // 1. Delete from HTTP Cookie Storage (Native iOS, Swift, Objective-C)
    // This is app-scoped - only contains cookies for this app
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *httpCookies = cookieStorage.cookies;
    for (NSHTTPCookie *cookie in httpCookies) {
        [cookieStorage deleteCookie:cookie];
    }
    
    // 2. Delete from WKWebView Cookie Store (React, Next.js, Flutter WebView)
    // This is app-scoped - only contains cookies for this app's web views
    WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
    WKHTTPCookieStore *cookieStore = dataStore.httpCookieStore;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSInteger remainingDeletions = 0;
    
    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        remainingDeletions = cookies.count;
        if (remainingDeletions == 0) {
            dispatch_semaphore_signal(semaphore);
        }
        
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStore deleteCookie:cookie completionHandler:^{
                remainingDeletions--;
                if (remainingDeletions == 0) {
                    dispatch_semaphore_signal(semaphore);
                }
            }];
        }
    }];
    
    // Wait up to 5 seconds for all deletions
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC));
    
    // 3. Clear WKWebsiteDataStore cookies (app-scoped)
    // This clears cookies for this app's web views only
    NSSet<NSString *> *dataTypes = [NSSet setWithObject:WKWebsiteDataTypeCookies];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
    
    dispatch_semaphore_t dataStoreSemaphore = dispatch_semaphore_create(0);
    [dataStore removeDataOfTypes:dataTypes 
                    modifiedSince:date 
                completionHandler:^{
                    // Cookies cleared for this app only
                    dispatch_semaphore_signal(dataStoreSemaphore);
                }];
    
    // Wait up to 5 seconds for completion
    dispatch_semaphore_wait(dataStoreSemaphore, dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC));
    
    // 4. Delete from URLSession default configuration (if different storage instance)
    // URLSessionConfiguration uses app-scoped cookie storage
    NSURLSessionConfiguration *defaultConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSHTTPCookieStorage *defaultCookieStorage = defaultConfig.HTTPCookieStorage;
    
    // Only process if it's a different storage instance
    if (defaultCookieStorage != cookieStorage) {
        NSArray<NSHTTPCookie *> *urlSessionCookies = defaultCookieStorage.cookies;
        for (NSHTTPCookie *cookie in urlSessionCookies) {
            [defaultCookieStorage deleteCookie:cookie];
        }
    }
    
    // 5. Clear app-specific cookie cache files and Library/Cookies directory
    // iOS sandbox ensures NSSearchPathForDirectoriesInDomains returns app-scoped paths only
    NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if (libraryPaths.count > 0) {
        NSString *appLibraryPath = libraryPaths.firstObject;
        
        // Clear Caches/Cookies directory (app-scoped)
        NSString *appCookiesCachePath = [appLibraryPath stringByAppendingPathComponent:@"Caches/Cookies"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:appCookiesCachePath]) {
            NSError *error = nil;
            NSArray<NSString *> *cacheFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appCookiesCachePath error:&error];
            if (!error && cacheFiles) {
                for (NSString *cacheFile in cacheFiles) {
                    NSString *cacheFilePath = [appCookiesCachePath stringByAppendingPathComponent:cacheFile];
                    // Safe to delete - it's in the app's Caches directory (app-scoped by iOS sandbox)
                    [[NSFileManager defaultManager] removeItemAtPath:cacheFilePath error:nil];
                }
            }
        }
        
        // Clear Library/Cookies directory (app-scoped)
        NSString *appCookiesPath = [appLibraryPath stringByAppendingPathComponent:@"Cookies"];
        // iOS sandbox guarantees this path is within the app's container
        // NSSearchPathForDirectoriesInDomains is always app-scoped
        if ([[NSFileManager defaultManager] fileExistsAtPath:appCookiesPath]) {
            NSError *error = nil;
            NSArray<NSString *> *cookieFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appCookiesPath error:&error];
            if (!error && cookieFiles) {
                for (NSString *cookieFile in cookieFiles) {
                    NSString *cookieFilePath = [appCookiesPath stringByAppendingPathComponent:cookieFile];
                    // Safe to delete - it's in the app's Library directory (app-scoped by iOS sandbox)
                    [[NSFileManager defaultManager] removeItemAtPath:cookieFilePath error:nil];
                }
            }
        }
    }
    
    // 6. Clear UserDefaults (app-scoped) - many apps store session tokens here
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *allDefaults = [defaults dictionaryRepresentation];
        for (NSString *key in allDefaults.allKeys) {
            [defaults removeObjectForKey:key];
        }
        [defaults synchronize];
    }
    
    // 7. Clear Keychain items (app-scoped) - authentication tokens, session keys
    [self clearKeychainForApp];
    
    // 8. Force synchronization (app-scoped)
    // Note: syncCookies was deprecated in iOS 9.0 and removed in later versions
    // Cookies are automatically synchronized by the system
}

- (void)deleteCookiesForDomain:(NSString *)domain {
    if (!domain || domain.length == 0) {
        return;
    }
    
    // All operations are app-scoped - only delete cookies for the current app
    
    // 1. Delete from HTTP Cookie Storage (app-scoped)
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *httpCookies = cookieStorage.cookies;
    for (NSHTTPCookie *cookie in httpCookies) {
        // Match domain (handles subdomains)
        NSString *cookieDomain = cookie.domain;
        if (cookieDomain) {
            // Remove leading dot if present for comparison
            NSString *normalizedCookieDomain = [cookieDomain hasPrefix:@"."] 
                ? [cookieDomain substringFromIndex:1] 
                : cookieDomain;
            NSString *normalizedDomain = [domain hasPrefix:@"."] 
                ? [domain substringFromIndex:1] 
                : domain;
            
            if ([normalizedCookieDomain isEqualToString:normalizedDomain] ||
                [normalizedCookieDomain hasSuffix:[@"." stringByAppendingString:normalizedDomain]] ||
                [normalizedDomain hasSuffix:[@"." stringByAppendingString:normalizedCookieDomain]]) {
                [cookieStorage deleteCookie:cookie];
            }
        }
    }
    
    // 2. Delete from WKWebView Cookie Store (app-scoped)
    WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
    WKHTTPCookieStore *cookieStore = dataStore.httpCookieStore;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSInteger remainingDeletions = 0;
    __block BOOL hasCookies = NO;
    
    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        NSMutableArray<NSHTTPCookie *> *matchingCookies = [NSMutableArray array];
        for (NSHTTPCookie *cookie in cookies) {
            NSString *cookieDomain = cookie.domain;
            if (cookieDomain) {
                NSString *normalizedCookieDomain = [cookieDomain hasPrefix:@"."] 
                    ? [cookieDomain substringFromIndex:1] 
                    : cookieDomain;
                NSString *normalizedDomain = [domain hasPrefix:@"."] 
                    ? [domain substringFromIndex:1] 
                    : domain;
                
                if ([normalizedCookieDomain isEqualToString:normalizedDomain] ||
                    [normalizedCookieDomain hasSuffix:[@"." stringByAppendingString:normalizedDomain]] ||
                    [normalizedDomain hasSuffix:[@"." stringByAppendingString:normalizedCookieDomain]]) {
                    [matchingCookies addObject:cookie];
                }
            }
        }
        
        remainingDeletions = matchingCookies.count;
        hasCookies = remainingDeletions > 0;
        
        if (remainingDeletions == 0) {
            dispatch_semaphore_signal(semaphore);
        }
        
        for (NSHTTPCookie *cookie in matchingCookies) {
            [cookieStore deleteCookie:cookie completionHandler:^{
                remainingDeletions--;
                if (remainingDeletions == 0) {
                    dispatch_semaphore_signal(semaphore);
                }
            }];
        }
    }];
    
    // Wait up to 5 seconds
    if (hasCookies) {
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC));
    }
    
    // 3. Delete from URLSession (app-scoped)
    NSURLSessionConfiguration *defaultConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSHTTPCookieStorage *defaultCookieStorage = defaultConfig.HTTPCookieStorage;
    
    // Only process if it's a different storage instance
    if (defaultCookieStorage != cookieStorage) {
        NSArray<NSHTTPCookie *> *urlSessionCookies = defaultCookieStorage.cookies;
        for (NSHTTPCookie *cookie in urlSessionCookies) {
            NSString *cookieDomain = cookie.domain;
            if (cookieDomain) {
                NSString *normalizedCookieDomain = [cookieDomain hasPrefix:@"."] 
                    ? [cookieDomain substringFromIndex:1] 
                    : cookieDomain;
                NSString *normalizedDomain = [domain hasPrefix:@"."] 
                    ? [domain substringFromIndex:1] 
                    : domain;
                
                if ([normalizedCookieDomain isEqualToString:normalizedDomain] ||
                    [normalizedCookieDomain hasSuffix:[@"." stringByAppendingString:normalizedDomain]] ||
                    [normalizedDomain hasSuffix:[@"." stringByAppendingString:normalizedCookieDomain]]) {
                    [defaultCookieStorage deleteCookie:cookie];
                }
            }
        }
    }
    
    // 4. Force synchronization (app-scoped)
    // Note: syncCookies was deprecated in iOS 9.0 and removed in later versions
    // Cookies are automatically synchronized by the system
}

#pragma mark - App Data Deletion (App-Scoped)

- (void)deleteAllAppData {
    // IMPORTANT: This deletes ALL data for the current app only (app-scoped)
    // iOS sandbox ensures we can only access this app's data
    
    // 1. Delete cookies first (includes Keychain and UserDefaults)
    [self deleteAllCookies];
    
    // 2. Delete caches
    [self deleteAppCaches];
    
    // 3. Delete documents
    [self deleteAppDocuments];
    
    // 4. Delete preferences
    [self deleteAppPreferences];
    
    // 5. Delete temporary files
    [self deleteAppTemporaryFiles];
    
    // 6. Clear WKWebsiteDataStore completely (app-scoped) - wait for completion
    WKWebsiteDataStore *dataStore = [WKWebsiteDataStore defaultDataStore];
    NSSet<NSString *> *allDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [dataStore removeDataOfTypes:allDataTypes 
                    modifiedSince:date 
                completionHandler:^{
                    // All website data cleared for this app
                    dispatch_semaphore_signal(semaphore);
                }];
    
    // Wait up to 10 seconds for completion
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10.0 * NSEC_PER_SEC));
    
    // 7. Clear Keychain again to ensure everything is gone
    [self clearKeychainForApp];
    
    // 8. Clear UserDefaults again
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *allDefaults = [defaults dictionaryRepresentation];
        for (NSString *key in allDefaults.allKeys) {
            [defaults removeObjectForKey:key];
        }
        [defaults synchronize];
    }
}

- (void)deleteAppCaches {
    // Delete app's Caches directory (app-scoped)
    NSArray<NSString *> *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (cachePaths.count > 0) {
        NSString *cachesPath = cachePaths.firstObject;
        // iOS sandbox ensures this is app-scoped
        [self deleteContentsOfDirectory:cachesPath];
    }
}

- (void)deleteAppDocuments {
    // Delete app's Documents directory (app-scoped)
    NSArray<NSString *> *documentsPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (documentsPaths.count > 0) {
        NSString *documentsPath = documentsPaths.firstObject;
        // iOS sandbox ensures this is app-scoped
        [self deleteContentsOfDirectory:documentsPath];
    }
}

- (void)deleteAppPreferences {
    // Delete app's preferences (app-scoped)
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID) {
        // Remove all user defaults for this app
        NSString *prefsPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences"] 
                              stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleID]];
        
        // Also handle preferences domain
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary<NSString *, id> *allPrefs = [defaults dictionaryRepresentation];
        for (NSString *key in allPrefs.allKeys) {
            [defaults removeObjectForKey:key];
        }
        [defaults synchronize];
        
        // Delete preference files
        if ([[NSFileManager defaultManager] fileExistsAtPath:prefsPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:prefsPath error:nil];
        }
    }
}

- (void)deleteAppTemporaryFiles {
    // Delete app's temporary files (app-scoped)
    NSString *tempPath = NSTemporaryDirectory();
    if (tempPath && tempPath.length > 0) {
        // iOS sandbox ensures this is app-scoped
        [self deleteContentsOfDirectory:tempPath];
    }
}

- (void)deleteContentsOfDirectory:(NSString *)directoryPath {
    // Helper method to delete contents of a directory (not the directory itself)
    // This ensures the directory structure remains intact
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return;
    }
    
    NSError *error = nil;
    NSArray<NSString *> *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        // Log error but continue
        return;
    }
    
    for (NSString *item in contents) {
        NSString *itemPath = [directoryPath stringByAppendingPathComponent:item];
        BOOL isDirectory = NO;
        
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // Recursively delete directory contents
                [self deleteContentsOfDirectory:itemPath];
                // Remove the directory itself
                [fileManager removeItemAtPath:itemPath error:nil];
            } else {
                // Delete file
                [fileManager removeItemAtPath:itemPath error:nil];
            }
        }
    }
}

- (NSUInteger)getAppDataSize {
    // Calculate total size of app data (app-scoped directories)
    NSUInteger totalSize = 0;
    
    // Get size of Caches directory
    NSArray<NSString *> *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (cachePaths.count > 0) {
        totalSize += [self getSizeOfDirectory:cachePaths.firstObject];
    }
    
    // Get size of Documents directory
    NSArray<NSString *> *documentsPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (documentsPaths.count > 0) {
        totalSize += [self getSizeOfDirectory:documentsPaths.firstObject];
    }
    
    // Get size of Library directory (excluding system files)
    NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if (libraryPaths.count > 0) {
        NSString *libraryPath = libraryPaths.firstObject;
        // Only count specific subdirectories to avoid system files
        NSArray<NSString *> *subdirs = @[@"Cookies", @"Preferences", @"Application Support"];
        for (NSString *subdir in subdirs) {
            NSString *subdirPath = [libraryPath stringByAppendingPathComponent:subdir];
            if ([[NSFileManager defaultManager] fileExistsAtPath:subdirPath]) {
                totalSize += [self getSizeOfDirectory:subdirPath];
            }
        }
    }
    
    // Get size of temporary files
    NSString *tempPath = NSTemporaryDirectory();
    if (tempPath && tempPath.length > 0) {
        totalSize += [self getSizeOfDirectory:tempPath];
    }
    
    return totalSize;
}

- (void)clearKeychainForApp {
    // Clear all Keychain items for this app (app-scoped)
    // Keychain items are automatically scoped to the app by iOS
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) {
        return;
    }
    
    // Query dictionary to find all items for this app
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
    };
    
    CFArrayRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    
    if (status == errSecSuccess && result) {
        NSArray *items = (__bridge_transfer NSArray *)result;
        for (NSDictionary *item in items) {
            NSMutableDictionary *deleteQuery = [item mutableCopy];
            deleteQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
            deleteQuery[(__bridge id)kSecReturnAttributes] = nil;
            deleteQuery[(__bridge id)kSecMatchLimit] = nil;
            SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        }
    }
    
    // Also try to delete internet passwords (cookies, tokens)
    NSDictionary *internetQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
    };
    
    CFArrayRef internetResult = NULL;
    OSStatus internetStatus = SecItemCopyMatching((__bridge CFDictionaryRef)internetQuery, (CFTypeRef *)&internetResult);
    
    if (internetStatus == errSecSuccess && internetResult) {
        NSArray *items = (__bridge_transfer NSArray *)internetResult;
        for (NSDictionary *item in items) {
            NSMutableDictionary *deleteQuery = [item mutableCopy];
            deleteQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
            deleteQuery[(__bridge id)kSecReturnAttributes] = nil;
            deleteQuery[(__bridge id)kSecMatchLimit] = nil;
            SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        }
    }
}

- (NSUInteger)getSizeOfDirectory:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return 0;
    }
    
    NSUInteger totalSize = 0;
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:directoryPath];
    
    for (NSString *filePath in enumerator) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:filePath];
        NSDictionary<NSFileAttributeKey, id> *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
        if (attributes) {
            NSNumber *fileSize = attributes[NSFileSize];
            if (fileSize) {
                totalSize += [fileSize unsignedIntegerValue];
            }
        }
    }
    
    return totalSize;
}

@end

