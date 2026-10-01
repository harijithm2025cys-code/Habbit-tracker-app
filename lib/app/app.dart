import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../features/navigation/main_navigation_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'theme.dart';

class HabitForgeApp extends ConsumerWidget {
  final bool initialOnboardingCompleted;

  const HabitForgeApp({
    super.key,
    required this.initialOnboardingCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'HabitForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: initialOnboardingCompleted
          ? const MainNavigationScreen()
          : const OnboardingScreen(),
    );
  }
}
