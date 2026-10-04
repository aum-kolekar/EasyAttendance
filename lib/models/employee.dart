// Represents one employee record.
class Employee {
  final int? id;
  final String name;
  final double monthlySalary;
  final String? joiningDate; // 'YYYY-MM-DD' or null
  // null = active. A timestamp string means this employee is archived
  // (soft-deleted) - hidden from the active list and current payroll,
  // but all their historical data stays intact and viewable.
  final String? archivedAt;

  Employee({
    this.id,
    required this.name,
    required this.monthlySalary,
    this.joiningDate,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthlySalary': monthlySalary,
      'joiningDate': joiningDate,
      'archivedAt': archivedAt,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      name: map['name'] as String,
      monthlySalary: (map['monthlySalary'] as num).toDouble(),
      joiningDate: map['joiningDate'] as String?,
      archivedAt: map['archivedAt'] as String?,
    );
  }

  Employee copyWith({
    int? id,
    String? name,
    double? monthlySalary,
    String? joiningDate,
    bool clearJoiningDate = false,
    String? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      joiningDate: clearJoiningDate ? null : (joiningDate ?? this.joiningDate),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }
}