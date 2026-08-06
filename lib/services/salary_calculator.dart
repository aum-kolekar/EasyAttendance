import '../models/employee.dart';
import '../db/database_helper.dart';

// Holds the calculated result for one employee for one month.
class SalaryResult {
  final Employee employee;
  final int totalDaysInMonth;
  final int absentDays;
  final double perDayRate;
  final double deduction;
  final double payableSalary;

  SalaryResult({
    required this.employee,
    required this.totalDaysInMonth,
    required this.absentDays,
    required this.perDayRate,
    required this.deduction,
    required this.payableSalary,
  });
}

class SalaryCalculator {
  // Calculates the payable salary for one employee for a given month/year.
  static Future<SalaryResult> calculateForEmployee({
    required Employee employee,
    required int year,
    required int month, // 1 = January ... 12 = December
  }) async {
    // How many days are in this month (handles Feb 28/29, 30 vs 31 days etc.)
    // Trick: day 0 of the NEXT month = the last day of THIS month.
    final totalDays = DateTime(year, month + 1, 0).day;

    final perDayRate = employee.monthlySalary / totalDays;

    // Build the date-range strings to query, e.g. '2026-08-01' to '2026-08-31'
    final startDate =
        '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate =
        '$year-${month.toString().padLeft(2, '0')}-${totalDays.toString().padLeft(2, '0')}';

    final records = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
      employee.id!,
      startDate,
      endDate,
    );

    // Count only explicitly-marked absences
    final absentDays = records.where((r) => !r.isPresent).length;

    final deduction = perDayRate * absentDays;
    final payable = employee.monthlySalary - deduction;

    return SalaryResult(
      employee: employee,
      totalDaysInMonth: totalDays,
      absentDays: absentDays,
      perDayRate: perDayRate,
      deduction: deduction,
      payableSalary: payable,
    );
  }

  // Calculates results for ALL employees for a given month/year at once
  // (used by the Reports screen).
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