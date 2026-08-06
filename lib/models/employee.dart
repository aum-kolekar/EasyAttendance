// Represents one employee record.
// This is a plain Dart class - it just holds data and knows how to
// convert itself to/from a database row (a Map).
class Employee {
  final int? id; // null until saved to database (DB assigns it)
  final String name;
  final double monthlySalary;
 
  Employee({
    this.id,
    required this.name,
    required this.monthlySalary,
  });


    // Convert an Employee object into a Map, which sqflite needs
  // for inserting/updating rows in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthlySalary': monthlySalary,
    };
  }

 // Create an Employee object from a database row (Map).
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      name: map['name'] as String,
      monthlySalary: map['monthlySalary'] as double,
    );
  }

    // Helper: makes it easy to create a copy with an updated field
  // (useful later when editing salary).
  Employee copyWith({int? id, String? name, double? monthlySalary}) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlySalary: monthlySalary ?? this.monthlySalary,
    );
  }
}