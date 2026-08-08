// Represents one salary advance given to an employee.
// Deducted from that employee's payable salary in the month
// matching `date`.
class Advance {
  final int? id;
  final int employeeId;
  final double amount;
  final String date; // 'YYYY-MM-DD' - determines which month it's deducted from
  final String? note; // optional, e.g. "for medical expense"

  Advance({
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

  factory Advance.fromMap(Map<String, dynamic> map) {
    return Advance(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as int,
      amount: map['amount'] as double,
      date: map['date'] as String,
      note: map['note'] as String?,
    );
  }
}