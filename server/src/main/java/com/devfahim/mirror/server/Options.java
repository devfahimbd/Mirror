package com.devfahim.mirror.server;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Runtime configuration options passed from client.
 */
public final class Options {
    private int maxBitRate = 8_000_000; // 8 Mbps
    private int maxResolution = 1080;   // 1080p
    private int maxFps = 60;            // 60 FPS
    private int port = 8099;            // Default listening port
    private boolean tunnelForward = false;

    public static Options parse(String[] args) {
        Options options = new Options();
        for (String arg : args) {
            if (arg.startsWith("bitrate=")) {
                options.maxBitRate = Integer.parseInt(arg.substring(8));
            } else if (arg.startsWith("max_size=")) {
                options.maxResolution = Integer.parseInt(arg.substring(9));
            } else if (arg.startsWith("max_fps=")) {
                options.maxFps = Integer.parseInt(arg.substring(8));
            } else if (arg.startsWith("port=")) {
                options.port = Integer.parseInt(arg.substring(5));
            } else if (arg.equals("tunnel_forward=true")) {
                options.tunnelForward = true;
            }
        }
        return options;
    }

    public int getMaxBitRate() { return maxBitRate; }
    public int getMaxResolution() { return maxResolution; }
    public int getMaxFps() { return maxFps; }
    public int getPort() { return port; }
    public boolean isTunnelForward() { return tunnelForward; }
}

