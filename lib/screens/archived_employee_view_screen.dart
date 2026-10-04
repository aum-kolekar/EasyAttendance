import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import '../models/advance.dart';
import '../models/bonus.dart';
import '../services/salary_calculator.dart';

class ArchivedEmployeeViewScreen extends StatefulWidget {
  final Employee employee;

  const ArchivedEmployeeViewScreen({super.key, required this.employee});

  @override
  State<ArchivedEmployeeViewScreen> createState() => _ArchivedEmployeeViewScreenState();
}

class _ArchivedEmployeeViewScreenState extends State<ArchivedEmployeeViewScreen> {
  late DateTime _selectedMonth;
  bool _isLoading = true;

  Map<int, String> _statusByDay = {};
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
    // Start on the month the employee was archived in, if available,
    // otherwise today - gives the most relevant view first.
    final archivedDate = DateTime.parse(widget.employee.archivedAt!);
    _selectedMonth = DateTime(archivedDate.year, archivedDate.month, 1);
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
    if (next.isAfter(currentMonthStart)) return;
    setState(() => _selectedMonth = next);
    _loadData();
  }

  bool get _isViewingCurrentMonth {
    final today = DateTime.now();
    return _selectedMonth.year == today.year && _selectedMonth.month == today.month;
  }

  Future<void> _restoreEmployee() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Employee?'),
        content: Text('${widget.employee.name} will be moved back to your active employee list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.restoreEmployee(widget.employee.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  // Four separate, increasingly serious confirmations before permanent
  // deletion - specifically to survive an accidental tap or pocket touch.
  // Cancelling at ANY step aborts the whole thing.
  Future<void> _permanentlyDelete() async {
    final name = widget.employee.name;

    final step1 = await _confirmStep(
      title: 'Delete Permanently?',
      message: '$name will be permanently removed, along with all their '
          'attendance, advance, and bonus history.',
      confirmLabel: 'Continue',
      confirmColor: Colors.orange,
    );
    if (step1 != true || !mounted) return;

    final step2 = await _confirmStep(
      title: 'Are You Sure?',
      message: 'This action cannot be undone. All records for $name will '
          'be lost permanently.',
      confirmLabel: 'Continue',
      confirmColor: Colors.deepOrange,
    );
    if (step2 != true || !mounted) return;

    final step3 = await _confirmStep(
      title: 'Really Sure?',
      message: 'This is your last chance to stop. Once deleted, $name\'s '
          'data cannot be recovered by any means.',
      confirmLabel: 'Continue',
      confirmColor: Colors.red,
    );
    if (step3 != true || !mounted) return;

    final step4 = await _confirmStep(
      title: 'Final Confirmation',
      message: 'Tap "Delete Forever" to permanently erase $name and every '
          'record associated with them.',
      confirmLabel: 'Delete Forever',
      confirmColor: Colors.red.shade900,
    );
    if (step4 != true || !mounted) return;

    await DatabaseHelper.instance.deleteEmployee(widget.employee.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name has been permanently deleted')),
      );
      Navigator.pop(context);
    }
  }

  Future<bool?> _confirmStep({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee.name, style: const TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore',
            onPressed: _restoreEmployee,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Delete Permanently',
            onPressed: _permanentlyDelete,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Archived employee - view only. Restore to make changes.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 20),
                  if (_result != null) _buildSummary(_result!),
                  if (_advances.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTransactionList(
                      title: 'Advances',
                      icon: Icons.remove_circle_outline,
                      color: Colors.orange,
                      items: _advances
                          .map((a) => _transactionTile(date: a.date, amount: a.amount, note: a.note))
                          .toList(),
                    ),
                  ],
                  if (_bonuses.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTransactionList(
                      title: 'Bonuses',
                      icon: Icons.add_circle_outline,
                      color: Colors.green,
                      items: _bonuses
                          .map((b) => _transactionTile(date: b.date, amount: b.amount, note: b.note))
                          .toList(),
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
    final firstWeekday = DateTime(year, month, 1).weekday;
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

  // View-only - no double-tap editing here, unlike the active Reports screen.
  Widget _dayCell(int day) {
    final today = DateTime.now();
    final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final isFuture = cellDate.isAfter(DateTime(today.year, today.month, today.day));

    if (isFuture) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text('$day', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
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
        bgColor = Colors.grey.shade300;
        textColor = Colors.black87;
    }

    return Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
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
                        color: Colors.orange.shade800, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  if (hasBonus)
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade800, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                ],
              ),
            ),
        ],
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
            if (!r.isInProgress) ...[
              _row('Holiday Quota', isMidMonthJoiner
                  ? '${r.holidayQuotaProrated} (prorated)'
                  : '${r.holidayQuota}/month'),
              _row('Holidays Taken', '${r.holidayDays}'),
              _row('Base Pay', '₹${r.basePay.toStringAsFixed(2)}'),
              _row('Days Absent', '${r.absentDays}'),
              _row('Attendance Deduction', '- ₹${r.deduction.toStringAsFixed(2)}', color: Colors.red),
              if (r.extraDaysWorked > 0)
                _row('Extra Days Worked', '${r.extraDaysWorked}'),
              if (r.extraDayBonus > 0)
                _row('Extra Day Bonus', '+ ₹${r.extraDayBonus.toStringAsFixed(2)}', color: Colors.green),
            ] else ...[
              _row('Days Present', '${r.presentDaysSoFar}'),
              _row('Holidays Taken', '${r.holidayDays}'),
              _row('Days Absent', '${r.absentDays}'),
            ],
            if (r.advanceDeducted > 0)
              _row('Advance Deducted', '- ₹${r.advanceDeducted.toStringAsFixed(2)}', color: Colors.orange),
            if (r.manualBonusAdded > 0)
              _row('Bonus Added', '+ ₹${r.manualBonusAdded.toStringAsFixed(2)}', color: Colors.green),
            const Divider(height: 20),
            _row('Payable', '₹${r.payableSalary.toStringAsFixed(2)}',
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
    required List<Widget> items,
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
            ...items,
          ],
        ),
      ),
    );
  }

  // Read-only - no delete button here, unlike the active Reports screen.
  Widget _transactionTile({required String date, required double amount, required String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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