import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migration_manager.dart';
import 'migration_set.dart';

/// SQLite file database management functionality.
class SQLiteStore {
  final Logger _log = new Logger('DBService');

  /// Create a new SQLite instance based on [filename],
  /// which is stored under [databaseFactoryFfi.getDatabasesPath()].
  /// While opening is is made sure all provided [migrationSteps] are executed
  /// so that the database has the latest, provided in the list of migrations.
  SQLiteStore(String filename, Iterable<MigrationStep> migrationSteps)
      : _filename = filename,
        _migrationSets = migrationSteps.toList() {
    sqfliteFfiInit();
  }

  final List<MigrationStep> _migrationSets;
  final String _filename;
  late String _filePath;

  Database get database => _database;
  late Database _database;

  Future<void> openAsync() async {
    //
    // compile current database filename
    //
    /*
      A SQLite database is a file in the file system identified by a path. 
      If relative, this path is relative to the path obtained by getDatabasesPath(), 
      which is the default database directory on Android and the documents directory on iOS.
     */
    String databasesPath;
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory
      databaseFactory = databaseFactoryFfi;
      databasesPath = (await getApplicationDocumentsDirectory()).path;
    } else {
      databasesPath = await getDatabasesPath();
    }

    
    _filePath = join(databasesPath, _filename);
    _log.info('Database filepath: $_filePath');

    //
    // if database does not yet exist in database directory
    // either there is an old one or it has to be created
    //
    bool exists = await databaseFactory.databaseExists(_filePath);
    if (!exists) {
      Directory appDir = await getApplicationDocumentsDirectory();
      var oldFile = File(join(appDir.path, _filename));
      // an old file exists,
      // close/flush database (WAL) and move to new location
      if (await oldFile.exists()) {
        Database oldDB = await databaseFactoryFfi.openDatabase(oldFile.path);
        await oldDB.close();
        await oldFile.rename(_filePath);
      }
    }

    _migrationSets.sort((a, b) => a.targetVersion.compareTo(b.targetVersion));
    int requiredVersion = _migrationSets.last.targetVersion;

    _log.info('Open database from file $_filePath');

    _database = await databaseFactoryFfi.openDatabase(_filePath,
        options: new OpenDatabaseOptions(
            version: requiredVersion,
            onCreate: (db, newVersion) async {
              var migrationManager = new MigrationManager(db, _migrationSets);
              await migrationManager.upgradeDatabaseAsync(0, newVersion);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              var migrationManager = new MigrationManager(db, _migrationSets);
              await migrationManager.upgradeDatabaseAsync(oldVersion, newVersion);
            },
            onConfigure: (Database db) async {
 
            }));

    var v = await _database.getVersion();
    _log.info('Current Database Version $v');
    assert(v == requiredVersion, "Unexpected DB version $v");
  }

  Future<String> saveToFile(String filename) async {
    if (_database.isOpen) await _database.close();

    File srcFile = new File(_filePath);
    String databasesPath = await getDatabasesPath();
    String backupFilePath = join(databasesPath, filename);
    await srcFile.copy(backupFilePath);
    await openAsync();
    _log.finest('DB is open = ${_database.isOpen}');
    return backupFilePath;
  }

  void close() {
    _log.info('Shutting down database.');
    _database.close();
  }

  void dispose() => close();
}
