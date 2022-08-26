package zhet.hi.activity;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.ads.Ad;
import com.facebook.ads.AdError;
import com.facebook.ads.AdSettings;
import com.facebook.ads.InterstitialAd;
import com.facebook.ads.InterstitialAdListener;

import java.util.List;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
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
        if (BuildConfig.DEBUG) AdSettings.addTestDevice("7ee72a5f-c97c-49ac-811f-0c055a5a56be");
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
                    openEmail(call, result, false);

            }
        });
        engine.getPlatformViewsController().
                getRegistry().
                registerViewFactory("medium_rectangle", new NativeViewFactory());
    }

    private void openEmail(MethodCall call, MethodChannel.Result result, boolean useBrowser) {
        try {
            Intent intent;
            Log.i(TAG, "args=>" + call.arguments());
            List<String> w = call.arguments();
            String domain = w.get(0);
            Log.i(TAG, "domain=>" + domain);
            if (useBrowser) {
                intent = new Intent(Intent.ACTION_VIEW, Uri.parse("http://" + domain));
            } else if ((intent = getIntentForCertainClients(domain)) == null) {
                intent = new Intent(Intent.ACTION_MAIN);
                intent.addCategory(Intent.CATEGORY_APP_EMAIL);
            }
//            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            result.success(true);
            finish();
        } catch (ActivityNotFoundException e) {
            if (!useBrowser) openEmail(call, result, true);
            else result.error("404", e.getMessage(), e);
        }
    }

    private Intent getIntentForCertainClients(String domain) {
        PackageManager manager = getPackageManager();
        if (domain.equals("outlook.com")) return manager.getLaunchIntentForPackage("com.microsoft.office.outlook");
        if (domain.matches("yandex\\..+")) return manager.getLaunchIntentForPackage("ru.yandex.mail");
        if (domain.equals("gmail.com")) {
            final Intent intent = manager.getLaunchIntentForPackage("com.google.android.gm");
            Log.i(TAG, "gmail intent=>" + intent);
            return intent;
        }
        if (domain.matches("(rambler|lenta|autorambler|myrambler|ro)\\.(ru|ua)"))
            return manager.getLaunchIntentForPackage("ru.rambler.mail");
        if (domain.equals("yahoo.com")) return manager.getLaunchIntentForPackage("com.yahoo.mobile.client.android.mail");
        Log.i(TAG, "returning null intent");
        return null;
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
