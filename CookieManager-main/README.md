# CookieManager

A powerful iOS dynamic library for managing cookies and app data with a beautiful floating button interface.

## Features

- 🍪 **Cookie Management** - Delete cookies from all storage types (HTTP, WKWebView, URLSession)
- 🗑️ **App Data Deletion** - Clear caches, documents, preferences, temporary files, Keychain, and UserDefaults
- 🎯 **App-Scoped** - All operations only affect the current app (iOS sandbox enforced)
- 🎨 **Floating Button UI** - Easy-to-use circular floating button with drag support
- ✅ **Universal Compatibility** - Works with Native Swift/Objective-C, React, Next.js, Flutter apps
- 📱 **iOS 11-26+** - Forward compatible with all iOS versions including iOS 26

## Installation

### Manual Installation

1. Clone the repository
2. Build the dylib using the GitHub Actions workflow
3. Inject the built dylib into your IPA using tools like Sideloadly

### CocoaPods

```ruby
pod 'CookieManager'
```

## Usage

The library automatically initializes when the dylib is loaded. A floating circular button will appear on screen.

### Controls

- **Single Tap** → Opens the cookie management menu
- **Drag** → Move the button around the screen
- **Long Press (1 second)** → Hide/Show the button

### Manual Initialization

If needed, you can manually initialize:

```objc
#import "CookieManager.h"

// Show menu immediately
initCookieManager();

// Or initialize silently (button only)
initCookieManagerSilent();
```

## Building

The library is built automatically via GitHub Actions. Check the Actions tab for the latest build artifacts.

## License

MIT License
