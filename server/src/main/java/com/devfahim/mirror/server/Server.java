package com.devfahim.mirror.server;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.ServerSocket;
import java.net.Socket;

/**
 * Mirror — Open-source Android screen mirroring and remote control
 * Author: Dev Fahim (devfahimbd)
 *
 * Main server entry point executed via app_process.
 */
public final class Server {
    public static void main(String[] args) {
        Thread.setDefaultUncaughtExceptionHandler((t, e) -> Ln.e("Uncaught exception: " + e.getMessage(), e));

        Ln.i("Mirror Server v1.0 starting...");
        Options options = Options.parse(args);
        Device device = new Device();

        int videoPort = options.getPort();
        int controlPort = options.getPort() + 1;

        try (ServerSocket videoServerSocket = new ServerSocket(videoPort);
             ServerSocket controlServerSocket = new ServerSocket(controlPort)) {

            Ln.i("Waiting for client connection on ports " + videoPort + " (video) and " + controlPort + " (control)...");

            Socket videoSocket = videoServerSocket.accept();
            Ln.i("Video client connected from " + videoSocket.getRemoteSocketAddress());
            videoSocket.setTcpNoDelay(true);

            Socket controlSocket = controlServerSocket.accept();
            Ln.i("Control client connected from " + controlSocket.getRemoteSocketAddress());
            controlSocket.setTcpNoDelay(true);

            Controller controller;
            try {
                controller = new Controller();
            } catch (Exception e) {
                Ln.e("Failed to initialize Controller: " + e.getMessage(), e);
                controller = null;
            }

            // Start control handler thread
            final Controller finalController = controller;
            Thread controlThread = new Thread(() -> {
                if (finalController != null) {
                    try (DataInputStream in = new DataInputStream(controlSocket.getInputStream())) {
                        finalController.handleControlStream(in, device);
                    } catch (Exception e) {
                        Ln.i("Control channel disconnected: " + e.getMessage());
                    }
                }
            }, "control-thread");
            controlThread.start();

            // Stream video on main thread
            ScreenEncoder screenEncoder = new ScreenEncoder(options, device);
            try (DataOutputStream out = new DataOutputStream(videoSocket.getOutputStream())) {
                screenEncoder.streamScreen(out);
            } catch (Exception e) {
                Ln.i("Video channel disconnected: " + e.getMessage());
            } finally {
                screenEncoder.destroy();
            }

        } catch (Exception e) {
            Ln.e("Server error: " + e.getMessage(), e);
            System.exit(1);
        }

        Ln.i("Mirror Server finished cleanly.");
        System.exit(0);
    }
}

