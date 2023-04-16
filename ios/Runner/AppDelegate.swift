import UIKit
import AVFoundation
import Flutter
import Network

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    let CHECK_CONN="checkConn"
    let REQUEST_PERMISSIONS="requestPermissions"
    let APP_SETTINGS="appSettings"
    let RESULT_GRANTED=3
    let RESULT_DENIED=4
    let RESULT_PERMANENTLY_DENIED=2
    let DEVICE_INFO = "deviceInfo";
  override func application(_ application: UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel=FlutterMethodChannel(name:"hi.channel/app",binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler({
        (call:FlutterMethodCall, result:@escaping FlutterResult)->Void in
        switch call.method {
        case self.CHECK_CONN: self.netMonitor(channel, result)
        case self.REQUEST_PERMISSIONS: self.requestPermissions(result, .video)
        case self.APP_SETTINGS:
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString)  {
                    UIApplication.shared.open(settingsUrl, options: [:]) { completed in
                         if !completed {
                             print("Failed opening")
                         }
                    }
            }
        case self.DEVICE_INFO:result(["model":self.deviceName(), "version":Bundle.main.infoDictionary?["CFBundleShortVersionString"], "code":Bundle.main.infoDictionary?["CFBundleVersion"]])
        default:
            break;
        }
        
    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    private func deviceName() -> String {
            var systemInfo = utsname()
            uname(&systemInfo)
            let str = withUnsafePointer(to: &systemInfo.machine.0) { ptr in
                return String(cString: ptr)
            }
            return str
        }
    
    private func requestPermissions(_ res:@escaping FlutterResult, _ type: AVMediaType){
        switch AVCaptureDevice.authorizationStatus(for: type) {
            case .authorized:
                if type == .audio { res(RESULT_GRANTED)}
                else {requestPermissions(res, .audio)}
                
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: type) { granted in
                    if granted && type == .audio { res(self.RESULT_GRANTED)}
                    else {self.requestPermissions(res, .audio)}
                }
            
            case  .restricted: res(self.RESULT_DENIED)
            case .denied: res(self.RESULT_PERMANENTLY_DENIED)
        }
    }
    
    private func netMonitor(_ channel:FlutterMethodChannel, _ res:@escaping FlutterResult){
        let monitor=NWPathMonitor()
        let queue=DispatchQueue(label: "monitor")
        monitor.start(queue: queue)
        monitor.pathUpdateHandler={ p in
            DispatchQueue.main.async {
                switch p.status{
                case .satisfied: channel.invokeMethod("onAvailable",arguments: nil)
                   res(true)
                case .unsatisfied, .requiresConnection: channel.invokeMethod("onLost",arguments: nil)
                    res(false)
                }
            }
        }
    }
}
