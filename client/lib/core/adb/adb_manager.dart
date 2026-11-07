/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * AdbManager: Comprehensive ADB wrapper for device discovery, server deployment,
 * port forwarding, wireless TCP/IP pairing, and input dispatch.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class AdbDevice {
  final String serial;
  final String model;
  final String product;
  final String state;
  final bool isWireless;

  AdbDevice({
    required this.serial,
    required this.model,
    required this.product,
    required this.state,
    required this.isWireless,
  });

  String get displayName {
    if (model.isNotEmpty) {
      return model.replaceAll('_', ' ');
    }
    return serial;
  }
}

class AdbManager {
  static final AdbManager instance = AdbManager._internal();
  AdbManager._internal();

  String? _adbPath;
  String? _serverJarPath;

  /// Resolves the ADB binary path (prefers bundled ADB, then system paths).
  Future<String> get adbPath async {
    if (_adbPath != null) return _adbPath!;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/data/flutter_assets/assets/bin/adb/adb.exe',
      '$exeDir/assets/bin/adb/adb.exe',
      'E:/Mirror/client/assets/bin/adb/adb.exe',
      'E:/src/android/platform-tools/adb.exe',
      'adb',
    ];

    for (final path in candidates) {
      if (path == 'adb' || await File(path).exists()) {
        try {
          final res = await Process.run(path, ['version']);
          if (res.exitCode == 0) {
            _adbPath = path;
            return path;
          }
        } catch (_) {}
      }
    }

    _adbPath = 'adb';
    return _adbPath!;
  }

  /// Resolves the mirror-server.jar path from bundled assets.
  Future<String> get serverJarPath async {
    if (_serverJarPath != null) return _serverJarPath!;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/data/flutter_assets/assets/bin/mirror-server.jar',
      '$exeDir/assets/bin/mirror-server.jar',
      'E:/Mirror/client/assets/bin/mirror-server.jar',
      'E:/Mirror/server/build/mirror-server.jar',
    ];

    for (final path in candidates) {
      if (await File(path).exists()) {
        _serverJarPath = path;
        return path;
      }
    }

    _serverJarPath = 'assets/bin/mirror-server.jar';
    return _serverJarPath!;
  }

  /// Retrieves list of all connected Android devices (USB and Wi-Fi).
  Future<List<AdbDevice>> getDevices() async {
    final adb = await adbPath;
    try {
      final res = await Process.run(adb, ['devices', '-l']);
      if (res.exitCode != 0) return [];

      final lines = const LineSplitter().convert(res.stdout.toString());
      final devices = <AdbDevice>[];

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final serial = parts[0];
          final state = parts[1];

          String model = '';
          String product = '';

          for (var p in parts) {
            if (p.startsWith('model:')) model = p.substring(6);
            if (p.startsWith('product:')) product = p.substring(8);
          }

          final isWireless = serial.contains(':');
          devices.add(AdbDevice(
            serial: serial,
            model: model.isEmpty ? (isWireless ? 'Wi-Fi Device' : 'Android Device') : model,
            product: product,
            state: state,
            isWireless: isWireless,
          ));
        }
      }
      return devices;
    } catch (_) {
      return [];
    }
  }

  /// Enables TCP/IP wireless debugging mode on USB-connected device.
  Future<bool> enableTcpIp(String serial, {int port = 5555}) async {
    final adb = await adbPath;
    try {
      final res = await Process.run(adb, ['-s', serial, 'tcpip', port.toString()]);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Connects to a device wirelessly via its Wi-Fi IP address.
  Future<bool> connectWireless(String ip, {int port = 5555}) async {
    final adb = await adbPath;
    final address = ip.contains(':') ? ip : '$ip:$port';
    try {
      final res = await Process.run(adb, ['connect', address]);
      final out = res.stdout.toString().toLowerCase();
      return out.contains('connected') && !out.contains('cannot');
    } catch (_) {
      return false;
    }
  }

  /// Sets up ADB port forwarding from PC to Android device.
  Future<bool> forwardPort(String serial, int localPort, int devicePort) async {
    final adb = await adbPath;
    try {
      final res = await Process.run(adb, ['-s', serial, 'forward', 'tcp:$localPort', 'tcp:$devicePort']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Removes port forwarding.
  Future<void> removeForward(String serial, int localPort) async {
    final adb = await adbPath;
    try {
      await Process.run(adb, ['-s', serial, 'forward', '--remove', 'tcp:$localPort']);
    } catch (_) {}
  }

  /// Pushes mirror-server.jar to /data/local/tmp/ on the device.
  Future<bool> pushServer(String serial) async {
    final adb = await adbPath;
    final jar = await serverJarPath;
    try {
      final res = await Process.run(adb, ['-s', serial, 'push', jar, '/data/local/tmp/mirror-server.jar']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Starts the mirror server on device via app_process.
  Future<Process> startServerProcess(
    String serial, {
    int port = 8099,
    int bitrate = 8000000,
    int maxSize = 1080,
    int maxFps = 60,
  }) async {
    final adb = await adbPath;
    final args = [
      '-s', serial,
      'shell',
      'CLASSPATH=/data/local/tmp/mirror-server.jar',
      'app_process',
      '/',
      'com.devfahim.mirror.server.Server',
      'port=$port',
      'bitrate=$bitrate',
      'max_size=$maxSize',
      'max_fps=$maxFps',
    ];

    return Process.start(adb, args);
  }

  /// Sends hardware/nav keyevent via ADB shell input.
  Future<void> sendKeyevent(String serial, int keyCode) async {
    final adb = await adbPath;
    try {
      await Process.run(adb, ['-s', serial, 'shell', 'input', 'keyevent', keyCode.toString()]);
    } catch (_) {}
  }

  /// Takes instant screenshot and saves to Pictures/Mirror directory.
  Future<String?> takeScreenshot(String serial) async {
    final adb = await adbPath;
    try {
      final picturesDir = Directory('${Platform.environment['USERPROFILE']}/Pictures/Mirror');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final fileName = 'Screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${picturesDir.path}/$fileName';

      final res = await Process.run(adb, ['-s', serial, 'exec-out', 'screencap', '-p'], stdoutEncoding: null);
      if (res.exitCode == 0 && res.stdout is List<int>) {
        await File(filePath).writeAsBytes(res.stdout as List<int>);
        return filePath;
      }
    } catch (_) {}
    return null;
  }
}

