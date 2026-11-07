/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * ControlChannel: High-speed binary socket channel for touch events,
 * mouse interactions, keyboard typing, and system navigation commands.
 */

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ControlChannel {
  static const int typeTouch = 1;
  static const int typeKey = 2;
  static const int typeText = 3;
  static const int typeScroll = 4;
  static const int typeCommand = 5;

  static const int cmdBack = 1;
  static const int cmdHome = 2;
  static const int cmdRecents = 3;
  static const int cmdPower = 4;
  static const int cmdVolumeUp = 5;
  static const int cmdVolumeDown = 6;
  static const int cmdScreenOff = 7;
  static const int cmdScreenOn = 8;

  Socket? _socket;

  Future<void> connect(String host, int port) async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
    _socket!.setOption(SocketOption.tcpNoDelay, true);
  }

  void close() {
    _socket?.destroy();
    _socket = null;
  }

  bool get isConnected => _socket != null;

  /// Injects touch event: action (0=DOWN, 1=UP, 2=MOVE) with normalized (0.0 to 1.0) coordinates.
  void sendTouchEvent(int action, double normX, double normY) {
    if (_socket == null) return;
    final bdata = ByteData(10);
    bdata.setUint8(0, typeTouch);
    bdata.setUint8(1, action);
    bdata.setFloat32(2, normX, Endian.big);
    bdata.setFloat32(6, normY, Endian.big);
    _socket!.add(bdata.buffer.asUint8List());
  }

  /// Injects mouse scroll / wheel event.
  void sendScrollEvent(double normX, double normY, double hScroll, double vScroll) {
    if (_socket == null) return;
    final bdata = ByteData(17);
    bdata.setUint8(0, typeScroll);
    bdata.setFloat32(1, normX, Endian.big);
    bdata.setFloat32(5, normY, Endian.big);
    bdata.setFloat32(9, hScroll, Endian.big);
    bdata.setFloat32(13, vScroll, Endian.big);
    _socket!.add(bdata.buffer.asUint8List());
  }

  /// Injects key event (action: 0=DOWN, 1=UP).
  void sendKeyEvent(int action, int keyCode, {int metaState = 0}) {
    if (_socket == null) return;
    final bdata = ByteData(10);
    bdata.setUint8(0, typeKey);
    bdata.setUint8(1, action);
    bdata.setInt32(2, keyCode, Endian.big);
    bdata.setInt32(6, metaState, Endian.big);
    _socket!.add(bdata.buffer.asUint8List());
  }

  /// Sends raw text string typed from PC keyboard.
  void sendText(String text) {
    if (_socket == null) return;
    final utf8Bytes = utf8.encode(text);
    final bdata = ByteData(5 + utf8Bytes.length);
    bdata.setUint8(0, typeText);
    bdata.setInt32(1, utf8Bytes.length, Endian.big);
    final list = bdata.buffer.asUint8List();
    list.setRange(5, 5 + utf8Bytes.length, utf8Bytes);
    _socket!.add(list);
  }

  /// Sends shortcut command (Back, Home, Recents, Power, Volume, Screen Off).
  void sendCommand(int cmd) {
    if (_socket == null) return;
    final bdata = ByteData(2);
    bdata.setUint8(0, typeCommand);
    bdata.setUint8(1, cmd);
    _socket!.add(bdata.buffer.asUint8List());
  }
}

