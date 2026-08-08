// Represents one attendance record for one employee on one date.
// status is one of: 'present', 'absent', 'holiday'
// - present: worked normally
// - absent: did not work, this day's pay IS deducted
// - holiday: employee's declared day off (their weekly quota), pay is
//   neither deducted nor extra - it's simply excluded from the
//   "working days" divisor for that month
class Attendance {
  final int? id;
  final int employeeId;
  final String date; // 'YYYY-MM-DD'
  final String status;

  Attendance({
    this.id,
    required this.employeeId,
    required this.date,
    required this.status,
  });

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isHoliday => status == 'holiday';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date,
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as int,
      date: map['date'] as String,
      status: map['status'] as String,
    );
  }
}