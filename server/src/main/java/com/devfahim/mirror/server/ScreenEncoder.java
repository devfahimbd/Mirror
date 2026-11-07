package com.devfahim.mirror.server;

import android.graphics.Point;
import android.graphics.Rect;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.os.IBinder;
import android.view.Surface;

import java.io.DataOutputStream;
import java.io.IOException;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Captures screen frames and encodes them into low-latency H.264 video using hardware MediaCodec.
 */
public final class ScreenEncoder {
    private static final int DEFAULT_I_FRAME_INTERVAL = 1; // 1 second
    private static final int TIMEOUT_US = 10_000;

    private final Options options;
    private final Device device;
    private MediaCodec codec;
    private IBinder display;
    private Surface inputSurface;

    public ScreenEncoder(Options options, Device device) {
        this.options = options;
        this.device = device;
    }

    public void streamScreen(DataOutputStream out) throws Exception {
        device.refreshDisplayInfo();
        Point screenSize = device.getScreenSize();
        Point videoSize = device.computeVideoSize(options.getMaxResolution());

        Ln.i("Starting screen encoder: Screen " + screenSize.x + "x" + screenSize.y + 
             ", Video " + videoSize.x + "x" + videoSize.y + 
             ", Bitrate " + (options.getMaxBitRate() / 1_000_000) + "Mbps" +
             ", FPS " + options.getMaxFps());

        // Send header to client: Magic "MIRR" (0x4D495252), screen W/H, video W/H
        out.writeInt(0x4D495252);
        out.writeInt(screenSize.x);
        out.writeInt(screenSize.y);
        out.writeInt(videoSize.x);
        out.writeInt(videoSize.y);
        out.flush();

        codec = MediaCodec.createEncoderByType("video/avc");
        MediaFormat format = MediaFormat.createVideoFormat("video/avc", videoSize.x, videoSize.y);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
        format.setInteger(MediaFormat.KEY_BIT_RATE, options.getMaxBitRate());
        format.setInteger(MediaFormat.KEY_FRAME_RATE, options.getMaxFps());
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, DEFAULT_I_FRAME_INTERVAL);
        format.setLong(MediaFormat.KEY_REPEAT_PREVIOUS_FRAME_AFTER, 100_000); // 100ms

        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
        inputSurface = codec.createInputSurface();
        codec.start();

        setDisplaySurface(display, inputSurface, screenSize, videoSize);

        encodeLoop(out);
    }

    private void setDisplaySurface(IBinder token, Surface surface, Point screen, Point video) {
        try {
            Class<?> scClass = Class.forName("android.view.SurfaceControl");
            Method createDisplay = scClass.getMethod("createDisplay", String.class, boolean.class);
            this.display = (IBinder) createDisplay.invoke(null, "mirror-display", false);

            Method openTransaction = scClass.getMethod("openTransaction");
            Method closeTransaction = scClass.getMethod("closeTransaction");
            Method setDisplaySurface = scClass.getMethod("setDisplaySurface", IBinder.class, Surface.class);
            Method setDisplayProjection = scClass.getMethod("setDisplayProjection", IBinder.class, int.class, Rect.class, Rect.class);
            Method setDisplayLayerStack = scClass.getMethod("setDisplayLayerStack", IBinder.class, int.class);

            openTransaction.invoke(null);
            setDisplaySurface.invoke(null, this.display, surface);
            setDisplayProjection.invoke(null, this.display, 0, new Rect(0, 0, screen.x, screen.y), new Rect(0, 0, video.x, video.y));
            setDisplayLayerStack.invoke(null, this.display, 0);
            closeTransaction.invoke(null);
            Ln.i("Virtual display projection configured successfully");
        } catch (Throwable t) {
            Ln.w("SurfaceControl reflection error: " + t.getMessage());
        }
    }

    private void encodeLoop(DataOutputStream out) throws IOException {
        MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
        byte[] transferBuffer = new byte[128 * 1024];

        try {
            while (true) {
                int index = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US);
                if (index >= 0) {
                    ByteBuffer buffer = codec.getOutputBuffer(index);
                    if (buffer != null) {
                        buffer.position(bufferInfo.offset);
                        buffer.limit(bufferInfo.offset + bufferInfo.size);

                        int length = bufferInfo.size;
                        // Protocol: [flags: 4B][pts: 8B][size: 4B][data: size bytes]
                        out.writeInt(bufferInfo.flags);
                        out.writeLong(bufferInfo.presentationTimeUs);
                        out.writeInt(length);

                        while (length > 0) {
                            int toRead = Math.min(length, transferBuffer.length);
                            buffer.get(transferBuffer, 0, toRead);
                            out.write(transferBuffer, 0, toRead);
                            length -= toRead;
                        }
                        out.flush();
                    }
                    codec.releaseOutputBuffer(index, false);
                } else if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    Ln.i("MediaCodec output format changed: " + codec.getOutputFormat());
                }
            }
        } finally {
            destroy();
        }
    }

    public void destroy() {
        if (display != null) {
            try {
                Class<?> scClass = Class.forName("android.view.SurfaceControl");
                Method destroyDisplay = scClass.getMethod("destroyDisplay", IBinder.class);
                destroyDisplay.invoke(null, display);
            } catch (Throwable ignored) {}
        }
        if (codec != null) {
            try {
                codec.stop();
                codec.release();
            } catch (Throwable ignored) {}
        }
        if (inputSurface != null) {
            inputSurface.release();
        }
    }
}

