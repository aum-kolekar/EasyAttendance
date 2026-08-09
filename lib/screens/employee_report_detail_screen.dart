import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
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
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadData();
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
                        icon: const Icon(Icons.chevron_right, size: 30),
                        onPressed: () => _changeMonth(1),
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
    final status = _statusByDay[day];
    final hasAdvance = _hasAdvanceByDay[day] == true;
    final hasBonus = _hasBonusByDay[day] == true;

    Color bgColor;
    Color textColor;
    switch (status) {
      case 'present':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case 'absent':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        break;
      case 'holiday':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.black54;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
          ),
          if (hasAdvance || hasBonus)
            Positioned(
              bottom: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasAdvance)
                    Container(
                      width: 5, height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    ),
                  if (hasBonus)
                    Container(
                      width: 5, height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
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
        _legendItem(Colors.green.shade100, 'Present'),
        _legendItem(Colors.red.shade100, 'Absent'),
        _legendItem(Colors.blue.shade100, 'Holiday'),
        _legendDot(Colors.orange, 'Advance'),
        _legendDot(Colors.green, 'Bonus'),
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