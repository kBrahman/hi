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
import com.facebook.ads.InterstitialAd;
import com.facebook.ads.InterstitialAdListener;

import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import zhet.hi.BuildConfig;
import zhet.hi.factory.NativeViewFactory;
import zhet.hi.util.AudienceNetworkInitializer;

public class MainActivity extends FlutterFragmentActivity implements InterstitialAdListener {
    private static final String TAG = "MainActivity";
    private static final String IS_LOADED = "isLoaded";
    private static final String SHOW = "show";
    private static final String GET_PACKAGE_NAME = "getPackageName";
    private static final String START_EMAIL_APP = "startEmailApp";
    private static final String ID_INTERSTITIAL = "3797187196981029_5287545084611892";
    private static final String UPDATE = "update";
    private InterstitialAd interstitialAd;
    private Timer timer;

    @Override
    protected void onCreate(@Nullable android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
//        SoLoader.init(this, false);
//        if (BuildConfig.DEBUG && FlipperUtils.shouldEnableFlipper(this)) {
//            FlipperClient client = AndroidFlipperClient.getInstance(this);
//            client.addPlugin(new SharedPreferencesFlipperPlugin(this));
//            client.addPlugin(new DatabasesFlipperPlugin(this));
//            client.start();
//        }
        AudienceNetworkInitializer.initialize(this);
        interstitialAd = new InterstitialAd(this, ID_INTERSTITIAL);
        loadAd();
        Log.i(TAG, "on create");
    }

    @Override
    public void onInterstitialDisplayed(Ad ad) {
        Log.e(TAG, "Interstitial ad displayed.");
    }

    @Override
    public void onInterstitialDismissed(Ad ad) {
        loadAd();
    }

    @Override
    public void onError(Ad ad, AdError adError) {
        Log.e(TAG, "Interstitial ad failed to load: " + adError.getErrorMessage() + ", invalidated=>" + interstitialAd.isAdInvalidated());
        (timer = new Timer()).schedule(new TimerTask() {
            @Override
            public void run() {
                loadAd();
            }
        }, 30000);
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


    private void loadAd() {
        interstitialAd.loadAd(interstitialAd.buildLoadAdConfig().withAdListener(this).build());
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
                    interstitialAd.isAdInvalidated();
                    result.success(interstitialAd.isAdLoaded());
                    break;
                case SHOW:
                    interstitialAd.show();
                    result.success(true);
                    break;
                case START_EMAIL_APP:
                    openEmail(call, result, false);
                    break;
                case UPDATE:
                    final String appPackageName = getPackageName(); // getPackageName() from Context or Activity object
                    openGooglePlay(result, appPackageName, true);
            }
        });
        engine.getPlatformViewsController().
                getRegistry().
                registerViewFactory("medium_rectangle", new NativeViewFactory());
    }

    private void openGooglePlay(MethodChannel.Result result, String appPackageName, boolean firstTime) {
        try {
            if (firstTime)
                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + appPackageName)));
            else
                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + appPackageName)));
        } catch (ActivityNotFoundException e) {
            if (firstTime) openGooglePlay(result, appPackageName, false);
            else result.success(false);
        }
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
        Log.i(TAG, "onDestroy");
        if (interstitialAd != null) interstitialAd.destroy();
        if (timer != null) timer.cancel();
        super.onDestroy();
    }

    @Override
    protected void onStart() {
        super.onStart();
        Log.i(TAG, "onStart");
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        boolean adInvalidated = interstitialAd.isAdInvalidated();
//        if (adInvalidated) loadAd();
        Log.i(TAG, "onRestart, adInvalidated=>" + adInvalidated);
    }
}
