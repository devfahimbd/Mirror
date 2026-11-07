/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * MirrorSession: Orchestrates ADB tunneling, server launch, control socket,
 * live video frame stream reception, and screencap fallback.
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../adb/adb_manager.dart';
import '../protocol/control_channel.dart';

enum SessionStatus {
  idle,
  connecting,
  mirroring,
  disconnected,
  error,
}

class MirrorSession extends ChangeNotifier {
  final String deviceSerial;
  final String? directIp;
  final int videoPort;
  final int controlPort;
  final int maxBitrate;
  final int maxResolution;
  final int maxFps;

  SessionStatus _status = SessionStatus.idle;
  String _statusMessage = 'Initializing session...';
  int _screenWidth = 1080;
  int _screenHeight = 2400;
  int _videoWidth = 1080;
  int _videoHeight = 2400;

  Uint8List? _currentFrame;
  bool _receivedAnySocketFrame = false;

  Process? _serverProcess;
  Socket? _videoSocket;
  final ControlChannel control = ControlChannel();
  Timer? _fallbackCheckTimer;
  bool _isDisposed = false;

  MirrorSession({
    required this.deviceSerial,
    this.directIp,
    this.videoPort = 8099,
    this.controlPort = 8100,
    this.maxBitrate = 8000000,
    this.maxResolution = 1080,
    this.maxFps = 60,
  });

  SessionStatus get status => _status;
  String get statusMessage => _statusMessage;
  int get screenWidth => _screenWidth;
  int get screenHeight => _screenHeight;
  int get videoWidth => _videoWidth;
  int get videoHeight => _videoHeight;
  Uint8List? get currentFrame => _currentFrame;
  double get aspectRatio => (_screenWidth > 0 && _screenHeight > 0) ? (_screenWidth / _screenHeight) : (9 / 19.5);

  /// Starts the complete mirroring session.
  Future<void> start() async {
    _status = SessionStatus.connecting;
    _statusMessage = 'Connecting to Android device...';
    notifyListeners();

    try {
      final host = directIp ?? '127.0.0.1';

      if (directIp == null) {
        // USB / ADB Forward Mode
        _statusMessage = 'Pushing mirror-server to device...';
        notifyListeners();

        final pushed = await AdbManager.instance.pushServer(deviceSerial);
        if (!pushed) {
          debugPrint('Warning: Could not push jar, will rely on ADB streaming fallback');
        }

        _statusMessage = 'Configuring high-speed ADB tunnels...';
        notifyListeners();
        await AdbManager.instance.forwardPort(deviceSerial, videoPort, videoPort);
        await AdbManager.instance.forwardPort(deviceSerial, controlPort, controlPort);

        _statusMessage = 'Launching low-latency encoder server...';
        notifyListeners();
        _serverProcess = await AdbManager.instance.startServerProcess(
          deviceSerial,
          port: videoPort,
          bitrate: maxBitrate,
          maxSize: maxResolution,
          maxFps: maxFps,
        );

        _serverProcess?.stderr.listen((data) {
          debugPrint('[Server stderr] ${String.fromCharCodes(data)}');
        });

        await Future.delayed(const Duration(milliseconds: 600));
      }

      // Connect video socket
      _statusMessage = 'Establishing video stream...';
      notifyListeners();

      try {
        _videoSocket = await Socket.connect(host, videoPort, timeout: const Duration(seconds: 4));
        _videoSocket!.setOption(SocketOption.tcpNoDelay, true);
        _listenToVideoSocket();
      } catch (e) {
        debugPrint('Direct video socket connect error: $e');
      }

      // Connect control socket
      _statusMessage = 'Establishing control channel...';
      notifyListeners();

      try {
        await control.connect(host, controlPort);
      } catch (e) {
        debugPrint('Direct control connect error: $e');
      }

      _status = SessionStatus.mirroring;
      _statusMessage = 'Mirroring active';
      notifyListeners();

      // Fallback monitor: if socket doesn't produce frames within 1.2s, start high-speed ADB screencap pump
      _fallbackCheckTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!_receivedAnySocketFrame && !_isDisposed && _status == SessionStatus.mirroring) {
          debugPrint('Starting ADB screencap stream fallback...');
          _startAdbScreencapFallback();
        }
      });

      _videoSocket?.done.then((_) => _onDisconnected());

    } catch (e) {
      _status = SessionStatus.error;
      _statusMessage = 'Error: $e';
      notifyListeners();
      await stop();
    }
  }

  void _listenToVideoSocket() {
    final List<int> streamBuffer = [];
    bool headerParsed = false;

    _videoSocket?.listen((List<int> chunk) {
      streamBuffer.addAll(chunk);

      // Parse 20-byte Header: [MIRR: 4B][screenWidth: 4B][screenHeight: 4B][videoWidth: 4B][videoHeight: 4B]
      if (!headerParsed && streamBuffer.length >= 20) {
        final bdata = ByteData.sublistView(Uint8List.fromList(streamBuffer.sublist(0, 20)));
        final magic = bdata.getUint32(0, Endian.big);
        if (magic == 0x4D495252) { // "MIRR"
          _screenWidth = bdata.getInt32(4, Endian.big);
          _screenHeight = bdata.getInt32(8, Endian.big);
          _videoWidth = bdata.getInt32(12, Endian.big);
          _videoHeight = bdata.getInt32(16, Endian.big);
          headerParsed = true;
          streamBuffer.removeRange(0, 20);
          notifyListeners();
        }
      }

      // Parse Frame Packets: [FRME: 4B][length: 4B][data...]
      while (streamBuffer.length >= 8) {
        final bdata = ByteData.sublistView(Uint8List.fromList(streamBuffer.sublist(0, 8)));
        final magic = bdata.getUint32(0, Endian.big);

        if (magic == 0x46524D45) { // "FRME"
          final length = bdata.getInt32(4, Endian.big);
          if (streamBuffer.length >= 8 + length) {
            final frameBytes = Uint8List.fromList(streamBuffer.sublist(8, 8 + length));
            streamBuffer.removeRange(0, 8 + length);

            _currentFrame = frameBytes;
            _receivedAnySocketFrame = true;
            notifyListeners();
          } else {
            // Need more data
            break;
          }
        } else {
          // Sync search: advance 1 byte
          streamBuffer.removeAt(0);
        }
      }
    });
  }

  /// High-speed ADB screencap fallback loop ensuring the screen ALWAYS shows live frames!
  void _startAdbScreencapFallback() async {
    while (!_isDisposed && _status == SessionStatus.mirroring && !_receivedAnySocketFrame) {
      try {
        final adb = await AdbManager.instance.adbPath;
        final res = await Process.run(
          adb,
          ['-s', deviceSerial, 'exec-out', 'screencap', '-p'],
          stdoutEncoding: null,
        );

        if (res.exitCode == 0 && res.stdout is List<int>) {
          final bytes = Uint8List.fromList(res.stdout as List<int>);
          if (bytes.length > 100) {
            _currentFrame = bytes;
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Fallback screencap error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 33)); // ~30 FPS
    }
  }

  void _onDisconnected() {
    if (_status == SessionStatus.mirroring) {
      _status = SessionStatus.disconnected;
      _statusMessage = 'Device disconnected';
      notifyListeners();
    }
  }

  /// Terminates the mirroring session and cleans up resources.
  Future<void> stop() async {
    _isDisposed = true;
    _fallbackCheckTimer?.cancel();
    control.close();
    await _videoSocket?.close();
    _videoSocket?.destroy();
    _videoSocket = null;

    _serverProcess?.kill();
    _serverProcess = null;

    if (directIp == null) {
      await AdbManager.instance.removeForward(deviceSerial, videoPort);
      await AdbManager.instance.removeForward(deviceSerial, controlPort);
    }

    _status = SessionStatus.disconnected;
    _statusMessage = 'Session stopped';
    notifyListeners();
  }

  // Quick Action Helpers
  void pressBack() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdBack);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 4);
    }
  }

  void pressHome() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdHome);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 3);
    }
  }

  void pressRecents() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdRecents);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 187);
    }
  }

  void pressPower() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdPower);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 26);
    }
  }

  void pressVolumeUp() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdVolumeUp);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 24);
    }
  }

  void pressVolumeDown() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdVolumeDown);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 25);
    }
  }

  void toggleScreenOff() {
    if (control.isConnected) {
      control.sendCommand(ControlChannel.cmdScreenOff);
    } else {
      AdbManager.instance.sendKeyevent(deviceSerial, 223);
    }
  }

  Future<String?> takeScreenshot() async {
    return AdbManager.instance.takeScreenshot(deviceSerial);
  }
}
