import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const scannedPOType = 'scanned_po';
const inputPOType = 'input_po';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'po_database.db');
    print('Database path: $path'); // Debugging line
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        print('Creating database...'); // Debugging line
        await _onCreate(db, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print(
            'Upgrading database from version $oldVersion to $newVersion'); // Debugging line
        await _onUpgrade(db, oldVersion, newVersion);
      },
      onOpen: (db) async {
        print('Opening database...'); // Debugging line
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      print('Executing CREATE TABLE statement...'); // Debugging line
      await db.execute(
        '''
        CREATE TABLE po(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pono TEXT,
          item_sku TEXT,
          item_name TEXT,
          qty_po INTEGER,
          qty_scanned INTEGER,
          qty_different INTEGER,
          barcode TEXT,
          scandate TEXT,
          device_name TEXT,
          type TEXT
        )
        ''',
      );
      await db.execute(
        '''
        CREATE TABLE scanned_results(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pono TEXT,
          item_sku TEXT,
          item_name TEXT,
          barcode TEXT,
          qty_po INTEGER,
          qty_scanned INTEGER,
          qty_different INTEGER,
          user TEXT,
          device_name TEXT,
          scandate TEXT,
          qty_koli TEXT,
          type TEXT,
          status TEXT
        )
        ''',
      );
    } catch (e) {
      print('Error creating tables: $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await db.execute(
          '''
          ALTER TABLE scanned_results ADD COLUMN scandate TEXT;
          ALTER TABLE scanned_results ADD COLUMN qty_koli TEXT;
          ''',
        );
      }
    } catch (e) {
      print('Error upgrading database: $e');
    }
  }

  Future<int> insertScannedResult(Map<String, dynamic> scannedData) async {
    try {
      final db = await database;
      return await db.insert('scanned_results', scannedData);
    } catch (e) {
      print('Error inserting scanned result: $e');
      return -1; // Indicate an error occurred
    }
  }

  Future<List<Map<String, dynamic>>> getScannedResultsByPONumber(
      String poNumber) async {
    final db = await database;
    return await db.query(
      'scanned_results',
      where: 'pono = ?',
      whereArgs: [poNumber],
      orderBy: 'scandate DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getScannedPODetails(
      String poNumber) async {
    final db = await database;
    return await db.query(
      'scanned_results',
      where: 'pono = ? AND type = ?',
      whereArgs: [poNumber, scannedPOType],
    );
  }

  Future<bool> scannedPOExists(String poNumber, String barcode) async {
    final db = await database;
    final result = await db.query(
      'po',
      where: 'pono = ? AND barcode = ? AND type = ?',
      whereArgs: [poNumber, barcode, scannedPOType],
    );
    return result.isNotEmpty;
  }

  Future<bool> poScannedExists(
      String poNumber, String barcode, String scandate) async {
    final db = await database;
    final result = await db.query(
      'scanned_results',
      where: 'pono = ? AND barcode = ? AND type = ? AND scandate = ?',
      whereArgs: [poNumber, barcode, scannedPOType, scandate],
    );
    return result.isNotEmpty;
  }

  Future<void> insertOrUpdateScannedResults(Map<String, dynamic> poData) async {
  final db = await database;

  bool exists = await poScannedExists(
    poData['pono'], 
    poData['barcode'], 
    poData['scandate'],
  );
  
  poData["type"] = scannedPOType; // Ensure this variable is defined somewhere in your code

  if (exists) {
    await db.update(
      'scanned_results',
      poData,
      where: 'pono = ? AND barcode = ? AND type = ? AND scandate = ?',
      whereArgs: [
        poData['pono'],
        poData['barcode'],
        scannedPOType,
        poData['scandate'],
      ],
    );
    print('CEKK PO updated: ${poData['pono']} - Barcode: ${poData['barcode']} - Scandate: ${poData['scandate']}');
  } else {
    await db.insert('scanned_results', poData);
    print('CEKK PO inserted: ${poData['pono']} - Barcode: ${poData['barcode']} - Scandate: ${poData['scandate']}');
  }
}


  Future<void> clearScannedResults() async {
    final db = await database;
    await db.delete('scanned_results');
  }

  Future<int> insertPO(Map<String, dynamic> poData) async {
    final db = await database;
    poData["type"] = inputPOType;
    return await db.insert('po', poData);
  }

  Future<int> updatePO(Map<String, dynamic> poData) async {
    final db = await database;
    return await db.update(
      'po',
      poData,
      where: 'id = ? AND type = ?',
      whereArgs: [poData['id'], inputPOType],
    );
  }
  

  Future<void> printScannedResults() async {
    try {
      final db = await database;
      List<Map<String, dynamic>> results = await db.query('scanned_results');

      // Print each row for debugging
      if (results.isEmpty) {
        print('No scanned results found.');
      } else {
        print('Scanned Results:');
        for (var result in results) {
          print(result);
        }
      }
    } catch (e) {
      print('Error fetching scanned results: $e');
    }
  }

  Future<bool> poExists(String poNumber, String barcode) async {
    final db = await database;
    final result = await db.query(
      'po',
      where: 'pono = ? AND barcode = ? AND type = ?',
      whereArgs: [poNumber, barcode, inputPOType],
    );
    return result.isNotEmpty;
  }

  Future<void> insertOrUpdatePO(Map<String, dynamic> poData) async {
    final db = await database;

    bool exists = await poExists(poData['pono'], poData['barcode']);
    poData["type"] = inputPOType;
    if (exists) {
      await db.update(
        'po',
        poData,
        where: 'pono = ? AND barcode = ? AND type = ?',
        whereArgs: [poData['pono'], poData['barcode'], inputPOType],
      );
      print('PO updated: ${poData['pono']} - Barcode: ${poData['barcode']}');
    } else {
      await db.insert('po', poData);
      print('PO inserted: ${poData['pono']} - Barcode: ${poData['barcode']}');
    }
  }

  Future<List<Map<String, dynamic>>> getItemsByPONumber(String poNumber) async {
    final db = await database;
    return await db.query(
      'po',
      where: 'pono = ?',
      whereArgs: [poNumber],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPODetails(String poNumber) async {
    final db = await database;
    return await db.query(
      'po',
      where: 'pono = ? AND type = ?',
      whereArgs: [poNumber, inputPOType],
    );
  }

  Future<List<Map<String, dynamic>>> getPOScannedODetails(
      String poNumber) async {
    final db = await database;
    return await db.query(
      'scanned_results',
      where: 'pono = ?',
      whereArgs: [poNumber],
    );
  }

  Future<List<Map<String, dynamic>>> getPOResultScannedDetails(
      String poNumber) async {
    final poDetails = await getPOScannedODetails(poNumber);
    final resultScanned =
        poDetails.where((e) => e['status'] == 'scanned').toList();
    // print("CEK RESULT ${poDetails.length} SCANNED ${jsonEncode(poDetails)}\n ");
    // print("CEK RESULT SCANNED $resultScanned");
    return resultScanned;
  }

  Future<List<Map<String, dynamic>>> getPODifferentScannedDetails(
      String poNumber) async {
    final poDetails = await getPOScannedODetails(poNumber);
    final differentScanned =
        poDetails.where((e) => e['status'] == 'different').toList();
    print("CEK Different SCANNED $differentScanned");
    return differentScanned;
  }

  Future<List<Map<String, dynamic>>> getRecentPOs({int? limit}) async {
    final db = await database;
    final query =
        'SELECT * FROM po ORDER BY id DESC${limit != null ? ' LIMIT $limit' : ''}';
    return await db.rawQuery(query);
  }

  Future<void> clearPOs() async {
    final db = await database;
    await db.delete('po');
  }

  Future<bool> checkTableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
    return result.isNotEmpty;
  }

  Future<void> checkTable() async {
    bool exists = await checkTableExists('po');
    print('Table exists: $exists');
  }

  Future<void> deletePO(String poNumber) async {
    final db = await database;
    await db.delete(
      'po',
      where: 'pono = ? AND type = ?',
      whereArgs: [poNumber, inputPOType],
    );
  }

  Future<void>  deletePOResult(String poNumber, String scandate) async {
    final db = await database;
    await db.delete(
      'scanned_results',
      where: 'pono = ? AND scandate = ?',
      whereArgs: [poNumber, scandate],
    );
  }

  Future<void> deletePOScannedDifferentResult(String poNumber) async {
    final db = await database;
    await db.delete(
      'scanned_results',
      where: 'pono = ? AND type = ?',
      whereArgs: [poNumber, scannedPOType],
    );
  }

  Future<void> updatePOItem(
      String poNumber, String barcode, int qtyScanned, int qtyDifferent) async {
    final db = await database;
    await db.update(
      'po',
      {
        'qty_scanned': qtyScanned,
        'qty_different': qtyDifferent,
      },
      where: 'pono = ? AND barcode = ? AND type = ?',
      whereArgs: [poNumber, barcode, inputPOType],
    );
  }
}