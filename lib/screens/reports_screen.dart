import 'package:flutter/material.dart';
import '../services/salary_calculator.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedMonth = DateTime.now();
  List<SalaryResult> _results = [];
  bool _isLoading = true;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final results = await SalaryCalculator.calculateForAllEmployees(
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadResults();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Reports', style: TextStyle(fontSize: 20)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
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
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'No employees yet.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          final isMidMonthJoiner = r.preJoiningDays > 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.employee.name,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
                                  _row('Attendance Deduction', '- ₹${r.deduction.toStringAsFixed(2)}',
                                      color: Colors.red),
                                  if (r.advanceDeducted > 0)
                                    _row('Advance Deducted', '- ₹${r.advanceDeducted.toStringAsFixed(2)}',
                                        color: Colors.orange),
                                  if (r.extraDaysWorked > 0)
                                    _row('Extra Days Worked (unused holidays)', '${r.extraDaysWorked}'),
                                  if (r.extraDayBonus > 0)
                                    _row('Extra Day Bonus', '+ ₹${r.extraDayBonus.toStringAsFixed(2)}',
                                        color: Colors.green),
                                  if (r.manualBonusAdded > 0)
                                    _row('Bonus Added', '+ ₹${r.manualBonusAdded.toStringAsFixed(2)}',
                                        color: Colors.green),
                                  const Divider(height: 20),
                                  _row('Payable Salary', '₹${r.payableSalary.toStringAsFixed(2)}',
                                      bold: true, color: Colors.green.shade700, fontSize: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Fixed to prevent the overflow error: label is Expanded (wraps/shrinks
  // as needed) and value is Flexible with right-aligned text, so long
  // strings never push past the edge of the card.
  Widget _row(String label, String value, {bool bold = false, Color? color, double fontSize = 15}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: fontSize, color: Colors.black87)),
          ),
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
}