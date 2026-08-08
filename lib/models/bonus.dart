// Represents one bonus given to an employee.
// Added to that employee's payable salary in the month matching `date`.
class Bonus {
  final int? id;
  final int employeeId;
  final double amount;
  final String date; // 'YYYY-MM-DD' - determines which month it's added to
  final String? note;

  Bonus({
    this.id,
    required this.employeeId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'amount': amount,
      'date': date,
      'note': note,
    };
  }

  factory Bonus.fromMap(Map<String, dynamic> map) {
    return Bonus(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as int,
      amount: map['amount'] as double,
      date: map['date'] as String,
      note: map['note'] as String?,
    );
  }
}