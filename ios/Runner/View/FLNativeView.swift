import Foundation
import FBAudienceNetwork

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view:FBAdView
    
    init(viewId:Int64, args:Any?, messenger:FlutterBinaryMessenger?, ctr:UIViewController) {
        _view=FBAdView.init(placementID: "749273062405103_749296435736099", adSize: kFBAdSizeHeight250Rectangle, rootViewController:ctr )
        _view.frame=CGRect(x: 0,y: 0,width: 320,height: 250)
        _view.loadAd()
        super.init()
    }
    
    func view() -> UIView {
           return _view
       }
}
