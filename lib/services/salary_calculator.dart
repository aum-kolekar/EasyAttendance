import '../models/employee.dart';
import '../db/database_helper.dart';

class SalaryResult {
  final Employee employee;
  final int totalDaysInMonth;
  final int sundaysInMonth;
  final int workingDaysInMonth;
  final int absentDays;
  final int extraDaysWorked;
  final double perDayRate;
  final double deduction;
  final double bonus;
  final double payableSalary;

  SalaryResult({
    required this.employee,
    required this.totalDaysInMonth,
    required this.sundaysInMonth,
    required this.workingDaysInMonth,
    required this.absentDays,
    required this.extraDaysWorked,
    required this.perDayRate,
    required this.deduction,
    required this.bonus,
    required this.payableSalary,
  });
}

class SalaryCalculator {
  static Future<SalaryResult> calculateForEmployee({
    required Employee employee,
    required int year,
    required int month,
  }) async {
    final totalDays = DateTime(year, month + 1, 0).day;

    // Count Sundays in this month
    int sundays = 0;
    for (int day = 1; day <= totalDays; day++) {
      if (DateTime(year, month, day).weekday == DateTime.sunday) {
        sundays++;
      }
    }

    final workingDays = totalDays - sundays;
    // Guard against a theoretical divide-by-zero (won't normally happen)
    final perDayRate = workingDays > 0 ? employee.monthlySalary / workingDays : 0.0;

    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate =
        '$year-${month.toString().padLeft(2, '0')}-${totalDays.toString().padLeft(2, '0')}';

    final records = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
      employee.id!,
      startDate,
      endDate,
    );

    int absentDays = 0;
    int extraDaysWorked = 0;

    for (final record in records) {
      final recordDate = DateTime.parse(record.date);
      final isSunday = recordDate.weekday == DateTime.sunday;

      if (isSunday) {
        // On Sundays, a record only ever means "worked extra" (isPresent=true).
        // Absent is never stored for Sundays (UI doesn't allow it).
        if (record.isPresent) extraDaysWorked++;
      } else {
        // Regular day: only explicit absences count against salary
        if (!record.isPresent) absentDays++;
      }
    }

    final deduction = perDayRate * absentDays;
    final bonus = perDayRate * extraDaysWorked;
    final payable = employee.monthlySalary - deduction + bonus;

    return SalaryResult(
      employee: employee,
      totalDaysInMonth: totalDays,
      sundaysInMonth: sundays,
      workingDaysInMonth: workingDays,
      absentDays: absentDays,
      extraDaysWorked: extraDaysWorked,
      perDayRate: perDayRate,
      deduction: deduction,
      bonus: bonus,
      payableSalary: payable,
    );
  }

  static Future<List<SalaryResult>> calculateForAllEmployees({
    required int year,
    required int month,
  }) async {
    final employees = await DatabaseHelper.instance.getAllEmployees();
    final results = <SalaryResult>[];
    for (final employee in employees) {
      final result = await calculateForEmployee(
        employee: employee,
        year: year,
        month: month,
      );
      results.add(result);
    }
    return results;
  }
}