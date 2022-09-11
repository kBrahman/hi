import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    let PLUGIN_NAME="plugin-hi"
  override func application(_ application: UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
//    let channel=FlutterMethodChannel(name:"hi_method_channel",binaryMessenger: controller.binaryMessenger)
//    channel.setMethodCallHandler({
//        (call:FlutterMethodCall, result:@escaping FlutterResult)->Void in
//        
//    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
