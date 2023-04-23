package zhet.hi.factory;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import zhet.hi.view.NativeView;

public class NativeViewFactory extends PlatformViewFactory {

    private final MethodChannel channel;

    public NativeViewFactory(MethodChannel channel) {
        super(StandardMessageCodec.INSTANCE);
        this.channel = channel;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
        return new NativeView(context, channel);
    }
}
