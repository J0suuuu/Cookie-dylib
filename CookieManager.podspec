Pod::Spec.new do |s|
  s.name             = 'CookieManager'
  s.version          = '1.0.0'
  s.summary          = 'iOS dynamic library for cookie and app data management with floating button UI'
  s.description      = <<-DESC
    CookieManager is a comprehensive iOS dynamic library that provides cookie and app data management functionality.
    Features include:
    - Delete cookies from all storage types (HTTP, WKWebView, URLSession)
    - Delete app data (caches, documents, preferences, temporary files)
    - Clear Keychain items and UserDefaults
    - Beautiful floating button UI for easy access
    - App-scoped operations (only affects current app)
    - Compatible with all iOS versions including iOS 26+
    - Works with all app types (Native Swift/Objective-C, React, Next.js, Flutter)
  DESC
  s.homepage         = 'https://github.com/d7pr/CookieManager'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'CookieManager' => '' }
  s.source           = { :git => 'https://github.com/d7pr/CookieManager.git', :tag => s.version.to_s }
  s.ios.deployment_target = '11.0'
  s.source_files = 'CookieManager/**/*.{h,m}'
  s.public_header_files = 'CookieManager/CookieManager.h'
  s.frameworks = 'Foundation', 'UIKit', 'WebKit', 'Security'
  s.requires_arc = true
end
