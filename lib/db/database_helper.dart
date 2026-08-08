import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/advance.dart';
import '../models/bonus.dart';

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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        monthlySalary REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (employeeId) REFERENCES employees (id) ON DELETE CASCADE,
        UNIQUE (employeeId, date)
      )
    ''');

    await _createAdvancesTable(db);
    await _createBonusesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employeeId INTEGER NOT NULL,
          date TEXT NOT NULL,
          isPresent INTEGER NOT NULL,
          FOREIGN KEY (employeeId) REFERENCES employees (id) ON DELETE CASCADE,
          UNIQUE (employeeId, date)
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add the new 'status' column and translate old true/false data
      // into it. The old 'isPresent' column is left in place unused -
      // harmless, and safer than trying to drop a column in SQLite.
      await db.execute("ALTER TABLE attendance ADD COLUMN status TEXT");
      await db.execute('''
        UPDATE attendance
        SET status = CASE WHEN isPresent = 1 THEN 'present' ELSE 'absent' END
        WHERE status IS NULL
      ''');
      await _createAdvancesTable(db);
    }
    if (oldVersion < 4) {
      // Fix: the old 'isPresent' column is still NOT NULL, but our new
      // code never sets it - every save was silently failing. Rebuild
      // the table cleanly with only the columns we actually use now.
      await db.execute('''
        CREATE TABLE attendance_new(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employeeId INTEGER NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY (employeeId) REFERENCES employees (id) ON DELETE CASCADE,
          UNIQUE (employeeId, date)
        )
      ''');
      await db.execute('''
        INSERT INTO attendance_new (id, employeeId, date, status)
        SELECT id, employeeId, date, status FROM attendance
        WHERE status IS NOT NULL
      ''');
      await db.execute('DROP TABLE attendance');
      await db.execute('ALTER TABLE attendance_new RENAME TO attendance');
    }
    if (oldVersion < 5) {
      await _createBonusesTable(db);
    }
  }

  Future<void> _createAdvancesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS advances(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (employeeId) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createBonusesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bonuses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (employeeId) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Employee CRUD (unchanged) ---

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

  // --- Attendance (status-based: present / absent / holiday) ---

  Future<void> markAttendance(Attendance attendance) async {
    final db = await database;
    await db.insert(
      'attendance',
      {
        'employeeId': attendance.employeeId,
        'date': attendance.date,
        'status': attendance.status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Attendance>> getAttendanceForDate(String date) async {
    final db = await database;
    final maps = await db.query('attendance', where: 'date = ?', whereArgs: [date]);
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

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

  // --- Advances ---

  Future<int> insertAdvance(Advance advance) async {
    final db = await database;
    return await db.insert('advances', advance.toMap()..remove('id'));
  }

  Future<List<Advance>> getAdvancesForEmployeeInRange(
    int employeeId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'advances',
      where: 'employeeId = ? AND date >= ? AND date <= ?',
      whereArgs: [employeeId, startDate, endDate],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Advance.fromMap(map)).toList();
  }

  Future<int> deleteAdvance(int id) async {
    final db = await database;
    return await db.delete('advances', where: 'id = ?', whereArgs: [id]);
  }

  // --- Bonuses ---

  Future<int> insertBonus(Bonus bonus) async {
    final db = await database;
    return await db.insert('bonuses', bonus.toMap()..remove('id'));
  }

  Future<List<Bonus>> getBonusesForEmployeeInRange(
    int employeeId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'bonuses',
      where: 'employeeId = ? AND date >= ? AND date <= ?',
      whereArgs: [employeeId, startDate, endDate],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Bonus.fromMap(map)).toList();
  }

  Future<int> deleteBonus(int id) async {
    final db = await database;
    return await db.delete('bonuses', where: 'id = ?', whereArgs: [id]);
  }
}