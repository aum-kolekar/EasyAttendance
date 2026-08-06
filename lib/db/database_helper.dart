import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/attendance.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_app.db');

    return await openDatabase(
      path,
      // Bumped from 1 -> 2 because we're adding a new table.
      // Flutter/sqflite uses this number to know when to run onUpgrade.
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Runs only on a brand-new install (no existing database).
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        monthlySalary REAL NOT NULL
      )
    ''');
    await _createAttendanceTable(db);
  }

  // Runs when an existing app is updated to a new database version.
  // This preserves data already on the device (e.g. your employees from Stage 2).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAttendanceTable(db);
    }
  }

  Future<void> _createAttendanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        date TEXT NOT NULL,
        isPresent INTEGER NOT NULL,
        FOREIGN KEY (employeeId) REFERENCES employees (id) ON DELETE CASCADE,
        UNIQUE (employeeId, date)
      )
    ''');
  }

  // --- Employee CRUD (unchanged from Stage 2) ---

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    return await db.insert('employees', employee.toMap()..remove('id'));
  }

  Future<List<Employee>> getAllEmployees() async {
    final db = await database;
    final maps = await db.query('employees', orderBy: 'name ASC');
    return maps.map((map) => Employee.fromMap(map)).toList();
  }

  Future<Employee?> getEmployee(int id) async {
    final db = await database;
    final maps = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<int> updateEmployee(Employee employee) async {
    final db = await database;
    return await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // --- Attendance operations ---

  // Marks (or updates) attendance for one employee on one date.
  // Uses INSERT OR REPLACE so tapping the same employee/date twice
  // just overwrites the previous value instead of creating duplicates
  // (the UNIQUE constraint above on employeeId+date makes this safe).
  Future<void> markAttendance(Attendance attendance) async {
    final db = await database;
    await db.insert(
      'attendance',
      attendance.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Gets all attendance records for a specific date (used to show
  // today's/selected date's present/absent state for every employee)
  Future<List<Attendance>> getAttendanceForDate(String date) async {
    final db = await database;
    final maps = await db.query('attendance', where: 'date = ?', whereArgs: [date]);
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  // Removes a single attendance record for one employee on one date.
  // Used to "un-mark" a Sunday extra-work day.
  Future<void> deleteAttendanceForDate(int employeeId, String date) async {
    final db = await database;
    await db.delete(
      'attendance',
      where: 'employeeId = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
  }

  // Gets all attendance records for one employee within a date range
  // (used later in Stage 5 for salary calculation)
  Future<List<Attendance>> getAttendanceForEmployeeInRange(
    int employeeId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'attendance',
      where: 'employeeId = ? AND date >= ? AND date <= ?',
      whereArgs: [employeeId, startDate, endDate],
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }
}