package com.devfahim.mirror.server;

import android.graphics.Point;
import android.graphics.Rect;
import android.os.Build;
import android.os.IBinder;

import java.lang.reflect.Method;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Interacts with Android DisplayManager and SurfaceControl services.
 */
public final class Device {
    private final Point screenSize = new Point();
    private int rotation = 0;

    public Device() {
        refreshDisplayInfo();
    }

    public void refreshDisplayInfo() {
        try {
            // Retrieve display size via DisplayManagerGlobal or SurfaceControl
            Class<?> dmgClass = Class.forName("android.hardware.display.DisplayManagerGlobal");
            Method getInstanceMethod = dmgClass.getDeclaredMethod("getInstance");
            Object dmg = getInstanceMethod.invoke(null);

            Method getDisplayInfoMethod = dmgClass.getDeclaredMethod("getDisplayInfo", int.class);
            Object displayInfo = getDisplayInfoMethod.invoke(dmg, 0);

            if (displayInfo != null) {
                Class<?> displayInfoClass = displayInfo.getClass();
                int logicalWidth = displayInfoClass.getDeclaredField("logicalWidth").getInt(displayInfo);
                int logicalHeight = displayInfoClass.getDeclaredField("logicalHeight").getInt(displayInfo);
                this.rotation = displayInfoClass.getDeclaredField("rotation").getInt(displayInfo);
                this.screenSize.set(logicalWidth, logicalHeight);
            }
        } catch (Throwable t) {
            Ln.w("Could not get display info via DisplayManagerGlobal: " + t.getMessage());
            // Fallback default
            screenSize.set(1080, 2400);
            rotation = 0;
        }
    }

    public Point getScreenSize() {
        return screenSize;
    }

    public int getRotation() {
        return rotation;
    }

    /**
     * Compute target video size scaled according to maxResolution option,
     * maintaining aspect ratio and ensuring multiples of 8 (required by H.264 encoders).
     */
    public Point computeVideoSize(int maxResolution) {
        int width = screenSize.x;
        int height = screenSize.y;

        int major = Math.max(width, height);
        if (maxResolution > 0 && major > maxResolution) {
            float factor = (float) maxResolution / major;
            width = Math.round(width * factor);
            height = Math.round(height * factor);
        }

        // Align dimensions to 8 for video encoders
        width = (width + 7) & ~7;
        height = (height + 7) & ~7;

        return new Point(width, height);
    }
}

