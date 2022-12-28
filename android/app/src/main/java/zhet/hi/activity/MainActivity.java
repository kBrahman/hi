package zhet.hi.activity;

import android.Manifest;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import com.facebook.ads.Ad;
import com.facebook.ads.AdError;
import com.facebook.ads.InterstitialAd;
import com.facebook.ads.InterstitialAdListener;
import com.facebook.flipper.android.AndroidFlipperClient;
import com.facebook.flipper.android.utils.FlipperUtils;
import com.facebook.flipper.core.FlipperClient;
import com.facebook.flipper.plugins.databases.DatabasesFlipperPlugin;
import com.facebook.flipper.plugins.sharedpreferences.SharedPreferencesFlipperPlugin;
import com.facebook.soloader.SoLoader;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import zhet.hi.BuildConfig;
import zhet.hi.factory.NativeViewFactory;
import zhet.hi.lambda.AllMatchTest;
import zhet.hi.util.AudienceNetworkInitializer;

public class MainActivity extends FlutterFragmentActivity implements InterstitialAdListener {
    private static final String TAG = "MainActivity";
    private static final String IS_LOADED = "isLoaded";
    private static final String SHOW = "show";
    private static final String GET_PACKAGE_NAME = "getPackageName";
    private static final String START_EMAIL_APP = "startEmailApp";
    private static final String ID_INTERSTITIAL = "3797187196981029_5287545084611892";
    private static final String UPDATE = "update";
    private static final String REQUEST_PERMISSIONS = "requestPermissions";
    private static final String CHECK_CONN = "checkConn";
    private static final String DEVICE_INFO = "deviceInfo";
    private static final String APP_SETTINGS = "appSettings";
    private static final int REQUEST_CODE_PERMISSIONS = 1;
    private static final int RESULT_PERMANENTLY_DENIED = 2;
    private static final int RESULT_GRANTED = 3;
    private static final int RESULT_DENIED = 4;
    private InterstitialAd interstitialAd;
    private Timer timer;
    private MethodChannel.Result result;
    private MethodChannel channel;
    private long tStart;

    @Override
    protected void onCreate(@Nullable android.os.Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SoLoader.init(this, false);
        if (BuildConfig.DEBUG && FlipperUtils.shouldEnableFlipper(this)) {
            FlipperClient client = AndroidFlipperClient.getInstance(this);
            client.addPlugin(new SharedPreferencesFlipperPlugin(this));
            client.addPlugin(new DatabasesFlipperPlugin(this));
            client.start();
        }
        AudienceNetworkInitializer.initialize(this);
        interstitialAd = new InterstitialAd(this, ID_INTERSTITIAL);
        loadAd();
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
        }, 31000);
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
        channel = new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "hi.channel/app");
        channel.setMethodCallHandler((call, result) -> {
            this.result = result;
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
                    final String appPackageName = getPackageName();
                    openGooglePlay(result, appPackageName, true);
                    break;
                case REQUEST_PERMISSIONS:
                    Log.i(TAG, "requestPermissions");
                    requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA}, REQUEST_CODE_PERMISSIONS);
                    break;
                case CHECK_CONN:
                    Log.i(TAG, "CHECK_CONN");
                    checkConn(this, result);
                    break;
                case DEVICE_INFO:
                    result.success(Map.of("model", android.os.Build.MODEL, "version", BuildConfig.VERSION_NAME, "code", BuildConfig.VERSION_CODE));
                    break;
                case APP_SETTINGS:
                    appSettings();
                    break;
            }
        });
        engine.getPlatformViewsController().getRegistry().registerViewFactory("medium_rectangle", new NativeViewFactory());
    }

    private void appSettings() {
        Intent settingsIntent = new Intent();
        settingsIntent.setAction(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        settingsIntent.addCategory(Intent.CATEGORY_DEFAULT);
        settingsIntent.setData(android.net.Uri.parse("package:" + getPackageName()));
        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY);
        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS);
        startActivity(settingsIntent);
    }

    private void checkConn(Context context, MethodChannel.Result result) {
        Log.i(TAG, "checkConn");
        NetworkRequest networkRequest = new NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).addTransportType(NetworkCapabilities.TRANSPORT_WIFI).addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR).build();
        ConnectivityManager cm = ContextCompat.getSystemService(context, ConnectivityManager.class);
        Log.i(TAG, "checkConn cm=" + cm);
        if (cm == null) result.success(false);
        else {
            result.success(true);
            ConnectivityManager.NetworkCallback networkCallback = new ConnectivityManager.NetworkCallback() {
                @Override
                public void onAvailable(@NonNull Network network) {
                    super.onAvailable(network);
                    runOnUiThread(() -> channel.invokeMethod("onAvailable", null));
                    Log.i(TAG, "onAvailable");
                }

                @Override
                public void onLost(@NonNull Network network) {
                    super.onLost(network);
                    runOnUiThread(() -> channel.invokeMethod("onLost", null));
                    Log.i(TAG, "onLost");
                }
            };
            cm.registerNetworkCallback(networkRequest, networkCallback);
        }
    }


    @Override
    protected void onPause() {
        tStart = System.currentTimeMillis();
        Log.i(TAG, "pause");
        super.onPause();
    }


    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        Log.i(TAG, "grant res: " + Arrays.toString(grantResults));
        Log.i(TAG, "request code: " + requestCode);
        long tEnd = System.currentTimeMillis();
        Log.i(TAG, "tDiff: " + (tEnd - tStart));
        if (allMatch(grantResults, res -> res == PackageManager.PERMISSION_GRANTED)) {
            result.success(RESULT_GRANTED);
            Log.i(TAG, "granted");
        } else if (tEnd - tStart < 500) {
            result.success(RESULT_PERMANENTLY_DENIED);
            Log.i(TAG, "RESULT_PERMANENTLY_DENIED");
        } else result.success(RESULT_DENIED);
        tStart = 0;
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    private boolean allMatch(int[] grantResults, AllMatchTest tester) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) return Arrays.stream(grantResults).allMatch(tester::test);
        for (int res : grantResults) if (!tester.test(res)) return false;
        return true;
    }

    private void openGooglePlay(MethodChannel.Result result, String appPackageName, boolean firstTime) {
        try {
            if (firstTime) startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + appPackageName)));
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
}
