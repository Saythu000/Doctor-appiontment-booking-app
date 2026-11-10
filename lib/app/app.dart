import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/router.dart';
import 'package:phia_flutter/core/theme/app_theme.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// Root widget: theme, navigation, and pausing background sync while the app
/// is not visible.
class DrGodlyApp extends StatefulWidget {
  const DrGodlyApp({super.key});

  @override
  State<DrGodlyApp> createState() => _DrGodlyAppState();
}

class _DrGodlyAppState extends State<DrGodlyApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final activityVm = context.read<ActivityViewModel>();
    if (state == AppLifecycleState.resumed) {
      activityVm.resumeAutoSync();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      activityVm.pauseAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DrGodly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // themeMode defaults to ThemeMode.system: follows the phone's setting.
      routerConfig: _router,
    );
  }
}
