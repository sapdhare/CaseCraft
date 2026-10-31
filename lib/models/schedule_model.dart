class ScheduleItem {
  final String id;
  final String title;
  final String category;
  final int startMinutes;
  final int endMinutes;
  final Set<int> weekdays;
  final String location;
  final String notes;
  final bool reminderEnabled;

  const ScheduleItem({
    required this.id,
    required this.title,
    required this.category,
    required this.startMinutes,
    required this.endMinutes,
    required this.weekdays,
    required this.location,
    required this.notes,
    this.reminderEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'weekdays': weekdays.toList(),
        'location': location,
        'notes': notes,
        'reminderEnabled': reminderEnabled,
      };

  factory ScheduleItem.fromMap(Map map) => ScheduleItem(
        id: '${map['id'] ?? ''}',
        title: '${map['title'] ?? ''}',
        category: '${map['category'] ?? 'Work'}',
        startMinutes: (map['startMinutes'] as int?) ?? 600,
        endMinutes: (map['endMinutes'] as int?) ?? 660,
        weekdays: Set<int>.from(map['weekdays'] as List? ?? [1, 2, 3, 4, 5]),
        location: '${map['location'] ?? ''}',
        notes: '${map['notes'] ?? ''}',
        reminderEnabled: map['reminderEnabled'] as bool? ?? true,
      );
}

String formatMinutes(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final displayHour = h % 12 == 0 ? 12 : h % 12;
  return '$displayHour:${m.toString().padLeft(2, '0')} $suffix';
}
