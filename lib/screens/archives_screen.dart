import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/employee.dart';
import 'archived_employee_view_screen.dart';

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  List<Employee> _archived = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    setState(() => _isLoading = true);
    final archived = await DatabaseHelper.instance.getArchivedEmployees();
    setState(() {
      _archived = archived;
      _isLoading = false;
    });
  }

  String _formatArchivedDate(String isoString) {
    final d = DateTime.parse(isoString);
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _restoreEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Employee?'),
        content: Text('${employee.name} will be moved back to your active employee list.'),
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
      await DatabaseHelper.instance.restoreEmployee(employee.id!);
      _loadArchived();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archives', style: TextStyle(fontSize: 22)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archived.isEmpty
              ? const Center(
                  child: Text(
                    'No archived employees.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _archived.length,
                  itemBuilder: (context, index) {
                    final employee = _archived[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade300,
                          child: const Icon(Icons.person_off_outlined, size: 26),
                        ),
                        title: Text(
                          employee.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        subtitle: Text(
                          'Archived on ${_formatArchivedDate(employee.archivedAt!)}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          tooltip: 'Restore',
                          onPressed: () => _restoreEmployee(employee),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArchivedEmployeeViewScreen(employee: employee),
                            ),
                          );
                          _loadArchived(); // refresh in case permanently deleted
                        },
                      ),
                    );
                  },
                ),
    );
  }
}