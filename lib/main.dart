import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/ble/ble_native_bridge.dart';
import 'core/permissions/permission_manager.dart';
import 'shared/navigation/main_scaffold.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation & status bar transparent for dark aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Native Ble Bridge
  BleNativeBridge.initialize();

  runApp(
    const ProviderScope(
      child: NearbyRadarApp(),
    ),
  );
}

class NearbyRadarApp extends StatefulWidget {
  const NearbyRadarApp({super.key});

  @override
  State<NearbyRadarApp> createState() => _NearbyRadarAppState();
}

class _NearbyRadarAppState extends State<NearbyRadarApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  void _checkPermissions() async {
    final status = await AppPermissionManager.checkAll();
    if (!status.isReadyForBle && mounted) {
      await AppPermissionManager.requestCorePermissions(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Nearby Radar",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainScaffold(),
    );
  }
}
