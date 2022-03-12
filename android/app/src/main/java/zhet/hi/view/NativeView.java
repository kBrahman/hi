package zhet.hi.view;

import android.content.Context;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.ads.AdSize;
import com.facebook.ads.AdView;

import java.util.Map;

import io.flutter.plugin.platform.PlatformView;

public class NativeView implements PlatformView {
    @NonNull
    private final AdView adView;

    public NativeView(@NonNull Context context, int id, @Nullable Map<String, Object> creationParams) {
        adView = new AdView(context, "3797187196981029_3797192466980502", AdSize.RECTANGLE_HEIGHT_250);
        adView.loadAd();
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

