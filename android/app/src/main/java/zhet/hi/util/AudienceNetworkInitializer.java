package zhet.hi.util;

import static zhet.hi.BuildConfig.DEBUG;

import com.facebook.ads.AdSettings;
import com.facebook.ads.AudienceNetworkAds;
import 	android.content.Context;
import io.flutter.Log;

public class AudienceNetworkInitializer implements AudienceNetworkAds.InitListener {

    public static void initialize(Context context) {
        if (!AudienceNetworkAds.isInitialized(context)) {
            if (DEBUG) {
                AdSettings.turnOnSDKDebugger(context);
            }

            AudienceNetworkAds
                    .buildInitSettings(context)
                    .withInitListener(new AudienceNetworkInitializer())
                    .initialize();
        }
    }

    @Override
    public void onInitialized(AudienceNetworkAds.InitResult result) {
        Log.d(AudienceNetworkAds.TAG, result.getMessage());
    }
}
