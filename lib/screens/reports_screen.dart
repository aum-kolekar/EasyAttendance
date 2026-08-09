import 'package:flutter/material.dart';
import '../services/salary_calculator.dart';
import 'employee_report_detail_screen.dart';

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
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    final today = DateTime.now();
    final currentMonthStart = DateTime(today.year, today.month, 1);
    if (next.isAfter(currentMonthStart)) return;
    setState(() => _selectedMonth = next);
    _loadResults();
  }

  bool get _isViewingCurrentMonth {
    final today = DateTime.now();
    return _selectedMonth.year == today.year && _selectedMonth.month == today.month;
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
                  icon: Icon(
                    Icons.chevron_right,
                    size: 30,
                    color: _isViewingCurrentMonth ? Colors.grey.shade300 : null,
                  ),
                  onPressed: _isViewingCurrentMonth ? null : () => _changeMonth(1),
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
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: const CircleAvatar(
                                radius: 24,
                                child: Icon(Icons.person, size: 28),
                              ),
                              // Name takes about half the row; long names
                              // fade out toward the right instead of
                              // wrapping or overflowing.
                              title: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.black, Colors.black, Colors.transparent],
                                  stops: [0.0, 0.85, 1.0],
                                ).createShader(bounds),
                                blendMode: BlendMode.dstIn,
                                child: Text(
                                  r.employee.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${r.payableSalary.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  if (r.isInProgress)
                                    Text(
                                      'so far',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmployeeReportDetailScreen(
                                      employee: r.employee,
                                      initialMonth: _selectedMonth,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}