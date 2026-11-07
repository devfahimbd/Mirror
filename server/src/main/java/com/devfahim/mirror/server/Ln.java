package com.devfahim.mirror.server;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Lightweight logging utility.
 */
public final class Ln {
    private static final String TAG = "MirrorServer";

    private Ln() {}

    public static void i(String message) {
        System.out.println("[" + TAG + "] [INFO] " + message);
    }

    public static void d(String message) {
        System.out.println("[" + TAG + "] [DEBUG] " + message);
    }

    public static void w(String message) {
        System.err.println("[" + TAG + "] [WARN] " + message);
    }

    public static void e(String message, Throwable throwable) {
        System.err.println("[" + TAG + "] [ERROR] " + message);
        if (throwable != null) {
            throwable.printStackTrace(System.err);
        }
    }
}

