import '../models/employee.dart';
import '../db/database_helper.dart';

class SalaryResult {
  final Employee employee;
  final int totalDaysInMonth;
  final int holidayQuota; // fixed monthly quota (4), for a fully employed month
  final int holidayQuotaProrated; // quota actually earned this month, scaled by days employed
  final int holidayDays; // actual holidays the employee took
  final int workingDaysBasis; // totalDays - 4, used purely to derive perDayRate
  final int employedDays; // days this month the employee was actually employed
  final int preJoiningDays;
  final int absentDays;
  final int extraDaysWorked;
  final double perDayRate;
  final double basePay; // perDayRate * (employedDays - holidayQuotaProrated)
  final double deduction;
  final double advanceDeducted;
  final double manualBonusAdded;
  final double extraDayBonus;
  final double payableSalary;

  SalaryResult({
    required this.employee,
    required this.totalDaysInMonth,
    required this.holidayQuota,
    required this.holidayQuotaProrated,
    required this.holidayDays,
    required this.workingDaysBasis,
    required this.employedDays,
    required this.preJoiningDays,
    required this.absentDays,
    required this.extraDaysWorked,
    required this.perDayRate,
    required this.basePay,
    required this.deduction,
    required this.advanceDeducted,
    required this.manualBonusAdded,
    required this.extraDayBonus,
    required this.payableSalary,
  });
}

class SalaryCalculator {
  static const int monthlyHolidayQuota = 4;

  static int _calculatePreJoiningDays({
    required String? joiningDate,
    required int year,
    required int month,
    required int totalDays,
  }) {
    if (joiningDate == null) return 0;

    final joined = DateTime.parse(joiningDate);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month, totalDays);

    if (!joined.isAfter(monthStart)) return 0;
    if (joined.isAfter(monthEnd)) return totalDays;
    return joined.day - 1;
  }

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

    // Per-day rate is always derived from a fully-employed month's
    // structure (total days minus the standard 4-day quota) - this is
    // a fixed rate, the same 26/27 days regardless of when someone joined.
    final workingDaysBasis = totalDays - monthlyHolidayQuota;
    final perDayRate =
        workingDaysBasis > 0 ? employee.monthlySalary / workingDaysBasis : 0.0;

    final preJoiningDays = _calculatePreJoiningDays(
      joiningDate: employee.joiningDate,
      year: year,
      month: month,
      totalDays: totalDays,
    );
    final employedDays = totalDays - preJoiningDays;

    // Holiday quota scaled to how much of the month was actually worked.
    final holidayQuotaProrated = (monthlyHolidayQuota * employedDays) ~/ totalDays;

    // The actual base pay owed: per-day rate times the days the employee
    // was both employed AND expected to work (i.e. excluding their
    // prorated holiday allowance). For a fully-employed month this comes
    // out exactly equal to the monthly salary, as expected.
    final basePay = perDayRate * (employedDays - holidayQuotaProrated);

    final deduction = perDayRate * absentDays;

    final extraDaysWorked =
        (holidayQuotaProrated - holidayDays).clamp(0, holidayQuotaProrated);
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

    final payable = basePay - deduction - advanceTotal + bonusTotal + extraDayBonus;

    return SalaryResult(
      employee: employee,
      totalDaysInMonth: totalDays,
      holidayQuota: monthlyHolidayQuota,
      holidayQuotaProrated: holidayQuotaProrated,
      holidayDays: holidayDays,
      workingDaysBasis: workingDaysBasis,
      employedDays: employedDays,
      preJoiningDays: preJoiningDays,
      absentDays: absentDays,
      extraDaysWorked: extraDaysWorked,
      perDayRate: perDayRate,
      basePay: basePay,
      deduction: deduction,
      advanceDeducted: advanceTotal,
      manualBonusAdded: bonusTotal,
      extraDayBonus: extraDayBonus,
      payableSalary: payable < 0 ? 0 : payable,
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