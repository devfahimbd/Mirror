/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * MirrorCinemaView: High-end, draggable Cinema Viewport for the mirrored Android screen.
 * Operates in its own standalone, detached process with a floating quick-actions dock.
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/legacy.dart';
import '../../core/stream/mirror_session.dart';
import '../theme/app_theme.dart';

class MirrorCinemaView extends StatefulWidget {
  final MirrorSession session;

  const MirrorCinemaView({super.key, required this.session});

  @override
  State<MirrorCinemaView> createState() => _MirrorCinemaViewState();
}

class _MirrorCinemaViewState extends State<MirrorCinemaView> {
  bool _isAlwaysOnTop = false;
  bool _isFullscreen = false;
  final FocusNode _keyboardFocusNode = FocusNode();
  String? _lastToast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    widget.session.start();
    _keyboardFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _keyboardFocusNode.dispose();
    widget.session.stop();
    super.dispose();
  }

  void _showOverlayToast(String message) {
    setState(() {
      _lastToast = message;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _lastToast = null;
        });
      }
    });
  }

  Future<void> _toggleAlwaysOnTop() async {
    final next = !_isAlwaysOnTop;
    try {
      await windowManager.setAlwaysOnTop(next);
      setState(() => _isAlwaysOnTop = next);
      _showOverlayToast(next ? 'Pinned (Always On Top)' : 'Unpinned');
    } catch (_) {}
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    try {
      await windowManager.setFullScreen(next);
      setState(() => _isFullscreen = next);
    } catch (_) {}
  }

  void _handlePointerDown(PointerDownEvent e, Size viewportSize) {
    final normX = (e.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
    final normY = (e.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);
    widget.session.control.sendTouchEvent(0, normX, normY);
  }

  void _handlePointerMove(PointerMoveEvent e, Size viewportSize) {
    final normX = (e.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
    final normY = (e.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);
    widget.session.control.sendTouchEvent(2, normX, normY);
  }

  void _handlePointerUp(PointerUpEvent e, Size viewportSize) {
    final normX = (e.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
    final normY = (e.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);
    widget.session.control.sendTouchEvent(1, normX, normY);
  }

  void _handlePointerSignal(PointerSignalEvent e, Size viewportSize) {
    if (e is PointerScrollEvent) {
      final normX = (e.localPosition.dx / viewportSize.width).clamp(0.0, 1.0);
      final normY = (e.localPosition.dy / viewportSize.height).clamp(0.0, 1.0);
      final vScroll = e.scrollDelta.dy > 0 ? -1.0 : 1.0;
      widget.session.control.sendScrollEvent(normX, normY, 0.0, vScroll);
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        widget.session.control.sendKeyEvent(0, 67); // KEYCODE_DEL
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        widget.session.control.sendKeyEvent(0, 66); // KEYCODE_ENTER
      } else if (event.character != null && event.character!.isNotEmpty) {
        widget.session.control.sendText(event.character!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: _keyboardFocusNode,
        onKey: _handleKeyEvent,
        child: Column(
          children: [
            _buildDraggableTitleBar(),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildScreenViewport(),
                  Positioned(
                    right: 14,
                    child: _buildFloatingControls(),
                  ),
                  if (_lastToast != null)
                    Positioned(
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xE614161F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6D00).withOpacity(0.2),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Text(
                          _lastToast!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableTitleBar() {
    return GestureDetector(
      onPanStart: (_) {
        try {
          windowManager.startDragging();
        } catch (_) {}
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1118),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.orangeGradient,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Mirror Cinema — ${widget.session.deviceSerial}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                _isAlwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 16,
                color: _isAlwaysOnTop ? const Color(0xFFFF9100) : Colors.white54,
              ),
              tooltip: 'Always on top',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _toggleAlwaysOnTop,
            ),
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                size: 18,
                color: Colors.white54,
              ),
              tooltip: 'Toggle Fullscreen',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _toggleFullscreen,
            ),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 16, color: Colors.white54),
              tooltip: 'Minimize',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                try {
                  windowManager.minimize();
                } catch (_) {}
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFFF5252)),
              tooltip: 'Close Cinema Window',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                exit(0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenViewport() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = widget.session.aspectRatio;
        double viewW, viewH;

        if (constraints.maxWidth / constraints.maxHeight > aspect) {
          viewH = constraints.maxHeight;
          viewW = viewH * aspect;
        } else {
          viewW = constraints.maxWidth;
          viewH = viewW / aspect;
        }

        final viewSize = Size(viewW, viewH);

        return Container(
          width: viewW,
          height: viewH,
          decoration: BoxDecoration(
            color: const Color(0xFF090A0E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withOpacity(0.12),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Listener(
              onPointerDown: (e) => _handlePointerDown(e, viewSize),
              onPointerMove: (e) => _handlePointerMove(e, viewSize),
              onPointerUp: (e) => _handlePointerUp(e, viewSize),
              onPointerSignal: (e) => _handlePointerSignal(e, viewSize),
              child: AnimatedBuilder(
                animation: widget.session,
                builder: (context, child) {
                  if (widget.session.status == SessionStatus.connecting) {
                    return _buildLoadingScreen();
                  }
                  if (widget.session.status == SessionStatus.error) {
                    return _buildErrorScreen();
                  }
                  return _buildActiveMirrorCanvas();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.orangeGradient,
            ),
            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            widget.session.statusMessage,
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Connection Error',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              widget.session.statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => widget.session.start(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMirrorCanvas() {
    if (widget.session.currentFrame != null) {
      return Image.memory(
        widget.session.currentFrame!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    return Container(
      color: const Color(0xFF0F111A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Opacity(
              opacity: 0.08,
              child: Image.asset('assets/images/logo.png', width: 220),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF6D00)),
                ),
                const SizedBox(height: 14),
                Text(
                  'Connected: ${widget.session.deviceSerial}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Syncing phone display stream...',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6141620),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(Icons.arrow_back_rounded, 'Back', widget.session.pressBack),
          _buildActionButton(Icons.circle_outlined, 'Home', widget.session.pressHome),
          _buildActionButton(Icons.crop_square_rounded, 'Recents', widget.session.pressRecents),
          const Divider(color: Colors.white12, height: 12),
          _buildActionButton(Icons.power_settings_new_rounded, 'Power', widget.session.pressPower),
          _buildActionButton(Icons.volume_up_rounded, 'Volume Up', widget.session.pressVolumeUp),
          _buildActionButton(Icons.volume_down_rounded, 'Volume Down', widget.session.pressVolumeDown),
          const Divider(color: Colors.white12, height: 12),
          _buildActionButton(Icons.camera_alt_rounded, 'Screenshot', () async {
            _showOverlayToast('Capturing screenshot...');
            final path = await widget.session.takeScreenshot();
            if (path != null) {
              _showOverlayToast('Saved to Pictures/Mirror');
            } else {
              _showOverlayToast('Screenshot failed');
            }
          }),
          _buildActionButton(Icons.visibility_off_rounded, 'Screen Off (Save Battery)', () {
            widget.session.toggleScreenOff();
            _showOverlayToast('Toggled device sleep state');
          }),
          const Divider(color: Colors.white12, height: 12),
          _buildActionButton(Icons.close_rounded, 'Disconnect', () {
            exit(0);
          }, color: const Color(0xFFFF5252)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 20, color: color ?? Colors.white70),
          ),
        ),
      ),
    );
  }
}

