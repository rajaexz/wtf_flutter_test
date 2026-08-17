import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/services/notification_service.dart';
import 'data/datasources/local_storage.dart';
import 'presentation/widgets/dev_panel_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: TrainerApp()));
}

class TrainerApp extends ConsumerStatefulWidget {
  const TrainerApp({super.key});

  @override
  ConsumerState<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends ConsumerState<TrainerApp> {
  @override
  void initState() {
    super.initState();
    // Wire notification tap → navigate to /call/:id
    NotificationService.instance.onCallTap = (callRequestId) {
      final router = ref.read(routerProvider);
      router.push('/call/$callRequestId');
    };
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariant,
          selectedColor: AppColors.primary,
          labelStyle: const TextStyle(color: AppColors.textPrimary),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        dividerColor: AppColors.divider,
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) => DevPanelOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
