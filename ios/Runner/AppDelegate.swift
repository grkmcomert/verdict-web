import Flutter
import UIKit
import WebKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    // MethodChannel for cookie access from Dart
    if let controller = window?.rootViewController as? FlutterViewController {
      let cookieChannel = FlutterMethodChannel(name: "com.grkmcomert.unfollowerscurrent/cookie", binaryMessenger: controller.binaryMessenger)
      cookieChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "getCookies" {
          guard let args = call.arguments as? [String:Any], let urlString = args["url"] as? String, let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGS", message: "missing url", details: nil))
            return
          }
          let host = url.host ?? ""
          let store = WKWebsiteDataStore.default().httpCookieStore
          store.getAllCookies { cookies in
            var filtered = cookies.filter { cookie in
              return cookie.domain.contains(host) || host.contains(cookie.domain)
            }
            // Fallback: if no cookies matched host, pick cookies that reference instagram
            if filtered.isEmpty {
              filtered = cookies.filter { $0.domain.contains("instagram") || $0.domain.contains("instagram.com") }
            }
            let pairs = filtered.map { "\($0.name)=\($0.value)" }
            let cookieHeader = pairs.joined(separator: "; ")
            print("[com.grkmcomert.unfollowerscurrent/cookie] host: \(host) cookies: \(cookieHeader)")
            result(cookieHeader)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
