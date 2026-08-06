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
  // Maps employeeId -> isPresent (or "worked extra" on Sundays), for the selected date
  Map<int, bool> _attendanceStatus = {};
  bool _isLoading = true;

  // Dart's DateTime.weekday: Monday=1 ... Sunday=7
  bool get _isSunday => _selectedDate.weekday == DateTime.sunday;

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

    final statusMap = <int, bool>{};
    for (final record in existingRecords) {
      statusMap[record.employeeId] = record.isPresent;
    }

    setState(() {
      _employees = employees;
      _attendanceStatus = statusMap;
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

  // Regular weekday: set Present/Absent
  Future<void> _setStatus(int employeeId, bool isPresent) async {
    final dateStr = _formatDate(_selectedDate);
    await DatabaseHelper.instance.markAttendance(
      Attendance(employeeId: employeeId, date: dateStr, isPresent: isPresent),
    );
    setState(() {
      _attendanceStatus[employeeId] = isPresent;
    });
  }

  // Sunday: toggle "worked extra day" on/off
  Future<void> _toggleExtraDay(int employeeId) async {
    final dateStr = _formatDate(_selectedDate);
    final currentlyMarked = _attendanceStatus[employeeId] == true;

    if (currentlyMarked) {
      // Un-mark: remove the record entirely (no extra pay, no deduction either)
      await DatabaseHelper.instance.deleteAttendanceForDate(employeeId, dateStr);
      setState(() => _attendanceStatus.remove(employeeId));
    } else {
      // Mark as worked - this is what triggers the bonus day's pay
      await DatabaseHelper.instance.markAttendance(
        Attendance(employeeId: employeeId, date: dateStr, isPresent: true),
      );
      setState(() => _attendanceStatus[employeeId] = true);
    }
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
            child: Column(
              children: [
                InkWell(
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
                if (_isSunday) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Sunday — off day. Mark only if the employee worked.',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
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
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      employee.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_isSunday)
                                    _extraDayButton(
                                      isMarked: status == true,
                                      onTap: () => _toggleExtraDay(employee.id!),
                                    )
                                  else ...[
                                    _statusButton(
                                      label: 'Present',
                                      color: Colors.green,
                                      isSelected: status == true,
                                      onTap: () => _setStatus(employee.id!, true),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusButton(
                                      label: 'Absent',
                                      color: Colors.red,
                                      isSelected: status == false,
                                      onTap: () => _setStatus(employee.id!, false),
                                    ),
                                  ],
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
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  // Single button for Sundays - toggles between "Mark Extra Day" and "Extra Day ✓"
  Widget _extraDayButton({required bool isMarked, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(isMarked ? Icons.check_circle : Icons.add_circle_outline, size: 18),
      label: Text(
        isMarked ? 'Extra Day ✓' : 'Mark Extra Day',
        style: const TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isMarked ? Colors.blue : Colors.grey.shade200,
        foregroundColor: isMarked ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}