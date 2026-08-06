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
  // Maps employeeId -> isPresent, for the currently selected date
  Map<int, bool> _attendanceStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Converts a DateTime into the 'YYYY-MM-DD' string format we store in the DB
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final employees = await DatabaseHelper.instance.getAllEmployees();
    final dateStr = _formatDate(_selectedDate);
    final existingRecords = await DatabaseHelper.instance.getAttendanceForDate(dateStr);

    // Build a quick lookup map from the saved records
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
      _loadData(); // reload attendance status for the newly picked date
    }
  }

  // Saves the tapped status immediately - no separate "save" button needed,
  // which keeps this simple for your father to use.
  Future<void> _setStatus(int employeeId, bool isPresent) async {
    final dateStr = _formatDate(_selectedDate);
    await DatabaseHelper.instance.markAttendance(
      Attendance(employeeId: employeeId, date: dateStr, isPresent: isPresent),
    );
    setState(() {
      _attendanceStatus[employeeId] = isPresent;
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
          // Date selector bar at the top
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

  // A toggle-style button - filled when selected, outlined when not.
  // Large tap target and clear color coding (green/red) for easy use.
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
}