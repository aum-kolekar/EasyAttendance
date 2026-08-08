import '../models/employee.dart';
import '../db/database_helper.dart';

class SalaryResult {
  final Employee employee;
  final int totalDaysInMonth;
  final int holidayQuota; // fixed monthly quota (4)
  final int holidayDays; // actual holidays the employee took
  final int workingDaysInMonth;
  final int absentDays;
  final int extraDaysWorked; // unused holiday quota - paid as bonus days
  final double perDayRate;
  final double deduction;
  final double advanceDeducted;
  final double manualBonusAdded;
  final double extraDayBonus;
  final double payableSalary;

  SalaryResult({
    required this.employee,
    required this.totalDaysInMonth,
    required this.holidayQuota,
    required this.holidayDays,
    required this.workingDaysInMonth,
    required this.absentDays,
    required this.extraDaysWorked,
    required this.perDayRate,
    required this.deduction,
    required this.advanceDeducted,
    required this.manualBonusAdded,
    required this.extraDayBonus,
    required this.payableSalary,
  });
}

class SalaryCalculator {
  // Fixed monthly holiday quota - any 4 days, no weekly restriction.
  static const int monthlyHolidayQuota = 4;

  static Future<SalaryResult> calculateForEmployee({
    required Employee employee,
    required int year,
    required int month,
  }) async {
    final totalDays = DateTime(year, month + 1, 0).day;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate =
        '$year-${month.toString().padLeft(2, '0')}-${totalDays.toString().padLeft(2, '0')}';

    final records = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
      employee.id!,
      startDate,
      endDate,
    );

    int absentDays = 0;
    int holidayDays = 0;
    for (final record in records) {
      if (record.isAbsent) absentDays++;
      if (record.isHoliday) holidayDays++;
    }

    // Salary always assumes a fixed monthly quota of off-days (4),
    // regardless of how many the employee actually took.
    final workingDays = totalDays - monthlyHolidayQuota;
    final perDayRate = workingDays > 0 ? employee.monthlySalary / workingDays : 0.0;
    final deduction = perDayRate * absentDays;

    // Any unused holiday quota (up to 4, enforced in the UI) becomes
    // extra pay - the employee worked days the salary already assumed
    // they'd take off.
    final extraDaysWorked =
        (monthlyHolidayQuota - holidayDays).clamp(0, monthlyHolidayQuota);
    final extraDayBonus = perDayRate * extraDaysWorked;

    final advances = await DatabaseHelper.instance.getAdvancesForEmployeeInRange(
      employee.id!,
      startDate,
      endDate,
    );
    final advanceTotal = advances.fold<double>(0.0, (sum, a) => sum + a.amount);

    final bonuses = await DatabaseHelper.instance.getBonusesForEmployeeInRange(
      employee.id!,
      startDate,
      endDate,
    );
    final bonusTotal = bonuses.fold<double>(0.0, (sum, b) => sum + b.amount);

    final payable =
        employee.monthlySalary - deduction - advanceTotal + bonusTotal + extraDayBonus;

    return SalaryResult(
      employee: employee,
      totalDaysInMonth: totalDays,
      holidayQuota: monthlyHolidayQuota,
      holidayDays: holidayDays,
      workingDaysInMonth: workingDays,
      absentDays: absentDays,
      extraDaysWorked: extraDaysWorked,
      perDayRate: perDayRate,
      deduction: deduction,
      advanceDeducted: advanceTotal,
      manualBonusAdded: bonusTotal,
      extraDayBonus: extraDayBonus,
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