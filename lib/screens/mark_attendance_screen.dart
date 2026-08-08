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
  DateTime _selectedDate = DateTime.now();
  List<Employee> _employees = [];
  Map<int, String> _attendanceStatus = {};
  // Tracks, per employee, whether they've already used their one holiday
  // for the week containing _selectedDate (on a DIFFERENT day than today)
  Map<int, bool> _holidayUsedElsewhereThisWeek = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Monday..Sunday range containing the given date.
  // DateTime.weekday: Monday = 1 ... Sunday = 7
  ({DateTime start, DateTime end}) _weekRangeFor(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return (start: start, end: end);
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

    // For each employee, check if they've already used a Holiday this
    // week on a day OTHER than the currently selected one.
    final week = _weekRangeFor(_selectedDate);
    final weekStartStr = _formatDate(week.start);
    final weekEndStr = _formatDate(week.end);

    final holidayUsedMap = <int, bool>{};
    for (final employee in employees) {
      final weekRecords = await DatabaseHelper.instance.getAttendanceForEmployeeInRange(
        employee.id!,
        weekStartStr,
        weekEndStr,
      );
      final usedElsewhere = weekRecords.any(
        (r) => r.isHoliday && r.date != dateStr,
      );
      holidayUsedMap[employee.id!] = usedElsewhere;
    }

    setState(() {
      _employees = employees;
      _attendanceStatus = statusMap;
      _holidayUsedElsewhereThisWeek = holidayUsedMap;
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
                                          onTap: (_holidayUsedElsewhereThisWeek[employee.id] ?? false)
                                              ? null
                                              : () => _setStatus(employee.id!, 'holiday'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((_holidayUsedElsewhereThisWeek[employee.id] ?? false))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Holiday already used this week',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
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