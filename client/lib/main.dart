/**
 * Mirror — Open-source Android Screen Mirroring & Remote Control
 * Author: Dev Fahim (devfahimbd)
 * GitHub: https://github.com/devfahim/Mirror
 *
 * Client Entry Point: Supports Dual-Mode Execution:
 * 1. Main Management Dashboard (default)
 * 2. Standalone Detached Cinema Viewport (--cinema mode)
 */

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';
import 'core/stream/mirror_session.dart';
import 'ui/cinema/mirror_cinema_view.dart';
import 'ui/dashboard/dashboard_screen.dart';
import 'ui/theme/app_theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final isCinema = args.contains('--cinema');
  String deviceSerial = '';
  String? directIp;
  int bitrate = 8000000;
  int maxSize = 1080;
  int maxFps = 60;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--device' && i + 1 < args.length) {
      deviceSerial = args[i + 1];
    } else if (args[i] == '--ip' && i + 1 < args.length) {
      directIp = args[i + 1];
    } else if (args[i] == '--bitrate' && i + 1 < args.length) {
      bitrate = int.tryParse(args[i + 1]) ?? bitrate;
    } else if (args[i] == '--max-size' && i + 1 < args.length) {
      maxSize = int.tryParse(args[i + 1]) ?? maxSize;
    } else if (args[i] == '--max-fps' && i + 1 < args.length) {
      maxFps = int.tryParse(args[i + 1]) ?? maxFps;
    }
  }

  final initialSize = isCinema ? const Size(440, 880) : const Size(1060, 720);
  final minSize = isCinema ? const Size(320, 600) : const Size(900, 640);

  final windowOptions = WindowOptions(
    size: initialSize,
    minimumSize: minSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: isCinema ? 'Mirror Cinema' : 'Mirror — by Dev Fahim',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  Widget homeWidget;
  if (isCinema) {
    final session = MirrorSession(
      deviceSerial: deviceSerial,
      directIp: directIp,
      maxBitrate: bitrate,
      maxResolution: maxSize,
      maxFps: maxFps,
    );
    homeWidget = MirrorCinemaView(session: session);
  } else {
    homeWidget = const DashboardScreen();
  }

  runApp(MirrorWindowsApp(homeWidget: homeWidget));
}

class MirrorWindowsApp extends StatelessWidget {
  final Widget homeWidget;

  const MirrorWindowsApp({super.key, required this.homeWidget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirror — by Dev Fahim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: homeWidget,
    );
  }
}
