import '../models/employee.dart';
import '../db/database_helper.dart';

class SalaryResult {
  final Employee employee;
  final int totalDaysInMonth;
  final int expectedHolidays; // number of complete weeks in the month
  final int holidayDays; // actual holidays the employee took
  final int workingDaysInMonth;
  final int absentDays;
  final int extraDaysWorked; // complete weeks with no holiday taken + full attendance
  final double perDayRate;
  final double deduction;
  final double advanceDeducted;
  final double manualBonusAdded;
  final double extraDayBonus;
  final double payableSalary;

  SalaryResult({
    required this.employee,
    required this.totalDaysInMonth,
    required this.expectedHolidays,
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
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Finds every Monday..Sunday week that is FULLY contained within this
  // month (both the Monday and the following Sunday fall inside it).
  // This is what defines the "expected holidays" quota - normally 4,
  // sometimes 3 depending on how the month lines up with the calendar.
  static List<({DateTime start, DateTime end})> _completeWeeksInMonth(int year, int month) {
    final totalDays = DateTime(year, month + 1, 0).day;
    final weeks = <({DateTime start, DateTime end})>[];

    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      if (date.weekday == DateTime.monday) {
        final weekEnd = date.add(const Duration(days: 6));
        if (weekEnd.month == month && weekEnd.year == year) {
          weeks.add((start: date, end: weekEnd));
        }
      }
    }
    return weeks;
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

    // The month's quota of expected off-days, based purely on the calendar
    // (how many complete Mon-Sun weeks fit inside it) - NOT on what the
    // employee actually did. This is the fixed baseline the salary assumes.
    final completeWeeks = _completeWeeksInMonth(year, month);
    final expectedHolidays = completeWeeks.length;

    final workingDays = totalDays - expectedHolidays;
    final perDayRate = workingDays > 0 ? employee.monthlySalary / workingDays : 0.0;
    final deduction = perDayRate * absentDays;

    // For each complete week: if the employee took NO holiday that week
    // AND was marked Present on all 7 days, that's a day beyond what the
    // salary already covers - pay one extra day's rate for it.
    int extraDaysWorked = 0;
    for (final week in completeWeeks) {
      final weekRecords = records.where(
        (r) {
          final d = DateTime.parse(r.date);
          return !d.isBefore(week.start) && !d.isAfter(week.end);
        },
      ).toList();

      final tookHolidayThisWeek = weekRecords.any((r) => r.isHoliday);
      final presentCount = weekRecords.where((r) => r.isPresent).length;
      final fullyPresentAllWeek = presentCount == 7;

      if (!tookHolidayThisWeek && fullyPresentAllWeek) {
        extraDaysWorked++;
      }
    }
    final extraDayBonus = perDayRate * extraDaysWorked;

    // Manual advances and bonuses (from the Advance/Bonus screens)
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
      expectedHolidays: expectedHolidays,
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