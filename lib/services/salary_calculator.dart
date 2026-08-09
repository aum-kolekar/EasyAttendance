import '../models/employee.dart';
import '../db/database_helper.dart';

class SalaryResult {
  final Employee employee;
  final int totalDaysInMonth;
  final int holidayQuota;
  final int holidayQuotaProrated;
  final int holidayDays;
  final int workingDaysBasis;
  final int employedDays;
  final int preJoiningDays;
  final int absentDays;
  final int extraDaysWorked;
  final double perDayRate;
  final double basePay;
  final double deduction;
  final double advanceDeducted;
  final double manualBonusAdded;
  final double extraDayBonus;
  final double payableSalary;
  // True if this month hasn't finished yet - payableSalary reflects
  // only days elapsed so far, and extra-day bonus is withheld until
  // the month actually completes.
  final bool isInProgress;
  final int presentDaysSoFar;

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
    required this.isInProgress,
    this.presentDaysSoFar = 0,
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
    final today = DateTime.now();
    final isCurrentMonth = year == today.year && month == today.month;
    final isFutureMonth =
        DateTime(year, month, 1).isAfter(DateTime(today.year, today.month, 1));

    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate =
        '$year-${month.toString().padLeft(2, '0')}-${totalDays.toString().padLeft(2, '0')}';

    final records = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
      employee.id!,
      startDate,
      endDate,
    );

    final workingDaysBasis = totalDays - monthlyHolidayQuota;
    final perDayRate =
        workingDaysBasis > 0 ? employee.monthlySalary / workingDaysBasis : 0.0;

    final preJoiningDays = _calculatePreJoiningDays(
      joiningDate: employee.joiningDate,
      year: year,
      month: month,
      totalDays: totalDays,
    );

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

    if (isFutureMonth) {
      // Nothing has happened yet - everything is zero.
      return SalaryResult(
        employee: employee,
        totalDaysInMonth: totalDays,
        holidayQuota: monthlyHolidayQuota,
        holidayQuotaProrated: 0,
        holidayDays: 0,
        workingDaysBasis: workingDaysBasis,
        employedDays: 0,
        preJoiningDays: preJoiningDays,
        absentDays: 0,
        extraDaysWorked: 0,
        perDayRate: perDayRate,
        basePay: 0,
        deduction: 0,
        advanceDeducted: 0,
        manualBonusAdded: 0,
        extraDayBonus: 0,
        payableSalary: 0,
        isInProgress: true,
      );
    }

    if (isCurrentMonth) {
      // ACCRUAL MODEL: only count days that have actually happened and
      // were actually marked - no assumptions about the rest of the
      // month, and no extra-day bonus until the month finishes.
      int presentDaysSoFar = 0;
      int holidayDaysSoFar = 0;
      int absentDaysSoFar = 0;

      for (final record in records) {
        final day = DateTime.parse(record.date).day;
        if (day > today.day) continue; // safety - shouldn't happen
        if (record.isPresent) presentDaysSoFar++;
        if (record.isHoliday) holidayDaysSoFar++;
        if (record.isAbsent) absentDaysSoFar++;
      }

      final basePay = perDayRate * (presentDaysSoFar + holidayDaysSoFar);
      final payable = basePay - advanceTotal + bonusTotal;

      return SalaryResult(
        employee: employee,
        totalDaysInMonth: totalDays,
        holidayQuota: monthlyHolidayQuota,
        holidayQuotaProrated: 0, // not finalized until month end
        holidayDays: holidayDaysSoFar,
        workingDaysBasis: workingDaysBasis,
        employedDays: today.day - preJoiningDays.clamp(0, today.day),
        preJoiningDays: preJoiningDays,
        absentDays: absentDaysSoFar,
        extraDaysWorked: 0,
        perDayRate: perDayRate,
        basePay: basePay,
        deduction: 0,
        advanceDeducted: advanceTotal,
        manualBonusAdded: bonusTotal,
        extraDayBonus: 0,
        payableSalary: payable < 0 ? 0 : payable,
        isInProgress: true,
        presentDaysSoFar: presentDaysSoFar,
      );
    }

    // COMPLETED PAST MONTH: full existing model.
    int absentDays = 0;
    int holidayDays = 0;
    for (final record in records) {
      if (record.isAbsent) absentDays++;
      if (record.isHoliday) holidayDays++;
    }

    final employedDays = totalDays - preJoiningDays;
    final holidayQuotaProrated = (monthlyHolidayQuota * employedDays) ~/ totalDays;
    final basePay = perDayRate * (employedDays - holidayQuotaProrated);
    final deduction = perDayRate * absentDays;
    final extraDaysWorked =
        (holidayQuotaProrated - holidayDays).clamp(0, holidayQuotaProrated);
    final extraDayBonus = perDayRate * extraDaysWorked;

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
      isInProgress: false,
    );
  }

  static Future<List<SalaryResult>> calculateForAllEmployees({
    required int year,
    required int month,
  }) async {
    final employees = await DatabaseHelper.instance.getAllEmployees();
    final results = <SalaryResult>[];
    for (final employee in employees) {
      final result = await calculateForEmployee(employee: employee, year: year, month: month);
      results.add(result);
    }
    return results;
  }
}