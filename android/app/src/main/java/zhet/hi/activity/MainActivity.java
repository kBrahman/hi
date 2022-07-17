package zhet.hi.activity;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.ads.Ad;
import com.facebook.ads.AdError;
import com.facebook.ads.AdSettings;
import com.facebook.ads.InterstitialAd;
import com.facebook.ads.InterstitialAdListener;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import zhet.hi.BuildConfig;
import zhet.hi.factory.NativeViewFactory;
import zhet.hi.util.AudienceNetworkInitializer;

public class MainActivity extends FlutterFragmentActivity {
    private static final String TAG = "MainActivity";
    private static final String IS_LOADED = "isLoaded";
    private static final String SHOW = "show";
    private static final String GET_PACKAGE_NAME = "getPackageName";
    private static final String START_EMAIL_APP = "startEmailApp";
    private static final String VIBRATE = "vibrate";
    private InterstitialAd interstitialAd;

    @Override
    protected void onCreate(@Nullable android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
//        SoLoader.init(this, false);
//
//        if (BuildConfig.DEBUG && FlipperUtils.shouldEnableFlipper(this)) {
//            FlipperClient client = AndroidFlipperClient.getInstance(this);
//            client.addPlugin(new SharedPreferencesFlipperPlugin(this));
//            client.addPlugin(new DatabasesFlipperPlugin(this));
//            client.start();
//        }
        AudienceNetworkInitializer.initialize(this);
        interstitialAd = new InterstitialAd(this, "3797187196981029_5287545084611892");
        if (BuildConfig.DEBUG) AdSettings.addTestDevice("706687f7-729e-46db-bc9e-db6ade23d591");
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
                                Log.d(TAG, "Interstitial ad is loaded and ready to be displayed!");

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
                case GET_PACKAGE_NAME:
                    result.success(BuildConfig.APPLICATION_ID);
                    break;
                case IS_LOADED:
                    result.success(interstitialAd.isAdLoaded());
                    break;
                case SHOW:
                    interstitialAd.show();
                    break;
                case START_EMAIL_APP:
                    try {
                        Intent intent = new Intent(Intent.ACTION_MAIN);
                        intent.addCategory(Intent.CATEGORY_APP_EMAIL);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(intent);
                        result.success(true);
                    } catch (ActivityNotFoundException e) {
                        result.error("404", e.getMessage(), e);
                    }
                    break;
                case VIBRATE:
                    Vibrator v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        v.vibrate(VibrationEffect.createOneShot(240, 15));
                    else v.vibrate(240);

            }
        });
        engine.getPlatformViewsController().
                getRegistry().
                registerViewFactory("medium_rectangle", new NativeViewFactory());
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
