import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'database/app_database.dart';
import 'repositories/habit_repository.dart';
import 'repositories/user_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Notifications
  await NotificationService().initialize();

  // Check Onboarding status locally
  final db = AppDatabase();
  final habitRepo = HabitRepository(db);
  final userRepo = UserRepository(db, habitRepo);
  final isOnboardingCompleted = await userRepo.isOnboardingCompleted();

  runApp(
    ProviderScope(
      child: HabitForgeApp(
        initialOnboardingCompleted: isOnboardingCompleted,
      ),
    ),
  );
}
