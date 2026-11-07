package com.devfahim.mirror;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Color;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.text.format.Formatter;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.Enumeration;

/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * Ultra-lightweight native companion app.
 */
public class MainActivity extends AppCompatActivity {
    private static final int DEFAULT_PORT = 8099;

    private TextView tvDeviceIp;
    private TextView tvStatusTitle;
    private TextView tvStatusDesc;
    private Button btnCopyIp;
    private Button btnToggleService;

    private boolean isServiceActive = false;
    private ServerSocket serverSocket;
    private Thread listenerThread;
    private String currentIp = "127.0.0.1";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tvDeviceIp = findViewById(R.id.tvDeviceIp);
        tvStatusTitle = findViewById(R.id.tvStatusTitle);
        tvStatusDesc = findViewById(R.id.tvStatusDesc);
        btnCopyIp = findViewById(R.id.btnCopyIp);
        btnToggleService = findViewById(R.id.btnToggleService);

        discoverLocalIp();

        btnCopyIp.setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            ClipData clip = ClipData.newPlainText("Mirror IP", currentIp + ":" + DEFAULT_PORT);
            if (clipboard != null) {
                clipboard.setPrimaryClip(clip);
                Toast.makeText(this, "Copied " + currentIp + ":" + DEFAULT_PORT, Toast.LENGTH_SHORT).show();
            }
        });

        btnToggleService.setOnClickListener(v -> toggleService());
    }

    private void discoverLocalIp() {
        try {
            for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements(); ) {
                NetworkInterface intf = en.nextElement();
                for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements(); ) {
                    InetAddress inetAddress = enumIpAddr.nextElement();
                    if (!inetAddress.isLoopbackAddress() && inetAddress instanceof Inet4Address) {
                        currentIp = inetAddress.getHostAddress();
                        tvDeviceIp.setText(currentIp);
                        return;
                    }
                }
            }
        } catch (Exception ignored) {}

        // Fallback to WifiManager
        try {
            WifiManager wm = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
            if (wm != null) {
                int ip = wm.getConnectionInfo().getIpAddress();
                if (ip != 0) {
                    currentIp = Formatter.formatIpAddress(ip);
                    tvDeviceIp.setText(currentIp);
                }
            }
        } catch (Exception ignored) {}
    }

    private void toggleService() {
        if (isServiceActive) {
            stopServiceListener();
        } else {
            startServiceListener();
        }
    }

    private void startServiceListener() {
        try {
            serverSocket = new ServerSocket(DEFAULT_PORT);
            isServiceActive = true;
            tvStatusTitle.setText("Wireless Listener Active");
            tvStatusTitle.setTextColor(Color.parseColor("#00E676"));
            tvStatusDesc.setText("Broadcasting on port " + DEFAULT_PORT + ". Enter " + currentIp + " on your PC Mirror app.");
            btnToggleService.setText("Stop Wireless Service");
            btnToggleService.setBackgroundColor(Color.parseColor("#D32F2F"));

            listenerThread = new Thread(() -> {
                while (isServiceActive && serverSocket != null && !serverSocket.isClosed()) {
                    try {
                        Socket client = serverSocket.accept();
                        client.getOutputStream().write("MIRROR_MOBILE_ACTIVE\n".getBytes());
                        client.close();
                    } catch (Exception ignored) {}
                }
            });
            listenerThread.start();
            Toast.makeText(this, "Wireless service started", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Failed to bind port: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void stopServiceListener() {
        isServiceActive = false;
        try {
            if (serverSocket != null) {
                serverSocket.close();
            }
        } catch (Exception ignored) {}
        tvStatusTitle.setText("Wireless Listener Standby");
        tvStatusTitle.setTextColor(Color.WHITE);
        tvStatusDesc.setText("Turn on wireless mode if you wish to connect from PC over Wi-Fi without any USB cable.");
        btnToggleService.setText("Start Wireless Service");
        btnToggleService.setBackgroundResource(R.drawable.btn_gradient);
        Toast.makeText(this, "Wireless service stopped", Toast.LENGTH_SHORT).show();
    }

    @Override
    protected void onDestroy() {
        stopServiceListener();
        super.onDestroy();
    }
}

