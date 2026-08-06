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
          // Month selector bar
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
                                  _row('Working Days (excl. Sundays)', '${r.workingDaysInMonth}'),
                                  _row('Per-Day Rate', '₹${r.perDayRate.toStringAsFixed(2)}'),
                                  _row('Days Absent', '${r.absentDays}'),
                                  _row('Deduction', '- ₹${r.deduction.toStringAsFixed(2)}',
                                      color: Colors.red),
                                  if (r.extraDaysWorked > 0) ...[
                                    _row('Extra Days Worked (Sundays)', '${r.extraDaysWorked}'),
                                    _row('Bonus', '+ ₹${r.bonus.toStringAsFixed(2)}',
                                        color: Colors.blue),
                                  ],
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

  Widget _row(String label, String value, {bool bold = false, Color? color, double fontSize = 15}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: Colors.black87)),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}