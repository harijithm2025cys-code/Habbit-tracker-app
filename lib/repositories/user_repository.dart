import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/user_profile_model.dart';
import 'habit_repository.dart';

class UserRepository {
  final AppDatabase _db;
  final HabitRepository _habitRepo;
  static const String _onboardingKey = 'habit_forge_onboarding_completed';
  static const String _themeModeKey = 'habit_forge_theme_mode';

  UserRepository(this._db, this._habitRepo);

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final prefVal = prefs.getBool(_onboardingKey);
    if (prefVal == true) return true;

    final profile = await getUserProfile();
    return profile?.onboardingCompleted ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  Future<UserProfileModel?> getUserProfile() async {
    final row = await _db.select(_db.userProfiles).getSingleOrNull();
    if (row == null) return null;

    List<String> focusList = [];
    if (row.focusAreas != null && row.focusAreas!.isNotEmpty) {
      try {
        focusList = (jsonDecode(row.focusAreas!) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      } catch (_) {
        focusList = row.focusAreas!.split(',');
      }
    }

    return UserProfileModel(
      id: row.id,
      name: row.name,
      age: row.age,
      wakeTime: row.wakeTime,
      sleepTime: row.sleepTime,
      focusAreas: focusList,
      onboardingCompleted: row.onboardingCompleted,
      createdAt: row.createdAt,
    );
  }

  Future<void> saveUserProfile(UserProfileModel profile) async {
    final existing = await _db.select(_db.userProfiles).getSingleOrNull();
    final focusJson = jsonEncode(profile.focusAreas);

    if (existing == null) {
      await _db.into(_db.userProfiles).insert(
            UserProfilesCompanion.insert(
              id: profile.id.isNotEmpty ? profile.id : const Uuid().v4(),
              name: profile.name,
              age: Value(profile.age),
              wakeTime: Value(profile.wakeTime),
              sleepTime: Value(profile.sleepTime),
              focusAreas: Value(focusJson),
              onboardingCompleted: Value(profile.onboardingCompleted),
              createdAt: Value(profile.createdAt),
            ),
          );
    } else {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(existing.id))).write(
        UserProfilesCompanion(
          name: Value(profile.name),
          age: Value(profile.age),
          wakeTime: Value(profile.wakeTime),
          sleepTime: Value(profile.sleepTime),
          focusAreas: Value(focusJson),
          onboardingCompleted: Value(profile.onboardingCompleted),
        ),
      );
    }

    if (profile.onboardingCompleted) {
      await setOnboardingCompleted(true);
    }
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  // Export full user database as JSON string
  Future<String> exportAllDataAsJson() async {
    final profile = await getUserProfile();
    final habits = await _habitRepo.getAllHabits();
    final completions = await _habitRepo.getAllCompletions();

    final exportMap = {
      'app': 'HabitForge',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile?.toJson(),
      'habits': habits.map((h) => h.toJson()).toList(),
      'completions': completions.map((c) => c.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  // Clear all data completely
  Future<void> deleteAllData() async {
    await _db.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
