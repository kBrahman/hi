 import Foundation

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger:FlutterBinaryMessenger
  private var controller:UIViewController
    
    init(messenger:FlutterBinaryMessenger, controller:UIViewController) {
        self.messenger=messenger
        self.controller=controller
        super.init()
    }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        FLNativeView(viewId: viewId, args:args, messenger: messenger, ctr: controller)
    }
}
