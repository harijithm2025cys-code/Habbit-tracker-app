import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/enums/task_enums.dart';
import '../database/app_database.dart';
import '../models/completion_model.dart';
import '../models/habit_model.dart';

class HabitRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  HabitRepository(this._db);

  // Helper to format date key YYYY-MM-DD
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Get all habits with their schedules and checklist items
  Future<List<HabitModel>> getAllHabits() async {
    final habitRows = await (_db.select(_db.habits)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();

    final List<HabitModel> results = [];
    for (final row in habitRows) {
      final schedules = await (_db.select(_db.habitSchedules)
            ..where((t) => t.habitId.equals(row.id)))
          .get();

      final checklist = await (_db.select(_db.checklistItems)
            ..where((t) => t.habitId.equals(row.id))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

      results.add(_mapRowToHabit(row, schedules, checklist));
    }
    return results;
  }

  // Stream all habits for reactive UI updates
  Stream<List<HabitModel>> watchAllHabits() {
    return _db.select(_db.habits).watch().asyncMap((habitRows) async {
      final List<HabitModel> results = [];
      for (final row in habitRows) {
        final schedules = await (_db.select(_db.habitSchedules)
              ..where((t) => t.habitId.equals(row.id)))
            .get();

        final checklist = await (_db.select(_db.checklistItems)
              ..where((t) => t.habitId.equals(row.id))
              ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
            .get();

        results.add(_mapRowToHabit(row, schedules, checklist));
      }
      return results;
    });
  }

  // Get single habit by ID
  Future<HabitModel?> getHabitById(String id) async {
    final row = await (_db.select(_db.habits)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final schedules = await (_db.select(_db.habitSchedules)
          ..where((t) => t.habitId.equals(id)))
        .get();

    final checklist = await (_db.select(_db.checklistItems)
          ..where((t) => t.habitId.equals(id))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    return _mapRowToHabit(row, schedules, checklist);
  }

  // Create Habit
  Future<String> createHabit(HabitModel habit) async {
    final habitId = habit.id.isNotEmpty ? habit.id : _uuid.v4();

    await _db.transaction(() async {
      await _db.into(_db.habits).insert(
            HabitsCompanion.insert(
              id: habitId,
              title: habit.title,
              description: Value(habit.description),
              taskType: habit.taskType.name,
              frequencyType: habit.frequencyType.name,
              targetValue: Value(habit.targetValue),
              targetUnit: Value(habit.targetUnit),
              reminderTime: Value(habit.reminderTime),
              wakeTime: Value(habit.wakeTime),
              isActive: Value(habit.isActive),
              colorValue: Value(habit.colorValue),
              iconName: Value(habit.iconName),
              currentStreak: Value(habit.currentStreak),
              bestStreak: Value(habit.bestStreak),
              createdAt: Value(habit.createdAt),
            ),
          );

      // Insert schedules if specific days
      if (habit.frequencyType == FrequencyType.specificDays) {
        for (final weekday in habit.scheduledWeekdays) {
          await _db.into(_db.habitSchedules).insert(
                HabitSchedulesCompanion.insert(
                  id: _uuid.v4(),
                  habitId: habitId,
                  weekday: weekday,
                ),
              );
        }
      }

      // Insert checklist items if any
      for (int i = 0; i < habit.checklistItems.length; i++) {
        final item = habit.checklistItems[i];
        await _db.into(_db.checklistItems).insert(
              ChecklistItemsCompanion.insert(
                id: item.id.isNotEmpty ? item.id : _uuid.v4(),
                habitId: habitId,
                title: item.title,
                isCompleted: Value(item.isCompleted),
                sortOrder: Value(i),
              ),
            );
      }
    });

    return habitId;
  }

  // Update Habit
  Future<void> updateHabit(HabitModel habit) async {
    await _db.transaction(() async {
      await (_db.update(_db.habits)..where((t) => t.id.equals(habit.id))).write(
        HabitsCompanion(
          title: Value(habit.title),
          description: Value(habit.description),
          taskType: Value(habit.taskType.name),
          frequencyType: Value(habit.frequencyType.name),
          targetValue: Value(habit.targetValue),
          targetUnit: Value(habit.targetUnit),
          reminderTime: Value(habit.reminderTime),
          wakeTime: Value(habit.wakeTime),
          isActive: Value(habit.isActive),
          colorValue: Value(habit.colorValue),
          iconName: Value(habit.iconName),
          currentStreak: Value(habit.currentStreak),
          bestStreak: Value(habit.bestStreak),
        ),
      );

      // Re-insert schedules
      await (_db.delete(_db.habitSchedules)..where((t) => t.habitId.equals(habit.id))).go();
      if (habit.frequencyType == FrequencyType.specificDays) {
        for (final weekday in habit.scheduledWeekdays) {
          await _db.into(_db.habitSchedules).insert(
                HabitSchedulesCompanion.insert(
                  id: _uuid.v4(),
                  habitId: habit.id,
                  weekday: weekday,
                ),
              );
        }
      }

      // Re-insert checklist items
      await (_db.delete(_db.checklistItems)..where((t) => t.habitId.equals(habit.id))).go();
      for (int i = 0; i < habit.checklistItems.length; i++) {
        final item = habit.checklistItems[i];
        await _db.into(_db.checklistItems).insert(
              ChecklistItemsCompanion.insert(
                id: item.id.isNotEmpty ? item.id : _uuid.v4(),
                habitId: habit.id,
                title: item.title,
                isCompleted: Value(item.isCompleted),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  // Update streak values directly on Habit
  Future<void> updateHabitStreaks(String habitId, int currentStreak, int bestStreak) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(habitId))).write(
      HabitsCompanion(
        currentStreak: Value(currentStreak),
        bestStreak: Value(bestStreak),
      ),
    );
  }

  // Delete Habit
  Future<void> deleteHabit(String habitId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.checklistItems)..where((t) => t.habitId.equals(habitId))).go();
      await (_db.delete(_db.reminders)..where((t) => t.habitId.equals(habitId))).go();
      await (_db.delete(_db.completions)..where((t) => t.habitId.equals(habitId))).go();
      await (_db.delete(_db.habitSchedules)..where((t) => t.habitId.equals(habitId))).go();
      await (_db.delete(_db.habits)..where((t) => t.id.equals(habitId))).go();
    });
  }

  // Toggle habit active state (pause / resume)
  Future<void> toggleHabitActive(String habitId, bool isActive) async {
    await (_db.update(_db.habits)..where((t) => t.id.equals(habitId))).write(
      HabitsCompanion(isActive: Value(isActive)),
    );
  }

  // Completions CRUD
  Future<bool> isHabitCompletedOnDate(String habitId, String date) async {
    final completion = await (_db.select(_db.completions)
          ..where((t) => t.habitId.equals(habitId) & t.date.equals(date)))
        .getSingleOrNull();
    return completion != null;
  }

  Future<void> recordCompletion({
    required String habitId,
    required DateTime date,
    double? value,
    String status = 'completed',
    String? notes,
  }) async {
    final dateStr = formatDate(date);
    final existing = await (_db.select(_db.completions)
          ..where((t) => t.habitId.equals(habitId) & t.date.equals(dateStr)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.completions).insert(
            CompletionsCompanion.insert(
              id: _uuid.v4(),
              habitId: habitId,
              date: dateStr,
              completedAt: Value(DateTime.now()),
              value: Value(value),
              status: Value(status),
              notes: Value(notes),
            ),
          );
    }
  }

  Future<void> removeCompletion(String habitId, String dateStr) async {
    await (_db.delete(_db.completions)
          ..where((t) => t.habitId.equals(habitId) & t.date.equals(dateStr)))
        .go();
  }

  Future<List<CompletionModel>> getCompletionsForHabit(String habitId) async {
    final rows = await (_db.select(_db.completions)
          ..where((t) => t.habitId.equals(habitId))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .get();

    return rows
        .map((r) => CompletionModel(
              id: r.id,
              habitId: r.habitId,
              date: r.date,
              completedAt: r.completedAt,
              value: r.value,
              status: r.status,
              notes: r.notes,
            ))
        .toList();
  }

  Future<List<CompletionModel>> getCompletionsForDate(String dateStr) async {
    final rows = await (_db.select(_db.completions)
          ..where((t) => t.date.equals(dateStr)))
        .get();

    return rows
        .map((r) => CompletionModel(
              id: r.id,
              habitId: r.habitId,
              date: r.date,
              completedAt: r.completedAt,
              value: r.value,
              status: r.status,
              notes: r.notes,
            ))
        .toList();
  }

  Stream<List<CompletionModel>> watchCompletionsForDate(String dateStr) {
    return (_db.select(_db.completions)..where((t) => t.date.equals(dateStr)))
        .watch()
        .map((rows) => rows
            .map((r) => CompletionModel(
                  id: r.id,
                  habitId: r.habitId,
                  date: r.date,
                  completedAt: r.completedAt,
                  value: r.value,
                  status: r.status,
                  notes: r.notes,
                ))
            .toList());
  }

  Future<List<CompletionModel>> getAllCompletions() async {
    final rows = await (_db.select(_db.completions)
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .get();

    return rows
        .map((r) => CompletionModel(
              id: r.id,
              habitId: r.habitId,
              date: r.date,
              completedAt: r.completedAt,
              value: r.value,
              status: r.status,
              notes: r.notes,
            ))
        .toList();
  }

  // Toggle Checklist item completion
  Future<void> toggleChecklistItem(String itemId, bool isCompleted) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(itemId))).write(
      ChecklistItemsCompanion(isCompleted: Value(isCompleted)),
    );
  }

  // Reset checklist items for a new day if desired
  Future<void> resetChecklistForHabit(String habitId) async {
    await (_db.update(_db.checklistItems)..where((t) => t.habitId.equals(habitId))).write(
      const ChecklistItemsCompanion(isCompleted: Value(false)),
    );
  }

  HabitModel _mapRowToHabit(
    Habit row,
    List<HabitSchedule> schedules,
    List<ChecklistItem> checklist,
  ) {
    return HabitModel(
      id: row.id,
      title: row.title,
      description: row.description,
      taskType: TaskType.fromString(row.taskType),
      frequencyType: FrequencyType.fromString(row.frequencyType),
      targetValue: row.targetValue,
      targetUnit: row.targetUnit,
      reminderTime: row.reminderTime,
      wakeTime: row.wakeTime,
      isActive: row.isActive,
      colorValue: row.colorValue,
      iconName: row.iconName,
      currentStreak: row.currentStreak,
      bestStreak: row.bestStreak,
      createdAt: row.createdAt,
      scheduledWeekdays: schedules.map((s) => s.weekday).toList(),
      checklistItems: checklist
          .map((c) => ChecklistItemModel(
                id: c.id,
                habitId: c.habitId,
                title: c.title,
                isCompleted: c.isCompleted,
                sortOrder: c.sortOrder,
              ))
          .toList(),
    );
  }
}
