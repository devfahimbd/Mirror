package com.devfahim.mirror.server;

import android.graphics.Bitmap;
import android.graphics.PixelFormat;
import android.graphics.Point;
import android.graphics.Rect;
import android.media.Image;
import android.media.ImageReader;
import android.os.IBinder;
import android.view.Surface;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Captures screen frames using hardware ImageReader or SurfaceControl reflection
 * and streams high-frequency, low-latency compressed JPEG frames to the PC client.
 */
public final class ScreenEncoder {
    private static final int MAGIC_HEADER = 0x4D495252; // "MIRR"
    private static final int MAGIC_FRAME  = 0x46524D45; // "FRME"

    private final Options options;
    private final Device device;
    private IBinder display;
    private ImageReader imageReader;
    private Surface surface;
    private volatile boolean running = true;

    public ScreenEncoder(Options options, Device device) {
        this.options = options;
        this.device = device;
    }

    public void streamScreen(DataOutputStream out) throws Exception {
        device.refreshDisplayInfo();
        Point screenSize = device.getScreenSize();
        Point videoSize = device.computeVideoSize(options.getMaxResolution());

        Ln.i("Starting Frame Streamer: Screen " + screenSize.x + "x" + screenSize.y +
             ", Target Viewport " + videoSize.x + "x" + videoSize.y +
             ", Max FPS " + options.getMaxFps());

        // Protocol Header: [MIRR: 4B][screenWidth: 4B][screenHeight: 4B][videoWidth: 4B][videoHeight: 4B]
        out.writeInt(MAGIC_HEADER);
        out.writeInt(screenSize.x);
        out.writeInt(screenSize.y);
        out.writeInt(videoSize.x);
        out.writeInt(videoSize.y);
        out.flush();

        // Attempt 1: Setup Hardware ImageReader VirtualDisplay
        boolean hardwareSetupOk = false;
        try {
            imageReader = ImageReader.newInstance(videoSize.x, videoSize.y, PixelFormat.RGBA_8888, 2);
            surface = imageReader.getSurface();
            setupVirtualDisplay(surface, screenSize, videoSize);
            hardwareSetupOk = true;
            Ln.i("Hardware ImageReader Surface configured successfully");
        } catch (Throwable t) {
            Ln.w("Hardware ImageReader setup failed, falling back to SurfaceControl screenshot: " + t.getMessage());
        }

        if (hardwareSetupOk && imageReader != null) {
            runImageReaderLoop(out, videoSize.x, videoSize.y);
        } else {
            runScreenshotFallbackLoop(out, videoSize.x, videoSize.y);
        }
    }

    private void setupVirtualDisplay(Surface targetSurface, Point screen, Point video) throws Exception {
        Class<?> scClass = Class.forName("android.view.SurfaceControl");
        Method createDisplay = scClass.getMethod("createDisplay", String.class, boolean.class);
        this.display = (IBinder) createDisplay.invoke(null, "mirror-display", false);

        Method openTransaction = scClass.getMethod("openTransaction");
        Method closeTransaction = scClass.getMethod("closeTransaction");
        Method setDisplaySurface = scClass.getMethod("setDisplaySurface", IBinder.class, Surface.class);
        Method setDisplayProjection = scClass.getMethod("setDisplayProjection", IBinder.class, int.class, Rect.class, Rect.class);
        Method setDisplayLayerStack = scClass.getMethod("setDisplayLayerStack", IBinder.class, int.class);

        openTransaction.invoke(null);
        try {
            setDisplaySurface.invoke(null, this.display, targetSurface);
            setDisplayProjection.invoke(null, this.display, 0, new Rect(0, 0, screen.x, screen.y), new Rect(0, 0, video.x, video.y));
            setDisplayLayerStack.invoke(null, this.display, 0);
        } finally {
            closeTransaction.invoke(null);
        }
    }

    private void runImageReaderLoop(DataOutputStream out, int width, int height) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream(64 * 1024);
        int frameIntervalMs = 1000 / Math.max(1, options.getMaxFps());
        long lastFrameTime = 0;

        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

        while (running) {
            long now = System.currentTimeMillis();
            if (now - lastFrameTime < frameIntervalMs) {
                try {
                    Thread.sleep(Math.max(1, frameIntervalMs - (now - lastFrameTime)));
                } catch (InterruptedException ignored) {}
            }

            Image image = null;
            try {
                image = imageReader.acquireLatestImage();
                if (image != null) {
                    Image.Plane[] planes = image.getPlanes();
                    ByteBuffer buffer = planes[0].getBuffer();
                    int pixelStride = planes[0].getPixelStride();
                    int rowStride = planes[0].getRowStride();
                    int rowPadding = rowStride - pixelStride * width;

                    bitmap.copyPixelsFromBuffer(buffer);

                    baos.reset();
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 75, baos);
                    byte[] jpegBytes = baos.toByteArray();

                    // Send Frame Packet: [FRME: 4B][length: 4B][bytes...]
                    out.writeInt(MAGIC_FRAME);
                    out.writeInt(jpegBytes.length);
                    out.write(jpegBytes);
                    out.flush();

                    lastFrameTime = System.currentTimeMillis();
                }
            } catch (Exception e) {
                // If hardware image reader throws, fallback to screenshot loop
                Ln.w("ImageReader loop error, switching to screenshot fallback: " + e.getMessage());
                break;
            } finally {
                if (image != null) {
                    image.close();
                }
            }
        }

        if (running) {
            runScreenshotFallbackLoop(out, width, height);
        }
    }

    private void runScreenshotFallbackLoop(DataOutputStream out, int width, int height) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream(64 * 1024);
        int frameIntervalMs = 1000 / Math.max(1, options.getMaxFps());
        long lastFrameTime = 0;

        Method screenshotMethod = null;
        try {
            Class<?> scClass = Class.forName("android.view.SurfaceControl");
            try {
                screenshotMethod = scClass.getMethod("screenshot", int.class, int.class);
            } catch (NoSuchMethodException e) {
                try {
                    screenshotMethod = scClass.getMethod("screenshot", Rect.class, int.class, int.class, int.class);
                } catch (NoSuchMethodException e2) {
                    screenshotMethod = scClass.getMethod("screenshot", IBinder.class, Rect.class, int.class, int.class, int.class, boolean.class);
                }
            }
        } catch (Throwable t) {
            Ln.w("Could not find SurfaceControl screenshot method: " + t.getMessage());
        }

        while (running) {
            long now = System.currentTimeMillis();
            if (now - lastFrameTime < frameIntervalMs) {
                try {
                    Thread.sleep(Math.max(1, frameIntervalMs - (now - lastFrameTime)));
                } catch (InterruptedException ignored) {}
            }

            Bitmap bitmap = null;
            if (screenshotMethod != null) {
                try {
                    if (screenshotMethod.getParameterTypes().length == 2) {
                        bitmap = (Bitmap) screenshotMethod.invoke(null, width, height);
                    }
                } catch (Throwable ignored) {}
            }

            if (bitmap != null) {
                baos.reset();
                bitmap.compress(Bitmap.CompressFormat.JPEG, 75, baos);
                byte[] jpegBytes = baos.toByteArray();
                bitmap.recycle();

                out.writeInt(MAGIC_FRAME);
                out.writeInt(jpegBytes.length);
                out.write(jpegBytes);
                out.flush();

                lastFrameTime = System.currentTimeMillis();
            } else {
                try {
                    Thread.sleep(30);
                } catch (InterruptedException ignored) {}
            }
        }
    }

    public void destroy() {
        running = false;
        if (display != null) {
            try {
                Class<?> scClass = Class.forName("android.view.SurfaceControl");
                Method destroyDisplay = scClass.getMethod("destroyDisplay", IBinder.class);
                destroyDisplay.invoke(null, display);
            } catch (Throwable ignored) {}
            display = null;
        }
        if (imageReader != null) {
            imageReader.close();
            imageReader = null;
        }
        if (surface != null) {
            surface.release();
            surface = null;
        }
    }
}
