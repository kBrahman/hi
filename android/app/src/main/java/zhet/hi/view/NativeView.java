package zhet.hi.view;

import android.content.Context;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;

import com.facebook.ads.Ad;
import com.facebook.ads.AdError;
import com.facebook.ads.AdListener;
import com.facebook.ads.AdSize;
import com.facebook.ads.AdView;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class NativeView implements PlatformView {
    private static final String TAG = "NativeView";
    @NonNull
    private final AdView adView;

    public NativeView(@NonNull Context context, MethodChannel channel) {
        adView = new AdView(context, "3797187196981029_3797192466980502", AdSize.RECTANGLE_HEIGHT_250);
        adView.loadAd(adView.buildLoadAdConfig().withAdListener(new AdListener() {
            @Override
            public void onError(Ad ad, AdError adError) {

            }

            @Override
            public void onAdLoaded(Ad ad) {
                Log.i(TAG, "on ad loaded");
            }

            @Override
            public void onAdClicked(Ad ad) {
                Log.i(TAG, "on ad clicked");
                channel.invokeMethod("pop", null);
            }

            @Override
            public void onLoggingImpression(Ad ad) {

            }
        }).build());
    }

    @NonNull
    @Override
    public View getView() {
        return adView;
    }

    @Override
    public void dispose() {
        adView.destroy();
    }
}

