//
//  Inject.h
//  CookieManager
//  Public injection interface
//

#ifndef Inject_h
#define Inject_h

#ifdef __cplusplus
extern "C" {
#endif

// Initialize cookie manager and show menu
void initCookieManager(void);

// Initialize cookie manager silently (without showing menu)
void initCookieManagerSilent(void);

#ifdef __cplusplus
}
#endif

#endif /* Inject_h */

