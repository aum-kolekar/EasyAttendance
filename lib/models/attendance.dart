// Represents one attendance record: one employee, on one date,
// present or absent.
class Attendance {
  final int? id;
  final int employeeId;
  final String date; // stored as 'YYYY-MM-DD' string - easy to sort/query
  final bool isPresent;

  Attendance({
    this.id,
    required this.employeeId,
    required this.date,
    required this.isPresent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date,
      // SQLite has no boolean type - store as 1/0
      'isPresent': isPresent ? 1 : 0,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as int,
      date: map['date'] as String,
      isPresent: (map['isPresent'] as int) == 1,
    );
  }
}