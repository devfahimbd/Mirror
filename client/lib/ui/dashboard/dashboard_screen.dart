/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * DashboardScreen: Main Control Hub for device management, wireless pairing,
 * streaming preferences, and launching the detached Mirror Cinema process.
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/adb/adb_manager.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<AdbDevice> _devices = [];
  AdbDevice? _selectedDevice;
  bool _isLoadingDevices = false;
  Timer? _refreshTimer;

  final TextEditingController _wifiIpController = TextEditingController();
  bool _isConnectingWireless = false;

  // Stream Preferences
  String _selectedResolution = '1080p (FHD)';
  int _selectedBitrate = 8; // Mbps
  int _selectedFps = 60;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _refreshDevices(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _wifiIpController.dispose();
    super.dispose();
  }

  Future<void> _refreshDevices({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingDevices = true);
    }
    final devs = await AdbManager.instance.getDevices();
    if (mounted) {
      setState(() {
        _devices = devs;
        _isLoadingDevices = false;
        if (_selectedDevice == null || !_devices.any((d) => d.serial == _selectedDevice!.serial)) {
          _selectedDevice = _devices.isNotEmpty ? _devices.first : null;
        }
      });
    }
  }

  Future<void> _connectWireless() async {
    final ip = _wifiIpController.text.trim();
    if (ip.isEmpty) {
      _showToast('Please enter phone Wi-Fi IP address');
      return;
    }

    setState(() => _isConnectingWireless = true);
    final success = await AdbManager.instance.connectWireless(ip);
    setState(() => _isConnectingWireless = false);

    if (success) {
      _showToast('Connected wirelessly to $ip!');
      _refreshDevices();
    } else {
      _showToast('Failed to connect to $ip. Make sure phone is on same Wi-Fi.');
    }
  }

  Future<void> _enableWirelessOnDevice(AdbDevice device) async {
    final ok = await AdbManager.instance.enableTcpIp(device.serial);
    if (ok) {
      _showToast('Wireless mode enabled on ${device.displayName}! You can now unplug USB.');
      _refreshDevices();
    } else {
      _showToast('Failed to enable wireless mode on device.');
    }
  }

  Future<void> _startMirrorCinema() async {
    if (_selectedDevice == null) {
      _showToast('Please connect an Android device first!');
      return;
    }

    int resValue = 1080;
    if (_selectedResolution.startsWith('720p')) resValue = 720;
    if (_selectedResolution.startsWith('1440p')) resValue = 1440;
    if (_selectedResolution.startsWith('Native')) resValue = 0;

    final args = [
      '--cinema',
      '--device', _selectedDevice!.serial,
      '--bitrate', (_selectedBitrate * 1000000).toString(),
      '--max-size', resValue.toString(),
      '--max-fps', _selectedFps.toString(),
    ];

    try {
      // Launch as detached independent process so user can close main hub!
      await Process.start(
        Platform.resolvedExecutable,
        args,
        mode: ProcessStartMode.detached,
      );

      _showToast('Mirror Cinema launched in independent process!');
    } catch (e) {
      _showToast('Error launching Cinema: $e');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E212D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDevicesCard(),
                        const SizedBox(height: 20),
                        _buildWirelessPairCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStreamingSettingsCard(),
                        const SizedBox(height: 20),
                        _buildLaunchCard(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
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
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppTheme.orangeGradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.screen_share_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.orangeGradient.createShader(bounds),
                  child: const Text(
                    'MIRROR',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.5)),
                  ),
                  child: const Text(
                    'v1.0 Windows Edition',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9100)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Open-source Android Screen Mirroring & Remote Control • By Dev Fahim (devfahimbd)',
              style: TextStyle(fontSize: 13, color: Colors.white60),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.devices_rounded, color: AppTheme.secondary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Connected Android Devices',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: _isLoadingDevices
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                    : const Icon(Icons.refresh_rounded, size: 20, color: Colors.white54),
                tooltip: 'Scan Devices',
                onPressed: () => _refreshDevices(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                children: const [
                  Icon(Icons.usb_rounded, color: Colors.white30, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'No Android Devices Detected',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Connect your phone via USB with "USB Debugging" enabled, or use the Wi-Fi pairing box below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white38, height: 1.4),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final dev = _devices[index];
                final isSelected = _selectedDevice?.serial == dev.serial;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedDevice = dev),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E2230) : const Color(0xFF0F1117),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.06),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          dev.isWireless ? Icons.wifi_rounded : Icons.usb_rounded,
                          color: dev.isWireless ? const Color(0xFF00E676) : AppTheme.secondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.displayName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dev.serial} • ${dev.state.toUpperCase()}',
                                style: const TextStyle(fontSize: 11, color: Colors.white38, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        if (!dev.isWireless)
                          OutlinedButton.icon(
                            onPressed: () => _enableWirelessOnDevice(dev),
                            icon: const Icon(Icons.wifi_rounded, size: 14),
                            label: const Text('Switch to Wi-Fi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.secondary,
                              side: const BorderSide(color: AppTheme.secondary),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWirelessPairCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.wifi_tethering_rounded, color: AppTheme.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Wi-Fi Wireless Connect',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter the IP address shown on your Mirror Mobile Companion app:',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wifiIpController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 192.168.1.105:5555',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0C0E14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isConnectingWireless ? null : _connectWireless,
                icon: _isConnectingWireless
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.link_rounded, size: 18),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, color: AppTheme.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Stream Quality',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown('Resolution', _selectedResolution, ['720p (HD)', '1080p (FHD)', '1440p (2K)', 'Native'], (val) {
            setState(() => _selectedResolution = val!);
          }),
          const SizedBox(height: 14),
          _buildDropdown('Frame Rate', '$_selectedFps FPS', ['30 FPS', '60 FPS'], (val) {
            setState(() => _selectedFps = int.parse(val!.split(' ')[0]));
          }),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bitrate', style: TextStyle(fontSize: 13, color: Colors.white70)),
              Text('$_selectedBitrate Mbps', style: const TextStyle(fontSize: 13, color: AppTheme.secondary, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _selectedBitrate.toDouble(),
            min: 4,
            max: 16,
            divisions: 6,
            activeColor: AppTheme.primary,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() => _selectedBitrate = val.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E212D),
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 13, color: AppTheme.secondary, fontWeight: FontWeight.bold),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLaunchCard() {
    final hasDevice = _selectedDevice != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF241C16),
            const Color(0xFF161822),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: hasDevice ? _startMirrorCinema : null,
              icon: const Icon(Icons.play_circle_filled_rounded, size: 24),
              label: const Text(
                'Start Mirror Cinema',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Runs in an independent Cinema process.\nYou can freely close or minimize this dashboard!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Mirror Project • Created with excellence by Dev Fahim (devfahimbd)',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
            Text(
              'GitHub: github.com/devfahim/Mirror',
              style: TextStyle(fontSize: 12, color: Colors.white24),
            ),
          ],
        ),
      ],
    );
  }
}

