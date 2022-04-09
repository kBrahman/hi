package zhet.hi.activity;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.ads.Ad;
import com.facebook.ads.AdError;
import com.facebook.ads.AdSettings;
import com.facebook.ads.InterstitialAd;
import com.facebook.ads.InterstitialAdListener;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import zhet.hi.factory.NativeViewFactory;
import zhet.hi.util.AudienceNetworkInitializer;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    public static final String IS_LOADED = "isLoaded";
    public static final String SHOW = "show";
    private InterstitialAd interstitialAd;

    @Override
    protected void onCreate(@Nullable android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        AudienceNetworkInitializer.initialize(getContext());
        interstitialAd = new InterstitialAd(getContext(), "3797187196981029_5287545084611892");
//        AdSettings.addTestDevice("df7ae421-a3f3-4ea8-b57a-7c17c1cf3ca9");
        loadAd();
    }

    private void loadAd() {
        interstitialAd.loadAd(
                interstitialAd.buildLoadAdConfig()
                        .withAdListener(new InterstitialAdListener() {
                            @Override
                            public void onInterstitialDisplayed(Ad ad) {
                                Log.e(TAG, "Interstitial ad displayed.");
                            }

                            @Override
                            public void onInterstitialDismissed(Ad ad) {
                                Log.e(TAG, "Interstitial ad dismissed. invalidated=>");
                                loadAd();
                            }

                            @Override
                            public void onError(Ad ad, AdError adError) {
                                Log.e(TAG, "Interstitial ad failed to load: " + adError.getErrorMessage());
                            }

                            @Override
                            public void onAdLoaded(Ad ad) {
                                Log.d(TAG, "Interstitial ad is loaded and ready to be displayed! time out=>");

                            }

                            @Override
                            public void onAdClicked(Ad ad) {
                            }

                            @Override
                            public void onLoggingImpression(Ad ad) {
                            }
                        }).build());
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        MethodChannel channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "hi.channel/app");
        channel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case IS_LOADED:
                    result.success(interstitialAd.isAdLoaded());
                    break;
                case SHOW:
                    interstitialAd.show();
            }
        });
        engine.getPlatformViewsController().getRegistry().registerViewFactory("medium_rectangle", new NativeViewFactory());
    }

    @Override
    protected void onDestroy() {
        if (interstitialAd != null) interstitialAd.destroy();
        super.onDestroy();
    }

    /*
    /
                interstitialAd.buildLoadAdConfig()
                        .withAdListener(new InterstitialAdListener() {
                            @java.lang.Override
                            public void onInterstitialDisplayed(Ad ad) {
                                Log.e(TAG, "Interstitial ad displayed.");
                                channel.invokeMethod("displayed", null);
                            }

                            @Override
                            public void onInterstitialDismissed(Ad ad) {
                                Log.e(TAG, "Interstitial ad dismissed.");
                                channel.invokeMethod("dismissed", null);
                            }

                            @java.lang.Override
                            public void onError(Ad ad, AdError adError) {
                                Log.e(TAG, "Interstitial ad failed to load: " + adError.getErrorMessage());
                            }

                            @java.lang.Override
                            public void onAdLoaded(Ad ad) {
                                Log.d(TAG, "Interstitial ad is loaded and ready to be displayed! time out=>" + timeOut);
                                if (!timeOut) {
                                    interstitialAd.show();
                                }
                            }

                            @java.lang.Override
                            public void onAdClicked(Ad ad) {
                            }

                            @java.lang.Override
                            public void onLoggingImpression(Ad ad) {
                            }
                        }).build()
     */
}
