import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import '../models/attendance.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  static const int monthlyHolidayQuota = 4;

  DateTime _selectedDate = DateTime.now();
  List<Employee> _employees = [];
  Map<int, String> _attendanceStatus = {};
  // Tracks, per employee, how many holidays they've already used THIS
  // MONTH on days other than the currently selected one.
  Map<int, int> _holidaysUsedElsewhereThisMonth = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final employees = await DatabaseHelper.instance.getAllEmployees();
    final dateStr = _formatDate(_selectedDate);
    final existingRecords = await DatabaseHelper.instance.getAttendanceForDate(dateStr);

    final statusMap = <int, String>{};
    for (final record in existingRecords) {
      statusMap[record.employeeId] = record.status;
    }

    // For each employee, count how many holidays they've used THIS MONTH,
    // excluding the currently selected date (so re-tapping the same day
    // doesn't count itself twice).
    final totalDaysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final monthStartStr = _formatDate(DateTime(_selectedDate.year, _selectedDate.month, 1));
    final monthEndStr =
        _formatDate(DateTime(_selectedDate.year, _selectedDate.month, totalDaysInMonth));

    final holidayCountMap = <int, int>{};
    for (final employee in employees) {
      final monthRecords = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
        employee.id!,
        monthStartStr,
        monthEndStr,
      );
      final usedElsewhere = monthRecords.where(
        (r) => r.isHoliday && r.date != dateStr,
      ).length;
      holidayCountMap[employee.id!] = usedElsewhere;
    }

    setState(() {
      _employees = employees;
      _attendanceStatus = statusMap;
      _holidaysUsedElsewhereThisMonth = holidayCountMap;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _setStatus(int employeeId, String status) async {
    final dateStr = _formatDate(_selectedDate);
    await DatabaseHelper.instance.markAttendance(
      Attendance(employeeId: employeeId, date: dateStr, status: status),
    );
    setState(() {
      _attendanceStatus[employeeId] = status;
    });
    // Holiday counts may need to re-sync if this changes totals, but since
    // we only track "used elsewhere" (not today), a quick reload keeps
    // everything consistent without extra bookkeeping.
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance', style: TextStyle(fontSize: 20)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('(tap to change)', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(
                        child: Text(
                          'No employees yet.\nAdd employees first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _employees.length,
                        itemBuilder: (context, index) {
                          final employee = _employees[index];
                          final status = _attendanceStatus[employee.id];
                          final usedElsewhere =
                              _holidaysUsedElsewhereThisMonth[employee.id] ?? 0;
                          final quotaReached = usedElsewhere >= monthlyHolidayQuota;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _statusButton(
                                          label: 'Present',
                                          color: Colors.green,
                                          isSelected: status == 'present',
                                          onTap: () => _setStatus(employee.id!, 'present'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _statusButton(
                                          label: 'Absent',
                                          color: Colors.red,
                                          isSelected: status == 'absent',
                                          onTap: () => _setStatus(employee.id!, 'absent'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _statusButton(
                                          label: 'Holiday',
                                          color: Colors.blue,
                                          isSelected: status == 'holiday',
                                          onTap: quotaReached
                                              ? null
                                              : () => _setStatus(employee.id!, 'holiday'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    quotaReached
                                        ? 'Holiday quota used ($usedElsewhere/$monthlyHolidayQuota this month)'
                                        : 'Holidays used this month: $usedElsewhere/$monthlyHolidayQuota',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: quotaReached ? Colors.red.shade400 : Colors.grey,
                                    ),
                                  ),
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

  Widget _statusButton({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}