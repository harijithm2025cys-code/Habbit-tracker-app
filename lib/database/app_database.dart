import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  UserProfiles,
  Habits,
  HabitSchedules,
  Completions,
  ActivitySessions,
  GpsPoints,
  Reminders,
  ChecklistItems,
])
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  factory AppDatabase() {
    return _instance ??= AppDatabase._internal();
  }

  AppDatabase._internal() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'habit_forge_db');
  }

  // Clear all data (for testing or "Delete All Data" feature)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(checklistItems).go();
      await delete(reminders).go();
      await delete(gpsPoints).go();
      await delete(activitySessions).go();
      await delete(completions).go();
      await delete(habitSchedules).go();
      await delete(habits).go();
      await delete(userProfiles).go();
    });
  }
}
