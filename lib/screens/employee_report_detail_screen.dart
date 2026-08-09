import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/advance.dart';
import '../models/bonus.dart';
import '../services/salary_calculator.dart';

class EmployeeReportDetailScreen extends StatefulWidget {
  final Employee employee;
  final DateTime initialMonth;

  const EmployeeReportDetailScreen({
    super.key,
    required this.employee,
    required this.initialMonth,
  });

  @override
  State<EmployeeReportDetailScreen> createState() => _EmployeeReportDetailScreenState();
}

class _EmployeeReportDetailScreenState extends State<EmployeeReportDetailScreen> {
  late DateTime _selectedMonth;
  bool _isLoading = true;

  Map<int, String> _statusByDay = {}; // day -> 'present'/'absent'/'holiday'
  Map<int, bool> _hasAdvanceByDay = {};
  Map<int, bool> _hasBonusByDay = {};
  List<Advance> _advances = [];
  List<Bonus> _bonuses = [];
  SalaryResult? _result;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = '$year-${month.toString().padLeft(2, '0')}-${totalDays.toString().padLeft(2, '0')}';

    final attendance = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
      widget.employee.id!,
      startDate,
      endDate,
    );
    final advances = await DatabaseHelper.instance.getAdvancesForEmployeeInRange(
      widget.employee.id!,
      startDate,
      endDate,
    );
    final bonuses = await DatabaseHelper.instance.getBonusesForEmployeeInRange(
      widget.employee.id!,
      startDate,
      endDate,
    );
    final result = await SalaryCalculator.calculateForEmployee(
      employee: widget.employee,
      year: year,
      month: month,
    );

    final statusMap = <int, String>{};
    for (final a in attendance) {
      statusMap[DateTime.parse(a.date).day] = a.status;
    }
    final advanceMap = <int, bool>{};
    for (final a in advances) {
      advanceMap[DateTime.parse(a.date).day] = true;
    }
    final bonusMap = <int, bool>{};
    for (final b in bonuses) {
      bonusMap[DateTime.parse(b.date).day] = true;
    }

    setState(() {
      _statusByDay = statusMap;
      _hasAdvanceByDay = advanceMap;
      _hasBonusByDay = bonusMap;
      _advances = advances;
      _bonuses = bonuses;
      _result = result;
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    final today = DateTime.now();
    final currentMonthStart = DateTime(today.year, today.month, 1);
    // Never allow navigating past the current month.
    if (next.isAfter(currentMonthStart)) return;
    setState(() => _selectedMonth = next);
    _loadData();
  }

  bool get _isViewingCurrentMonth {
    final today = DateTime.now();
    return _selectedMonth.year == today.year && _selectedMonth.month == today.month;
  }

  Future<void> _confirmDeleteAdvance(Advance a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Advance?'),
        content: Text('Remove the ₹${a.amount.toStringAsFixed(0)} advance from ${a.date}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteAdvance(a.id!);
      _loadData();
    }
  }

  Future<void> _confirmDeleteBonus(Bonus b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bonus?'),
        content: Text('Remove the ₹${b.amount.toStringAsFixed(0)} bonus from ${b.date}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteBonus(b.id!);
      _loadData();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _monthlyHolidayQuota = 4;

  // Quick-mark: double-tapping a calendar day opens this instead of
  // requiring a trip back to Mark Attendance. Shows the same
  // Present/Absent/Holiday choice, pre-filled with whatever is
  // currently set for that day.
  Future<void> _showQuickMarkDialog(int day) async {
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final dateStr = _formatDate(date);
    final currentStatus = _statusByDay[day];

    // Check how many holidays are already used this month, excluding
    // this specific day - same rule as the main Mark Attendance screen.
    final totalDays = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final monthStart = _formatDate(DateTime(_selectedMonth.year, _selectedMonth.month, 1));
    final monthEnd = _formatDate(DateTime(_selectedMonth.year, _selectedMonth.month, totalDays));
    final monthRecords = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
      widget.employee.id!,
      monthStart,
      monthEnd,
    );
    final holidaysUsedElsewhere =
        monthRecords.where((r) => r.isHoliday && r.date != dateStr).length;
    final holidayQuotaReached = holidaysUsedElsewhere >= _monthlyHolidayQuota;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.employee.name, style: const TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 16),
              _quickStatusButton(
                label: 'Present',
                color: Colors.green,
                isSelected: currentStatus == 'present',
                onTap: () => _quickSetStatus(dialogContext, dateStr, 'present'),
              ),
              const SizedBox(height: 8),
              _quickStatusButton(
                label: 'Absent',
                color: Colors.red,
                isSelected: currentStatus == 'absent',
                onTap: () => _quickSetStatus(dialogContext, dateStr, 'absent'),
              ),
              const SizedBox(height: 8),
              _quickStatusButton(
                label: holidayQuotaReached && currentStatus != 'holiday'
                    ? 'Holiday (quota used: $holidaysUsedElsewhere/$_monthlyHolidayQuota)'
                    : 'Holiday',
                color: Colors.blue,
                isSelected: currentStatus == 'holiday',
                onTap: (holidayQuotaReached && currentStatus != 'holiday')
                    ? null
                    : () => _quickSetStatus(dialogContext, dateStr, 'holiday'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _quickSetStatus(BuildContext dialogContext, String dateStr, String status) async {
    await DatabaseHelper.instance.markAttendance(
      Attendance(employeeId: widget.employee.id!, date: dateStr, status: status),
    );
    if (dialogContext.mounted) Navigator.pop(dialogContext);
    _loadData(); // refresh calendar and salary summary immediately
  }

  Widget _quickStatusButton({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? color
            : (isDisabled ? Colors.grey.shade100 : Colors.grey.shade200),
        foregroundColor: isSelected
            ? Colors.white
            : (isDisabled ? Colors.grey.shade400 : Colors.black87),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee.name, style: const TextStyle(fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Month navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 30),
                        onPressed: () => _changeMonth(-1),
                      ),
                      SizedBox(
                        width: 180,
                        child: Text(
                          monthLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          size: 30,
                          color: _isViewingCurrentMonth ? Colors.grey.shade300 : null,
                        ),
                        onPressed: _isViewingCurrentMonth ? null : () => _changeMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCalendar(),
                  const SizedBox(height: 12),
                  _buildLegend(),
                  const SizedBox(height: 6),
                  Text(
                    'Tip: double-tap any past day to quickly mark or fix attendance',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 20),
                  if (_result != null) _buildSummary(_result!),
                  if (_advances.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTransactionList(
                      title: 'Advances',
                      icon: Icons.remove_circle_outline,
                      color: Colors.orange,
                      children: _advances.map((a) => _transactionTile(
                        date: a.date,
                        amount: a.amount,
                        note: a.note,
                        onDelete: () => _confirmDeleteAdvance(a),
                      )).toList(),
                    ),
                  ],
                  if (_bonuses.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTransactionList(
                      title: 'Bonuses',
                      icon: Icons.add_circle_outline,
                      color: Colors.green,
                      children: _bonuses.map((b) => _transactionTile(
                        date: b.date,
                        amount: b.amount,
                        note: b.note,
                        onDelete: () => _confirmDeleteBonus(b),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // Monday=1..Sunday=7
    final leadingBlanks = firstWeekday - 1;

    final cells = <Widget>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (int day = 1; day <= totalDays; day++) {
      cells.add(_dayCell(day));
    }

    return Column(
      children: [
        const Row(
          children: [
            _WeekdayLabel('Mon'), _WeekdayLabel('Tue'), _WeekdayLabel('Wed'),
            _WeekdayLabel('Thu'), _WeekdayLabel('Fri'), _WeekdayLabel('Sat'), _WeekdayLabel('Sun'),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
      ],
    );
  }

  Widget _dayCell(int day) {
    final today = DateTime.now();
    final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final isFuture = cellDate.isAfter(DateTime(today.year, today.month, today.day));

    if (isFuture) {
      // Future days: clearly inactive, no status possible yet.
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
          ),
        ),
      );
    }

    final status = _statusByDay[day];
    final hasAdvance = _hasAdvanceByDay[day] == true;
    final hasBonus = _hasBonusByDay[day] == true;

    Color bgColor;
    Color textColor;
    switch (status) {
      case 'present':
        bgColor = Colors.green.shade400;
        textColor = Colors.white;
        break;
      case 'absent':
        bgColor = Colors.red.shade400;
        textColor = Colors.white;
        break;
      case 'holiday':
        bgColor = Colors.blue.shade400;
        textColor = Colors.white;
        break;
      default:
        // Past/today with no record marked - neutral gray, distinct
        // from both the status colors and the future-day style.
        bgColor = Colors.grey.shade300;
        textColor = Colors.black87;
    }

    return GestureDetector(
      onDoubleTap: () => _showQuickMarkDialog(day),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
            ),
            if (hasAdvance || hasBonus)
              Positioned(
                bottom: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasAdvance)
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade800,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    if (hasBonus)
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade800,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendItem(Colors.green.shade400, 'Present'),
        _legendItem(Colors.red.shade400, 'Absent'),
        _legendItem(Colors.blue.shade400, 'Holiday'),
        _legendDot(Colors.orange.shade800, 'Advance'),
        _legendDot(Colors.teal.shade800, 'Bonus'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSummary(SalaryResult r) {
    final isMidMonthJoiner = r.preJoiningDays > 0;

    if (r.isInProgress) {
      // Simplified view for the current, still-running month.
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Salary So Far', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Month in progress',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Final totals (including any unused holiday bonus) are calculated once the month ends.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              _row('Monthly Salary', '₹${r.employee.monthlySalary.toStringAsFixed(2)}'),
              _row('Per-Day Rate', '₹${r.perDayRate.toStringAsFixed(2)} (basis: ${r.workingDaysBasis} days)'),
              _row('Days Present So Far', '${r.presentDaysSoFar}'),
              _row('Holidays Taken So Far', '${r.holidayDays}'),
              _row('Days Absent So Far', '${r.absentDays}'),
              if (r.advanceDeducted > 0)
                _row('Advance Deducted', '- ₹${r.advanceDeducted.toStringAsFixed(2)}', color: Colors.orange),
              if (r.manualBonusAdded > 0)
                _row('Bonus Added', '+ ₹${r.manualBonusAdded.toStringAsFixed(2)}', color: Colors.green),
              const Divider(height: 20),
              _row('Payable So Far', '₹${r.payableSalary.toStringAsFixed(2)}',
                  bold: true, color: Colors.green.shade700, fontSize: 18),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Salary Breakdown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _row('Monthly Salary', '₹${r.employee.monthlySalary.toStringAsFixed(2)}'),
            _row('Per-Day Rate', '₹${r.perDayRate.toStringAsFixed(2)} (basis: ${r.workingDaysBasis} days)'),
            if (isMidMonthJoiner)
              _row('Days Employed This Month', '${r.employedDays} / ${r.totalDaysInMonth}'),
            _row('Holiday Quota', isMidMonthJoiner
                ? '${r.holidayQuotaProrated} (prorated)'
                : '${r.holidayQuota}/month'),
            _row('Holidays Taken', '${r.holidayDays}'),
            _row('Base Pay', '₹${r.basePay.toStringAsFixed(2)}'),
            _row('Days Absent', '${r.absentDays}'),
            _row('Attendance Deduction', '- ₹${r.deduction.toStringAsFixed(2)}', color: Colors.red),
            if (r.advanceDeducted > 0)
              _row('Advance Deducted', '- ₹${r.advanceDeducted.toStringAsFixed(2)}', color: Colors.orange),
            if (r.extraDaysWorked > 0)
              _row('Extra Days Worked', '${r.extraDaysWorked}'),
            if (r.extraDayBonus > 0)
              _row('Extra Day Bonus', '+ ₹${r.extraDayBonus.toStringAsFixed(2)}', color: Colors.green),
            if (r.manualBonusAdded > 0)
              _row('Bonus Added', '+ ₹${r.manualBonusAdded.toStringAsFixed(2)}', color: Colors.green),
            const Divider(height: 20),
            _row('Payable Salary', '₹${r.payableSalary.toStringAsFixed(2)}',
                bold: true, color: Colors.green.shade700, fontSize: 18),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color, double fontSize = 15}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: fontSize, color: Colors.black87))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _transactionTile({
    required String date,
    required double amount,
    required String? note,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  note != null ? '$date · $note' : date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
      ),
    );
  }
}