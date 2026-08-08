// Represents one employee record.
// This is a plain Dart class - it just holds data and knows how to
// convert itself to/from a database row (a Map).
class Employee {
  final int? id; // null until saved to database (DB assigns it)
  final String name;
  final double monthlySalary;
  // 'YYYY-MM-DD' or null. Null means "no joining date set" - existing
  // employees added before this feature aren't retroactively affected.
  final String? joiningDate;

  Employee({
    this.id,
    required this.name,
    required this.monthlySalary,
    this.joiningDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthlySalary': monthlySalary,
      'joiningDate': joiningDate,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      name: map['name'] as String,
      monthlySalary: (map['monthlySalary'] as num).toDouble(),
      joiningDate: map['joiningDate'] as String?,
    );
  }

  // Helper: makes it easy to create a copy with an updated field.
  // Pass clearJoiningDate: true to explicitly set it back to null.
  Employee copyWith({
    int? id,
    String? name,
    double? monthlySalary,
    String? joiningDate,
    bool clearJoiningDate = false,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      joiningDate: clearJoiningDate ? null : (joiningDate ?? this.joiningDate),
    );
  }
}