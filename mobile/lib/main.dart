/**
 * Mirror — Open-Source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * Mobile Companion App:
 * Provides wireless pairing IP, server status, zero-install USB instructions,
 * and high-performance device configuration.
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0E14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MirrorMobileApp());
}

class MirrorMobileApp extends StatelessWidget {
  const MirrorMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirror',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        primaryColor: const Color(0xFFFF6D00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6D00),
          secondary: Color(0xFFFF9100),
          surface: Color(0xFF14161F),
          background: Color(0xFF0B0C10),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const MobileHomeScreen(),
    );
  }
}

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with SingleTickerProviderStateMixin {
  String _deviceIp = 'Discovering...';
  bool _isServiceActive = false;
  int _port = 8099;
  String _selectedResolution = '1080p (FHD)';
  int _selectedBitrate = 8; // Mbps
  int _selectedFps = 60;
  bool _keepScreenAwake = true;
  late AnimationController _pulseController;

  ServerSocket? _wirelessSocketServer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _discoverLocalIp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wirelessSocketServer?.close();
    super.dispose();
  }

  Future<void> _discoverLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            setState(() {
              _deviceIp = addr.address;
            });
            return;
          }
        }
      }
      setState(() {
        _deviceIp = 'No Wi-Fi Connection';
      });
    } catch (e) {
      setState(() {
        _deviceIp = '127.0.0.1';
      });
    }
  }

  Future<void> _toggleService() async {
    if (_isServiceActive) {
      await _wirelessSocketServer?.close();
      _wirelessSocketServer = null;
      setState(() {
        _isServiceActive = false;
      });
      _showToast('Mirror wireless listener stopped');
    } else {
      try {
        _wirelessSocketServer = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
        _wirelessSocketServer!.listen((client) {
          // Handshake connection from PC
          client.write('MIRROR_MOBILE_READY:$_selectedResolution:$_selectedFps\n');
        });
        setState(() {
          _isServiceActive = true;
        });
        _showToast('Mirror wireless listener running on port $_port');
      } catch (e) {
        _showToast('Could not bind port $_port: $e');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E212D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildConnectionCard(),
              const SizedBox(height: 20),
              _buildMainActionCard(),
              const SizedBox(height: 20),
              _buildZeroInstallGuideCard(),
              const SizedBox(height: 20),
              _buildSettingsCard(),
              const SizedBox(height: 24),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6D00), Color(0xFFFF9E80)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.screen_share_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Mirror',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.5)),
                    ),
                    child: const Text(
                      'v1.0',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9100)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'By Dev Fahim • Ultra-low latency Android Mirroring',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.wifi_rounded, color: const Color(0xFFFF9100), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Device Wi-Fi Address',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white54),
                tooltip: 'Refresh IP',
                onPressed: _discoverLocalIp,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1017),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deviceIp,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Port: $_port',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$_deviceIp:$_port'));
                    _showToast('Copied $_deviceIp:$_port to clipboard!');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B181F),
            _isServiceActive ? const Color(0xFF2A1B0B) : const Color(0xFF14161F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isServiceActive ? const Color(0xFFFF6D00) : Colors.white.withOpacity(0.08),
          width: _isServiceActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isServiceActive ? const Color(0xFF00E676) : Colors.grey,
                      boxShadow: _isServiceActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676).withOpacity(0.6 * _pulseController.value),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                _isServiceActive ? 'Wireless Listener Active' : 'Wireless Listener Standby',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isServiceActive ? const Color(0xFF00E676) : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _isServiceActive
                ? 'Your phone is broadcasting on port $_port. On PC Mirror app, enter "$_deviceIp" to connect wirelessly.'
                : 'Turn on wireless mode if you wish to connect from PC over Wi-Fi without any USB cable.',
            style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _toggleService,
              icon: Icon(_isServiceActive ? Icons.stop_circle_rounded : Icons.play_arrow_rounded, size: 22),
              label: Text(
                _isServiceActive ? 'Stop Wireless Service' : 'Start Wireless Service',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServiceActive ? const Color(0xFFD32F2F) : const Color(0xFFFF6D00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZeroInstallGuideCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.usb_rounded, color: Color(0xFFFF9100), size: 20),
              SizedBox(width: 8),
              Text(
                'Zero-Install USB Mode (Scrcpy-style)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideStep('1', 'Enable Developer Options and "USB Debugging" in phone settings.'),
          _buildGuideStep('2', 'Connect phone to PC with a USB cable.'),
          _buildGuideStep('3', 'Open mirror.exe on PC — it automatically starts mirroring instantly without requiring this app open!'),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.4)),
            ),
            child: Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9100))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, color: Color(0xFFFF9100), size: 20),
              SizedBox(width: 8),
              Text(
                'Streaming Preferences',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdownTile(
            title: 'Resolution',
            value: _selectedResolution,
            items: const ['720p (HD)', '1080p (FHD)', '1440p (2K)', 'Native'],
            onChanged: (val) => setState(() => _selectedResolution = val!),
          ),
          const Divider(color: Colors.white12, height: 20),
          _buildDropdownTile(
            title: 'Frame Rate',
            value: '$_selectedFps FPS',
            items: const ['30 FPS', '60 FPS', '120 FPS'],
            onChanged: (val) {
              setState(() {
                _selectedFps = int.parse(val!.split(' ')[0]);
              });
            },
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Video Bitrate', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  Text('$_selectedBitrate Mbps', style: const TextStyle(fontSize: 12, color: Color(0xFFFF9100), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _selectedBitrate.toDouble(),
                min: 2,
                max: 20,
                divisions: 9,
                activeColor: const Color(0xFFFF6D00),
                inactiveColor: Colors.white12,
                onChanged: (val) => setState(() => _selectedBitrate = val.toInt()),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Stay Awake while Mirroring', style: TextStyle(fontSize: 14, color: Colors.white70)),
            value: _keepScreenAwake,
            activeColor: const Color(0xFFFF6D00),
            onChanged: (val) => setState(() => _keepScreenAwake = val),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E212D),
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 14, color: Color(0xFFFF9100), fontWeight: FontWeight.bold),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          'Mirror Project • Developed by Dev Fahim',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 4),
        const Text(
          'Open-source on GitHub: github.com/devfahim/Mirror',
          style: TextStyle(fontSize: 11, color: Colors.white24),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
