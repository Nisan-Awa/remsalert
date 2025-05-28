import 'dart:convert'; // For utf8 encoding and json
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart'; // For SHA256
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart'; // For generating salts and IDs

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p_path; // Aliased to avoid conflicts
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

// --- Logger Instance ---
final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 70,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
);

// --- Constants for SharedPreferences & SecureStorage Keys ---
const String PREF_REMEMBER_ME_EMAIL_KEY = 'user_remember_me_email';
const String PREF_REMEMBER_ME_KEY = 'remember_me';
const String PREF_LOGGED_IN_KEY = 'logged_in';
const String PREF_CURRENT_USER_EMAIL_KEY = 'current_user_email'; // NEW
const String PREF_FIRST_NAME_KEY = 'user_firstName';
const String PREF_LAST_NAME_KEY = 'user_lastName';
const String PREF_PHONE_KEY = 'user_phone';
const String PREF_USER_ROLE_KEY = 'user_role';
const String SECURE_STORAGE_USER_AUTH_PREFIX = 'user_auth_data_';

// --- THEME CONSTANTS ---
const String PREF_THEME_MODE_KEY = 'app_theme_mode';

const MaterialColor primaryBlue = MaterialColor(0xFF1A237E, <int, Color>{
  50: Color(0xFFE8EAF6),
  100: Color(0xFFC5CAE9),
  200: Color(0xFF9FA8DA),
  300: Color(0xFF7986CB),
  400: Color(0xFF5C6BC0),
  500: Color(0xFF3F51B5),
  600: Color(0xFF3949AB),
  700: Color(0xFF303F9F),
  800: Color(0xFF283593),
  900: Color(0xFF1A237E),
});

const MaterialColor accentOrange = MaterialColor(0xFFFF6F00, <int, Color>{
  50: Color(0xFFFFF3E0),
  100: Color(0xFFFFE0B2),
  200: Color(0xFFFFCC80),
  300: Color(0xFFFFB74D),
  400: Color(0xFFFFA726),
  500: Color(0xFFFF9800),
  600: Color(0xFFFB8C00),
  700: Color(0xFFF57C00),
  800: Color(0xFFEF6C00),
  900: Color(0xFFE65100),
});

TextTheme _buildTextTheme(TextTheme base, Color textColor, Color headlineColor) {
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: 24.0,
      color: headlineColor,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 20.0,
      color: headlineColor,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16.0, color: textColor),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14.0, color: textColor.withOpacity(0.8)),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16.0),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12.0, color: textColor.withOpacity(0.6)),
  );
}

ThemeData get lightTheme {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: primaryBlue,
      accentColor: accentOrange,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryBlue.shade900,
      secondary: accentOrange.shade700,
      surface: Colors.grey.shade100,
      onSurface: Colors.black87,
      background: Colors.grey.shade100,
      onBackground: Colors.black87,
      tertiary: primaryBlue.shade600, // Added for variety
    ),
    textTheme: _buildTextTheme(base.textTheme, Colors.black87, primaryBlue.shade900),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryBlue.shade900,
      foregroundColor: Colors.white,
      elevation: 2.0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        textStyle: base.textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue.shade800,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryBlue.shade800, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red.shade700, width: 2.0),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      prefixIconColor: Colors.grey.shade600,
      contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
    ),
    cardTheme: CardTheme(
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.grey.shade100,
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return primaryBlue.shade700;
        return null;
      }),
      checkColor: MaterialStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    brightness: Brightness.light,
  );
}

ThemeData get darkTheme {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: primaryBlue,
      accentColor: accentOrange,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryBlue.shade300,
      secondary: accentOrange.shade300,
      surface: const Color(0xFF121212),
      onSurface: Colors.white.withOpacity(0.87),
      background: const Color(0xFF121212),
      onBackground: Colors.white.withOpacity(0.87),
      tertiary: primaryBlue.shade200, // Added for variety
    ),
    textTheme: _buildTextTheme(base.textTheme, Colors.white.withOpacity(0.87), primaryBlue.shade300),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade900,
      foregroundColor: Colors.white.withOpacity(0.87),
      elevation: 2.0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(color: Colors.white.withOpacity(0.87)),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue.shade500,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        textStyle: base.textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue.shade300,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: primaryBlue.shade300, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2.0),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade400),
      prefixIconColor: Colors.grey.shade500,
      contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
    ),
    cardTheme: CardTheme(
      elevation: 3.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.grey.shade800,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return primaryBlue.shade500;
        return Colors.grey.shade600;
      }),
      checkColor: MaterialStateProperty.all(Colors.black87),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    brightness: Brightness.dark,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryBlue.shade400,
      foregroundColor: Colors.white,
    ),
  );
}
// --- END OF THEME CONSTANTS ---

// --- DATABASE CONSTANTS ---
class DBConstants {
  static const String databaseName = 'rems_alert_app_v4.db'; // Incremented version for schema change
  static const int databaseVersion = 2; // Incremented version

  static const String tableEstates = 'estates';
  static const String colEstateId = 'id';
  static const String colEstateName = 'name';
  static const String colEstateAddress = 'address';
  static const String colEstateDescription = 'description';
  static const String colEstateDateAdded = 'dateAdded';
  static const String colEstateIsFeatured = 'isFeatured';
  static const String colEstateFeaturedDetailsJson = 'featuredDetailsJson';

  static const String tableProperties = 'properties';
  static const String colPropertyId = 'id';
  static const String colPropertyEstateId = 'estateId';
  static const String colPropertyName = 'name';
  static const String colPropertyType = 'type';
  static const String colPropertyAddress = 'address';
  static const String colPropertyStatus = 'status';
  static const String colPropertyOwnerId = 'ownerId';

  // New Table for Visitors
  static const String tableVisitors = 'visitors';
  static const String colVisitorId = 'id';
  static const String colVisitorPropertyId = 'propertyId';
  static const String colVisitorOwnerId = 'ownerId'; // User who registered the visitor
  static const String colVisitorName = 'visitorName';
  static const String colVisitorPhone = 'visitorPhone';
  static const String colVisitorAddressVisiting = 'addressVisiting';
  static const String colVisitorExpectedDate = 'expectedDate'; // YYYY-MM-DD
  static const String colVisitorExpectedTime = 'expectedTime'; // HH:MM
  static const String colVisitorGatePassCode = 'gatePassCode';
  static const String colVisitorStatus = 'status'; // Expected, Arrived, Departed
  static const String colVisitorDateAdded = 'dateAdded';
}

// --- Service: Secure Storage ---
class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> writeData(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      _logger.d('SecureStorage: Write $key');
    } catch (e) {
      _logger.e('SecureStorage: Error writing $key', error: e);
      throw Exception('Failed to write secure data');
    }
  }

  Future<String?> readData(String key) async {
    try {
      final d = await _storage.read(key: key);
      _logger.d('SecureStorage: Read $key -> ${d != null ? "data" : "null"}');
      return d;
    } catch (e) {
      _logger.e('SecureStorage: Error reading $key', error: e);
      return null;
    }
  }

  Future<void> deleteData(String key) async {
    try {
      await _storage.delete(key: key);
      _logger.i('SecureStorage: Deleted $key');
    } catch (e) {
      _logger.e('SecureStorage: Error deleting $key', error: e);
    }
  }

  Future<void> deleteAllData() async {
    try {
      await _storage.deleteAll();
      _logger.i('SecureStorage: All data deleted.');
    } catch (e) {
      _logger.e('SecureStorage: Error deleting all data', error: e);
    }
  }
}

// --- Service: Preferences Storage ---
class PreferencesService {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> setString(String key, String value) async {
    try {
      final p = await _prefs;
      await p.setString(key, value);
      _logger.d('Prefs: SetString $key');
    } catch (e) {
      _logger.e('Prefs: Error SetString $key', error: e);
    }
  }

  Future<String?> getString(String key) async {
    try {
      final p = await _prefs;
      final v = p.getString(key);
      _logger.d('Prefs: GetString $key -> $v');
      return v;
    } catch (e) {
      _logger.e('Prefs: Error GetString $key', error: e);
      return null;
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      final p = await _prefs;
      await p.setBool(key, value);
      _logger.d('Prefs: SetBool $key -> $value');
    } catch (e) {
      _logger.e('Prefs: Error SetBool $key', error: e);
    }
  }

  Future<bool?> getBool(String key) async {
    try {
      final p = await _prefs;
      final v = p.getBool(key);
      _logger.d('Prefs: GetBool $key -> $v');
      return v;
    } catch (e) {
      _logger.e('Prefs: Error GetBool $key', error: e);
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      final p = await _prefs;
      await p.remove(key);
      _logger.i('Prefs: Removed $key');
    } catch (e) {
      _logger.e('Prefs: Error removing $key', error: e);
    }
  }
}

// --- Service: Authentication ---
class AuthService {
  final SecureStorageService _secureStorageService = SecureStorageService();
  final PreferencesService _preferencesService = PreferencesService();
  final Uuid _uuid = const Uuid();

  String _hashPassword(String password, String salt) {
    final saltedPassword = utf8.encode(password + salt + "RemsAlertSalt!V2");
    final hashedPassword = sha256.convert(saltedPassword);
    return hashedPassword.toString();
  }

  String _generateSalt() {
    return _uuid.v4();
  }

  Future<bool> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String role = 'user',
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final existingUserData = await _secureStorageService.readData(
        '$SECURE_STORAGE_USER_AUTH_PREFIX$normalizedEmail',
      );
      if (existingUserData != null) {
        _logger.w('Auth: SignUp Fail - Exists: $normalizedEmail');
        return false;
      }
      final salt = _generateSalt();
      final hashedPassword = _hashPassword(password, salt);
      final userData = jsonEncode({
        'salt': salt,
        'hashedPassword': hashedPassword,
        'role': role,
        // Storing PII in secure storage is better, but for quick access on signup/login,
        // prefs are used for non-critical display data.
        // 'firstName': firstName.trim(),
        // 'lastName': lastName.trim(),
        // 'phone': phone?.trim(),
      });

      await _secureStorageService.writeData(
        '$SECURE_STORAGE_USER_AUTH_PREFIX$normalizedEmail',
        userData,
      );

      await _preferencesService.setString(PREF_FIRST_NAME_KEY, firstName.trim());
      await _preferencesService.setString(PREF_LAST_NAME_KEY, lastName.trim());
      if (phone != null && phone.isNotEmpty) {
        await _preferencesService.setString(PREF_PHONE_KEY, phone.trim());
      }
      // await _preferencesService.setString(PREF_USER_ROLE_KEY, role); // Set upon login

      _logger.i('Auth: SignUp OK: $normalizedEmail, Role: $role');
      return true;
    } catch (e, s) {
      _logger.e('Auth: SignUp Error for $email', error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final userDataString = await _secureStorageService.readData(
        '$SECURE_STORAGE_USER_AUTH_PREFIX$normalizedEmail',
      );
      if (userDataString == null) {
        _logger.w('Auth: SignIn Fail - Not found: $normalizedEmail');
        return false;
      }

      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      final salt = userData['salt'] as String?;
      final storedHashedPassword = userData['hashedPassword'] as String?;
      final role = userData['role'] as String? ?? 'user';

      if (salt == null || storedHashedPassword == null) {
        _logger.e('Auth: SignIn Fail - Corrupt data for $normalizedEmail');
        return false;
      }

      final enteredHashedPassword = _hashPassword(password, salt);

      if (enteredHashedPassword == storedHashedPassword) {
        await _preferencesService.setBool(PREF_LOGGED_IN_KEY, true);
        await _preferencesService.setBool(PREF_REMEMBER_ME_KEY, rememberMe);
        await _preferencesService.setString(PREF_CURRENT_USER_EMAIL_KEY, normalizedEmail); // Store current user email

        // First/Last name and phone are typically set during signup into Prefs.
        // If they were stored in secure_storage userData, you'd fetch and set them here.
        // Example:
        // final firstNameFromSecure = userData['firstName'] as String?;
        // if (firstNameFromSecure != null) await _preferencesService.setString(PREF_FIRST_NAME_KEY, firstNameFromSecure);


        await _preferencesService.setString(PREF_USER_ROLE_KEY, role);

        if (rememberMe) {
          await _preferencesService.setString(
            PREF_REMEMBER_ME_EMAIL_KEY,
            normalizedEmail,
          );
        } else {
          await _preferencesService.remove(PREF_REMEMBER_ME_EMAIL_KEY);
        }

        _logger.i('Auth: SignIn OK: $normalizedEmail, Role: $role');
        return true;
      } else {
        _logger.w('Auth: SignIn Fail - Pwd mismatch for $normalizedEmail');
        return false;
      }
    } catch (e, s) {
      _logger.e('Auth: SignIn Error for $email', error: e, stackTrace: s);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _preferencesService.setBool(PREF_LOGGED_IN_KEY, false);
      await _preferencesService.remove(PREF_CURRENT_USER_EMAIL_KEY);
      // Optionally clear other user-specific prefs:
      // await _preferencesService.remove(PREF_USER_ROLE_KEY);
      // await _preferencesService.remove(PREF_FIRST_NAME_KEY);
      // await _preferencesService.remove(PREF_LAST_NAME_KEY);
      // await _preferencesService.remove(PREF_PHONE_KEY);
      _logger.i('Auth: SignOut OK.');
    } catch (e, s) {
      _logger.e('Auth: SignOut Error', error: e, stackTrace: s);
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final loggedIn = (await _preferencesService.getBool(PREF_LOGGED_IN_KEY)) ?? false;
      _logger.d('Auth: isLoggedIn -> $loggedIn');
      return loggedIn;
    } catch (e) {
      _logger.e('Auth: Error checking login status', error: e);
      return false;
    }
  }

  Future<String?> getRememberedEmail() async { // For pre-filling email field
    try {
      final bool shouldRemember = (await _preferencesService.getBool(PREF_REMEMBER_ME_KEY)) ?? false;
      if (shouldRemember) {
        return _preferencesService.getString(PREF_REMEMBER_ME_EMAIL_KEY);
      }
      return null;
    } catch (e) {
      _logger.e('Auth: Error loading remembered email', error: e);
      return null;
    }
  }

  Future<String?> getCurrentUserEmail() async { // For getting current session's email
    try {
      return _preferencesService.getString(PREF_CURRENT_USER_EMAIL_KEY);
    } catch (e) {
      _logger.e('Auth: Error loading current user email', error: e);
      return null;
    }
  }


  Future<String?> getUserFirstName() async {
    try {
      return _preferencesService.getString(PREF_FIRST_NAME_KEY);
    } catch (e) {
      _logger.e('Auth: Error loading user first name', error: e);
      return null;
    }
  }

  Future<String?> getUserRole() async {
    try {
      return _preferencesService.getString(PREF_USER_ROLE_KEY);
    } catch (e) {
      _logger.e('Auth: Error loading user role', error: e);
      return null;
    }
  }
}

// --- Database Helper ---
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  final Uuid _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p_path.join(documentsDirectory.path, DBConstants.databaseName);
    _logger.i('DB Path: $path');
    return await openDatabase(
      path,
      version: DBConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB, // Added for schema migration
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${DBConstants.tableEstates} (
        ${DBConstants.colEstateId} TEXT PRIMARY KEY,
        ${DBConstants.colEstateName} TEXT NOT NULL,
        ${DBConstants.colEstateAddress} TEXT,
        ${DBConstants.colEstateDescription} TEXT,
        ${DBConstants.colEstateDateAdded} TEXT NOT NULL,
        ${DBConstants.colEstateIsFeatured} INTEGER DEFAULT 0,
        ${DBConstants.colEstateFeaturedDetailsJson} TEXT
      )
    ''');
    _logger.i('DB: Created table ${DBConstants.tableEstates}');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableProperties} (
        ${DBConstants.colPropertyId} TEXT PRIMARY KEY,
        ${DBConstants.colPropertyEstateId} TEXT NOT NULL,
        ${DBConstants.colPropertyName} TEXT NOT NULL,
        ${DBConstants.colPropertyType} TEXT,
        ${DBConstants.colPropertyAddress} TEXT,
        ${DBConstants.colPropertyStatus} TEXT,
        ${DBConstants.colPropertyOwnerId} TEXT,
        FOREIGN KEY (${DBConstants.colPropertyEstateId}) REFERENCES ${DBConstants.tableEstates} (${DBConstants.colEstateId}) ON DELETE CASCADE
      )
    ''');
    _logger.i('DB: Created table ${DBConstants.tableProperties}');

    // Create Visitors Table (new for v2)
    await _createVisitorsTable(db);

    await _seedDiamondCityData(db);
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    _logger.i("DB: Upgrading from version $oldVersion to $newVersion");
    if (oldVersion < 2) {
      // If upgrading from a version before visitors table existed
      await _createVisitorsTable(db);
      _logger.i("DB: Upgraded to version 2 - added visitors table.");
    }
    // Add more upgrade steps here for future versions
    // if (oldVersion < 3) { ... }
  }

  Future<void> _createVisitorsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DBConstants.tableVisitors} (
        ${DBConstants.colVisitorId} TEXT PRIMARY KEY,
        ${DBConstants.colVisitorPropertyId} TEXT NOT NULL,
        ${DBConstants.colVisitorOwnerId} TEXT,
        ${DBConstants.colVisitorName} TEXT NOT NULL,
        ${DBConstants.colVisitorPhone} TEXT,
        ${DBConstants.colVisitorAddressVisiting} TEXT,
        ${DBConstants.colVisitorExpectedDate} TEXT NOT NULL,
        ${DBConstants.colVisitorExpectedTime} TEXT NOT NULL,
        ${DBConstants.colVisitorGatePassCode} TEXT,
        ${DBConstants.colVisitorStatus} TEXT DEFAULT 'Expected',
        ${DBConstants.colVisitorDateAdded} TEXT NOT NULL,
        FOREIGN KEY (${DBConstants.colVisitorPropertyId}) REFERENCES ${DBConstants.tableProperties} (${DBConstants.colPropertyId}) ON DELETE CASCADE
      )
    ''');
    _logger.i('DB: Created/Ensured table ${DBConstants.tableVisitors}');
  }


  Future<void> _seedDiamondCityData(Database db) async {
    const diamondCityName = "DIAMOND CITY GROUP LTD";
    final existing = await db.query(
      DBConstants.tableEstates,
      where: '${DBConstants.colEstateName} = ?',
      whereArgs: [diamondCityName],
    );

    if (existing.isEmpty) {
      final diamondCityId = _uuid.v4();
      final featuredDetails = {
        "company_profile":
        "DIAMOND CITY GROUP LTD is a property development company based in Abuja, Nigeria, specializing in the design, construction, and management of modern residential and commercial properties. Our mission is to create sustainable communities with high-quality infrastructure and a focus on customer satisfaction.",
        "property_types": [
          {"name": "THREE BEDROOM TERRACE DUPLEX WITH BQ", "beds": 4, "baths": 4, "sqm": 250},
          {"name": "FOUR BEDROOM SEMI-DETACHED DUPLEX WITH BQ", "beds": 5, "baths": 5, "sqm": 300},
          {"name": "FIVE BEDROOM FULLY DETACHED DUPLEX WITH BQ", "beds": 6, "baths": 6, "sqm": 380},
        ],
      };
      await db.insert(DBConstants.tableEstates, {
        DBConstants.colEstateId: diamondCityId,
        DBConstants.colEstateName: diamondCityName,
        DBConstants.colEstateAddress: "Abuja, Nigeria",
        DBConstants.colEstateDescription: "Premier Property Development.",
        DBConstants.colEstateDateAdded: DateTime.now().toIso8601String(),
        DBConstants.colEstateIsFeatured: 1,
        DBConstants.colEstateFeaturedDetailsJson: jsonEncode(featuredDetails),
      });
      _logger.i('DB: Seeded $diamondCityName Estate.');

      // Seed properties for Diamond City (Optional)
      await db.insert(DBConstants.tableProperties, Property(estateId: diamondCityId, name: "Terrace Duplex Unit 101", type: "Terrace Duplex", address: "101 Diamond Avenue", status: "Vacant").toMap());
      await db.insert(DBConstants.tableProperties, Property(estateId: diamondCityId, name: "Semi-Detached Unit A2", type: "Semi-Detached Duplex", address: "A2 Crystal Close", status: "Occupied").toMap());
    } else {
      _logger.i('DB: $diamondCityName estate already exists, skipping seed.');
    }
  }

  // Estate Methods
  Future<String> insertEstate(Estate estate) async {
    final db = await database;
    final id = estate.id.isEmpty ? _uuid.v4() : estate.id;
    final newEstate = estate.copyWith(id: id, dateAdded: estate.dateAdded ?? DateTime.now());
    await db.insert(DBConstants.tableEstates, newEstate.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _logger.i('DB: Inserted Estate: ${newEstate.name} (ID: $id)');
    return id;
  }

  Future<List<Estate>> getEstates({bool? isFeatured}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (isFeatured != null) {
      maps = await db.query(DBConstants.tableEstates, where: '${DBConstants.colEstateIsFeatured} = ?', whereArgs: [isFeatured ? 1 : 0], orderBy: '${DBConstants.colEstateName} ASC');
    } else {
      maps = await db.query(DBConstants.tableEstates, orderBy: '${DBConstants.colEstateName} ASC');
    }
    return List.generate(maps.length, (i) => Estate.fromMap(maps[i]));
  }

  Future<int> updateEstate(Estate estate) async {
    final db = await database;
    _logger.i('DB: Updating Estate: ${estate.name}');
    return await db.update(DBConstants.tableEstates, estate.toMap(), where: '${DBConstants.colEstateId} = ?', whereArgs: [estate.id]);
  }

  Future<int> deleteEstate(String id) async {
    final db = await database;
    _logger.i('DB: Deleting Estate ID: $id');
    await db.delete(DBConstants.tableProperties, where: '${DBConstants.colPropertyEstateId} = ?', whereArgs: [id]); // Cascade delete properties
    // Cascade delete visitors related to properties of this estate indirectly
    // Get all property IDs for this estate
    List<Map<String,dynamic>> propertiesToDelete = await db.query(DBConstants.tableProperties, columns: [DBConstants.colPropertyId], where: '${DBConstants.colPropertyEstateId} = ?', whereArgs: [id]);
    for (var prop in propertiesToDelete) {
      await db.delete(DBConstants.tableVisitors, where: '${DBConstants.colVisitorPropertyId} = ?', whereArgs: [prop[DBConstants.colPropertyId]]);
    }
    return await db.delete(DBConstants.tableEstates, where: '${DBConstants.colEstateId} = ?', whereArgs: [id]);
  }

  Future<Estate?> getEstateById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBConstants.tableEstates,
      where: '${DBConstants.colEstateId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Estate.fromMap(maps.first);
    }
    return null;
  }

  // Property Methods
  Future<String> insertProperty(Property property) async {
    final db = await database;
    final id = property.id.isEmpty ? _uuid.v4() : property.id;
    final newProperty = property.copyWith(id: id);
    await db.insert(DBConstants.tableProperties, newProperty.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _logger.i('DB: Inserted Property: ${newProperty.name} for Estate ID: ${newProperty.estateId}');
    return id;
  }

  Future<List<Property>> getProperties([String? estateId]) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (estateId != null) {
      maps = await db.query(DBConstants.tableProperties, where: '${DBConstants.colPropertyEstateId} = ?', whereArgs: [estateId], orderBy: '${DBConstants.colPropertyName} ASC');
    } else {
      maps = await db.query(DBConstants.tableProperties, orderBy: '${DBConstants.colPropertyName} ASC');
    }
    return List.generate(maps.length, (i) => Property.fromMap(maps[i]));
  }

  Future<Property?> getPropertyById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBConstants.tableProperties,
      where: '${DBConstants.colPropertyId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Property.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateProperty(Property property) async {
    final db = await database;
    _logger.i('DB: Updating Property: ${property.name}');
    return await db.update(DBConstants.tableProperties, property.toMap(), where: '${DBConstants.colPropertyId} = ?', whereArgs: [property.id]);
  }

  Future<int> deleteProperty(String id) async {
    final db = await database;
    _logger.i('DB: Deleting Property ID: $id');
    await db.delete(DBConstants.tableVisitors, where: '${DBConstants.colVisitorPropertyId} = ?', whereArgs: [id]); // Cascade delete visitors
    return await db.delete(DBConstants.tableProperties, where: '${DBConstants.colPropertyId} = ?', whereArgs: [id]);
  }

  // Visitor Methods
  Future<String> insertVisitor(Visitor visitor) async {
    final db = await database;
    final id = visitor.id.isEmpty ? _uuid.v4() : visitor.id;
    // Ensure dateAdded is set if not provided, especially important for new records
    final newVisitor = visitor.copyWith(id: id, dateAdded: visitor.dateAdded);
    await db.insert(DBConstants.tableVisitors, newVisitor.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _logger.i('DB: Inserted Visitor: ${newVisitor.visitorName} for Property ID: ${newVisitor.propertyId}');
    return id;
  }

  Future<List<Visitor>> getVisitorsForProperty(String propertyId, {String? statusFilter}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    String whereClause = '${DBConstants.colVisitorPropertyId} = ?';
    List<dynamic> whereArgs = [propertyId];

    if (statusFilter != null && statusFilter.isNotEmpty) {
      whereClause += ' AND ${DBConstants.colVisitorStatus} = ?';
      whereArgs.add(statusFilter);
    }

    maps = await db.query(
      DBConstants.tableVisitors,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: '${DBConstants.colVisitorExpectedDate} DESC, ${DBConstants.colVisitorExpectedTime} DESC',
    );
    return List.generate(maps.length, (i) => Visitor.fromMap(maps[i]));
  }

  Future<Visitor?> getVisitorById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBConstants.tableVisitors,
      where: '${DBConstants.colVisitorId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Visitor.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateVisitor(Visitor visitor) async {
    final db = await database;
    _logger.i('DB: Updating Visitor: ${visitor.visitorName}');
    return await db.update(
      DBConstants.tableVisitors,
      visitor.toMap(),
      where: '${DBConstants.colVisitorId} = ?',
      whereArgs: [visitor.id],
    );
  }

  Future<int> deleteVisitor(String id) async {
    final db = await database;
    _logger.i('DB: Deleting Visitor ID: $id');
    return await db.delete(
      DBConstants.tableVisitors,
      where: '${DBConstants.colVisitorId} = ?',
      whereArgs: [id],
    );
  }
}

// --- Data Models ---
class FeaturedPropertyType {
  final String name;
  final int beds;
  final int baths;
  final int sqm;

  FeaturedPropertyType({required this.name, required this.beds, required this.baths, required this.sqm});

  factory FeaturedPropertyType.fromMap(Map<String, dynamic> map) {
    return FeaturedPropertyType(
      name: map['name'] as String? ?? 'Unknown Type',
      beds: map['beds'] as int? ?? 0,
      baths: map['baths'] as int? ?? 0,
      sqm: map['sqm'] as int? ?? 0,
    );
  }
  Map<String, dynamic> toMap() => {'name': name, 'beds': beds, 'baths': baths, 'sqm': sqm};
}

class Estate {
  final String id;
  final String name;
  final String? address;
  final String? description;
  final DateTime? dateAdded;
  final bool isFeatured;
  final String? companyProfile;
  final List<FeaturedPropertyType> propertyTypesOffered;

  Estate({
    String? id,
    required this.name,
    this.address,
    this.description,
    this.dateAdded,
    this.isFeatured = false,
    this.companyProfile,
    this.propertyTypesOffered = const [],
  }) : id = id ?? const Uuid().v4();

  Estate copyWith({
    String? id, String? name, String? address, String? description, DateTime? dateAdded,
    bool? isFeatured, String? companyProfile, List<FeaturedPropertyType>? propertyTypesOffered,
  }) {
    return Estate(
      id: id ?? this.id, name: name ?? this.name, address: address ?? this.address,
      description: description ?? this.description, dateAdded: dateAdded ?? this.dateAdded,
      isFeatured: isFeatured ?? this.isFeatured, companyProfile: companyProfile ?? this.companyProfile,
      propertyTypesOffered: propertyTypesOffered ?? this.propertyTypesOffered,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      DBConstants.colEstateId: id, DBConstants.colEstateName: name, DBConstants.colEstateAddress: address,
      DBConstants.colEstateDescription: description, DBConstants.colEstateDateAdded: (dateAdded ?? DateTime.now()).toIso8601String(),
      DBConstants.colEstateIsFeatured: isFeatured ? 1 : 0,
    };
    if (isFeatured && (companyProfile != null || propertyTypesOffered.isNotEmpty)) {
      map[DBConstants.colEstateFeaturedDetailsJson] = jsonEncode({
        'company_profile': companyProfile,
        'property_types': propertyTypesOffered.map((pt) => pt.toMap()).toList(),
      });
    }
    return map;
  }

  factory Estate.fromMap(Map<String, dynamic> map) {
    bool isFeatured = (map[DBConstants.colEstateIsFeatured] as int? ?? 0) == 1;
    String? companyProfile;
    List<FeaturedPropertyType> propertyTypes = [];
    if (isFeatured && map[DBConstants.colEstateFeaturedDetailsJson] != null) {
      try {
        final details = jsonDecode(map[DBConstants.colEstateFeaturedDetailsJson] as String) as Map<String, dynamic>;
        companyProfile = details['company_profile'] as String?;
        if (details['property_types'] != null && details['property_types'] is List) {
          propertyTypes = (details['property_types'] as List)
              .map((ptMap) => FeaturedPropertyType.fromMap(ptMap as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        _logger.e("Error parsing featuredDetailsJson for estate ${map[DBConstants.colEstateName]}", error: e);
      }
    }
    return Estate(
      id: map[DBConstants.colEstateId] as String, name: map[DBConstants.colEstateName] as String,
      address: map[DBConstants.colEstateAddress] as String?, description: map[DBConstants.colEstateDescription] as String?,
      dateAdded: map[DBConstants.colEstateDateAdded] != null ? DateTime.tryParse(map[DBConstants.colEstateDateAdded] as String) : null,
      isFeatured: isFeatured, companyProfile: companyProfile, propertyTypesOffered: propertyTypes,
    );
  }
}

class Property {
  final String id;
  final String estateId;
  final String name;
  final String? type;
  final String? address;
  final String? status;
  final String? ownerId; // ID of the user who owns this property

  Property({
    String? id, required this.estateId, required this.name, this.type,
    this.address, this.status, this.ownerId,
  }) : id = id ?? const Uuid().v4();

  Property copyWith({
    String? id, String? estateId, String? name, String? type, String? address, String? status, String? ownerId,
  }) {
    return Property(
      id: id ?? this.id, estateId: estateId ?? this.estateId, name: name ?? this.name, type: type ?? this.type,
      address: address ?? this.address, status: status ?? this.status, ownerId: ownerId ?? this.ownerId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DBConstants.colPropertyId: id, DBConstants.colPropertyEstateId: estateId, DBConstants.colPropertyName: name,
      DBConstants.colPropertyType: type, DBConstants.colPropertyAddress: address, DBConstants.colPropertyStatus: status,
      DBConstants.colPropertyOwnerId: ownerId,
    };
  }

  factory Property.fromMap(Map<String, dynamic> map) {
    return Property(
      id: map[DBConstants.colPropertyId] as String, estateId: map[DBConstants.colPropertyEstateId] as String,
      name: map[DBConstants.colPropertyName] as String, type: map[DBConstants.colPropertyType] as String?,
      address: map[DBConstants.colPropertyAddress] as String?, status: map[DBConstants.colPropertyStatus] as String?,
      ownerId: map[DBConstants.colPropertyOwnerId] as String?,
    );
  }
}

class Visitor {
  final String id;
  final String propertyId;
  final String? ownerId; // Email of the user who registered the visitor
  final String visitorName;
  final String visitorPhone;
  final String addressVisiting;
  final DateTime expectedDate;
  final TimeOfDay expectedTime;
  final String? gatePassCode;
  final String status; // e.g., "Expected", "Arrived", "Departed"
  final DateTime dateAdded;

  Visitor({
    String? id,
    required this.propertyId,
    this.ownerId,
    required this.visitorName,
    required this.visitorPhone,
    required this.addressVisiting,
    required this.expectedDate,
    required this.expectedTime,
    this.gatePassCode,
    this.status = "Expected",
    DateTime? dateAdded,
  }) : id = id ?? const Uuid().v4(),
        dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      DBConstants.colVisitorId: id,
      DBConstants.colVisitorPropertyId: propertyId,
      DBConstants.colVisitorOwnerId: ownerId,
      DBConstants.colVisitorName: visitorName,
      DBConstants.colVisitorPhone: visitorPhone,
      DBConstants.colVisitorAddressVisiting: addressVisiting,
      DBConstants.colVisitorExpectedDate: DateFormat('yyyy-MM-dd').format(expectedDate), // Store YYYY-MM-DD
      DBConstants.colVisitorExpectedTime: '${expectedTime.hour.toString().padLeft(2, '0')}:${expectedTime.minute.toString().padLeft(2, '0')}', // Store HH:MM
      DBConstants.colVisitorGatePassCode: gatePassCode,
      DBConstants.colVisitorStatus: status,
      DBConstants.colVisitorDateAdded: dateAdded.toIso8601String(),
    };
  }

  factory Visitor.fromMap(Map<String, dynamic> map) {
    List<String> timeParts = (map[DBConstants.colVisitorExpectedTime] as String? ?? "00:00").split(':');
    return Visitor(
      id: map[DBConstants.colVisitorId] as String,
      propertyId: map[DBConstants.colVisitorPropertyId] as String,
      ownerId: map[DBConstants.colVisitorOwnerId] as String?,
      visitorName: map[DBConstants.colVisitorName] as String,
      visitorPhone: map[DBConstants.colVisitorPhone] as String,
      addressVisiting: map[DBConstants.colVisitorAddressVisiting] as String,
      expectedDate: DateTime.parse(map[DBConstants.colVisitorExpectedDate] as String),
      expectedTime: TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
      gatePassCode: map[DBConstants.colVisitorGatePassCode] as String?,
      status: map[DBConstants.colVisitorStatus] as String? ?? "Expected",
      dateAdded: DateTime.parse(map[DBConstants.colVisitorDateAdded] as String),
    );
  }

  Visitor copyWith({
    String? id,
    String? propertyId,
    String? ownerId,
    String? visitorName,
    String? visitorPhone,
    String? addressVisiting,
    DateTime? expectedDate,
    TimeOfDay? expectedTime,
    String? gatePassCode,
    String? status,
    DateTime? dateAdded,
  }) {
    return Visitor(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      ownerId: ownerId ?? this.ownerId,
      visitorName: visitorName ?? this.visitorName,
      visitorPhone: visitorPhone ?? this.visitorPhone,
      addressVisiting: addressVisiting ?? this.addressVisiting,
      expectedDate: expectedDate ?? this.expectedDate,
      expectedTime: expectedTime ?? this.expectedTime,
      gatePassCode: gatePassCode ?? this.gatePassCode,
      status: status ?? this.status,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }
}

// --- THEME PROVIDER ---
class ThemeProvider extends ChangeNotifier {
  final PreferencesService _preferencesService;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider(this._preferencesService) {
    loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    try {
      final themeString = await _preferencesService.getString(PREF_THEME_MODE_KEY);
      if (themeString != null) {
        if (themeString == 'light') _themeMode = ThemeMode.light;
        else if (themeString == 'dark') _themeMode = ThemeMode.dark;
        else _themeMode = ThemeMode.system;
      }
      _logger.i("ThemeProvider: Loaded theme mode - $_themeMode");
    } catch (e) {
      _logger.e("ThemeProvider: Error loading theme", error: e);
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    try {
      String themeString;
      if (mode == ThemeMode.light) themeString = 'light';
      else if (mode == ThemeMode.dark) themeString = 'dark';
      else themeString = 'system';
      await _preferencesService.setString(PREF_THEME_MODE_KEY, themeString);
      _logger.i("ThemeProvider: Set theme mode to $themeString");
    } catch (e) {
      _logger.e("ThemeProvider: Error saving theme", error: e);
    }
    notifyListeners();
  }
}

// --- ChangeNotifier Providers ---
class EstateProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<Estate> _estates = [];
  List<Estate> _featuredEstates = [];
  bool _isLoading = false;

  EstateProvider(this._dbHelper) { fetchEstates(); }
  List<Estate> get estates => _estates;
  List<Estate> get featuredEstates => _featuredEstates;
  bool get isLoading => _isLoading;
  int get estateCount => _estates.length;

  Future<void> fetchEstates() async {
    _isLoading = true; notifyListeners();
    try {
      _estates = await _dbHelper.getEstates();
      _featuredEstates = await _dbHelper.getEstates(isFeatured: true);
      _logger.i('EstateProvider: Fetched ${_estates.length} estates, ${_featuredEstates.length} featured.');
    } catch (e) {
      _logger.e("EstateProvider: Error fetching estates", error: e);
      _estates = []; _featuredEstates = [];
    }
    _isLoading = false; notifyListeners();
  }

  Future<void> addEstate(Estate estate) async {
    _isLoading = true; notifyListeners();
    try { await _dbHelper.insertEstate(estate); await fetchEstates(); }
    catch (e) { _logger.e("EstateProvider: Error adding estate", error: e); _isLoading = false; notifyListeners(); rethrow;}
  }
  Future<void> updateEstate(Estate estate) async {
    _isLoading = true; notifyListeners();
    try { await _dbHelper.updateEstate(estate); await fetchEstates(); }
    catch (e) { _logger.e("EstateProvider: Error updating estate", error: e); _isLoading = false; notifyListeners(); rethrow;}
  }
  Future<void> deleteEstate(String id) async {
    _isLoading = true; notifyListeners();
    try { await _dbHelper.deleteEstate(id); await fetchEstates(); }
    catch (e) { _logger.e("EstateProvider: Error deleting estate", error: e); _isLoading = false; notifyListeners(); rethrow;}
  }
  Future<Estate?> getEstateById(String id) async => _dbHelper.getEstateById(id);
}

class PropertyProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<Property> _properties = [];
  bool _isLoading = false;
  String? _currentEstateIdFilter;

  PropertyProvider(this._dbHelper) { fetchProperties(); } // Fetch all initially
  List<Property> get properties => _properties;
  bool get isLoading => _isLoading;
  int get propertyCount => _properties.length;

  Future<void> fetchProperties([String? estateId]) async {
    _isLoading = true; _currentEstateIdFilter = estateId; notifyListeners();
    try {
      _properties = await _dbHelper.getProperties(estateId);
      _logger.i('PropertyProvider: Fetched ${_properties.length} properties ${estateId != null ? "for estate $estateId" : "(all)"}.');
    } catch (e) {
      _logger.e("PropertyProvider: Error fetching properties", error: e); _properties = [];
    }
    _isLoading = false; notifyListeners();
  }
  Future<void> addProperty(Property property) async {
    _isLoading = true; notifyListeners();
    try { await _dbHelper.insertProperty(property); await fetchProperties(_currentEstateIdFilter); }
    catch (e) { _logger.e("PropertyProvider: Error adding property", error: e); _isLoading = false; notifyListeners(); rethrow;}
  }
  Future<void> updateProperty(Property property) async {
    _isLoading = true; notifyListeners();
    try { await _dbHelper.updateProperty(property); await fetchProperties(_currentEstateIdFilter); }
    catch (e) { _logger.e("PropertyProvider: Error updating property", error: e); _isLoading = false; notifyListeners(); rethrow;}
  }
  Future<void> deleteProperty(String id) async {
    _isLoading = true; notifyListeners();
    try { await _dbHelper.deleteProperty(id); await fetchProperties(_currentEstateIdFilter); }
    catch (e) { _logger.e("PropertyProvider: Error deleting property", error: e); _isLoading = false; notifyListeners(); rethrow;}
  }
  Future<Property?> getPropertyById(String id) async => _dbHelper.getPropertyById(id);
}

class VisitorProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<Visitor> _visitors = [];
  bool _isLoading = false;
  String? _currentPropertyIdFilter;

  VisitorProvider(this._dbHelper);

  List<Visitor> get visitors => _visitors;
  bool get isLoading => _isLoading;

  Future<void> fetchVisitors(String propertyId, {String? statusFilter}) async {
    _isLoading = true;
    _currentPropertyIdFilter = propertyId;
    notifyListeners();
    try {
      _visitors = await _dbHelper.getVisitorsForProperty(propertyId, statusFilter: statusFilter);
      _logger.i('VisitorProvider: Fetched ${_visitors.length} visitors for property $propertyId.');
    } catch (e) {
      _logger.e("VisitorProvider: Error fetching visitors", error: e);
      _visitors = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addVisitor(Visitor visitor) async {
    try {
      final random = Random();
      final gatePassCode = List.generate(6, (_) => random.nextInt(10)).join();
      final visitorWithCode = visitor.copyWith(gatePassCode: gatePassCode);

      await _dbHelper.insertVisitor(visitorWithCode);
      if (_currentPropertyIdFilter != null && _currentPropertyIdFilter == visitor.propertyId) {
        await fetchVisitors(_currentPropertyIdFilter!);
      }
    } catch (e) {
      _logger.e("VisitorProvider: Error adding visitor", error: e);
      rethrow;
    }
  }

  Future<void> updateVisitor(Visitor visitor) async {
    try {
      await _dbHelper.updateVisitor(visitor);
      if (_currentPropertyIdFilter != null && _currentPropertyIdFilter == visitor.propertyId) {
        await fetchVisitors(_currentPropertyIdFilter!);
      }
    } catch (e) {
      _logger.e("VisitorProvider: Error updating visitor", error: e);
      rethrow;
    }
  }

  Future<void> deleteVisitor(String visitorId, String propertyId) async {
    try {
      await _dbHelper.deleteVisitor(visitorId);
      if (_currentPropertyIdFilter != null && _currentPropertyIdFilter == propertyId) {
        await fetchVisitors(_currentPropertyIdFilter!);
      }
    } catch (e) {
      _logger.e("VisitorProvider: Error deleting visitor", error: e);
      rethrow;
    }
  }
  Future<Visitor?> getVisitorById(String id) async => _dbHelper.getVisitorById(id);
}


// --- Function to seed admin user ---
Future<void> _seedAdminUserIfNotFound(AuthService authService) async {
  const adminEmail = 'infodiamondcities@gmail.com';
  final secureStorage = SecureStorageService();
  final existingUserData = await secureStorage.readData('$SECURE_STORAGE_USER_AUTH_PREFIX$adminEmail');

  if (existingUserData == null) {
    _logger.i('Admin user $adminEmail not found. Seeding...');
    final success = await authService.signUp(
      firstName: 'Diamond', lastName: 'City Admin', email: adminEmail,
      password: 'DiamondAdmin123!', phone: '08093335558', role: 'admin',
    );
    if (success) _logger.i('Admin user $adminEmail seeded successfully.');
    else _logger.e('Failed to seed admin user $adminEmail.');
  } else {
    _logger.i('Admin user $adminEmail already exists. Skipping seed.');
  }
}

// --- App Entry Point ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  final dbHelper = DatabaseHelper();
  await dbHelper.database; // Ensures DB is initialized and migration (if any) runs
  _logger.i("DB initialized in main.");

  final authService = AuthService();
  final preferencesService = PreferencesService();

  await _seedAdminUserIfNotFound(authService);

  final themeProvider = ThemeProvider(preferencesService);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(create: (_) => EstateProvider(dbHelper)),
        ChangeNotifierProvider(create: (_) => PropertyProvider(dbHelper)),
        ChangeNotifierProvider(create: (_) => VisitorProvider(dbHelper)), // Added VisitorProvider
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

// --- Root Application Widget ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'RemsAlert',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/signIn': (context) => const SignInScreen(),
        '/signUp': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/manageEstates': (context) => const ManageEstatesScreen(),
        '/addEditEstate': (context) => const AddEditEstateScreen(),
        '/manageProperties': (context) => const ManagePropertiesScreen(),
        '/addEditProperty': (context) => const AddEditPropertyScreen(),
        '/propertyVisitors': (context) => const PropertyVisitorsScreen(), // New Route
        '/addEditVisitor': (context) => const AddEditVisitorScreen(),   // New Route
        '/manageStaff': (context) => const ManageStaffScreen(),
        '/assignTasks': (context) => const AssignTasksScreen(),
        '/viewAnalytics': (context) => const ViewAnalyticsScreen(),
        '/manageOwners': (context) => const ManageOwnersScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// --- Authentication Wrapper ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}
class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool>? _checkLoginStatusFuture;
  @override
  void initState() { super.initState(); _checkLoginStatusFuture = _initAuthCheck(); }
  Future<bool> _initAuthCheck() async {
    if (!mounted) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    return await authService.isLoggedIn();
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoginStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingIndicator(message: "Initializing..."));
        } else {
          if (snapshot.hasError) {
            _logger.e("AuthWrapper Error", error: snapshot.error, stackTrace: snapshot.stackTrace);
            return const WelcomeScreen();
          }
          return snapshot.data == true ? const HomeScreen() : const WelcomeScreen();
        }
      },
    );
  }
}

// --- Welcome Screen Widget ---
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.surface, colorScheme.primary.withOpacity(0.1)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FlutterLogo(size: 100, style: FlutterLogoStyle.stacked, textColor: colorScheme.primary),
                  const SizedBox(height: 40),
                  Text('Welcome to RemsAlert', style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  Text('Your Smart Estate Management Partner', style: textTheme.bodyLarge?.copyWith(color: textTheme.bodyMedium?.color), textAlign: TextAlign.center),
                  const Spacer(),
                  ElevatedButton.icon(icon: const Icon(Icons.login), label: const Text('Sign In'), onPressed: () => Navigator.pushNamed(context, '/signIn')),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1), label: const Text('Sign Up'),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.surface, foregroundColor: colorScheme.primary, side: BorderSide(color: colorScheme.primary)),
                    onPressed: () => Navigator.pushNamed(context, '/signUp'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Sign Up Screen Widget ---
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}
class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController, _lastNameController, _emailController, _phoneController, _passwordController, _confirmPasswordController;
  bool _isPasswordVisible = false, _isConfirmPasswordVisible = false, _isLoading = false;
  late FocusNode _lastNameFocus, _emailFocus, _phoneFocus, _passwordFocus, _confirmPasswordFocus;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(); _lastNameController = TextEditingController();
    _emailController = TextEditingController(); _phoneController = TextEditingController();
    _passwordController = TextEditingController(); _confirmPasswordController = TextEditingController();
    _lastNameFocus = FocusNode(); _emailFocus = FocusNode(); _phoneFocus = FocusNode();
    _passwordFocus = FocusNode(); _confirmPasswordFocus = FocusNode();
  }
  @override
  void dispose() {
    _firstNameController.dispose(); _lastNameController.dispose(); _emailController.dispose();
    _phoneController.dispose(); _passwordController.dispose(); _confirmPasswordController.dispose();
    _lastNameFocus.dispose(); _emailFocus.dispose(); _phoneFocus.dispose();
    _passwordFocus.dispose(); _confirmPasswordFocus.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Min 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Needs at least one lowercase';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Needs at least one uppercase';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Needs at least one number';
    return null;
  }

  Future<void> _submitSignUp() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final success = await authService.signUp(
        firstName: _firstNameController.text, lastName: _lastNameController.text,
        email: _emailController.text, password: _passwordController.text, phone: _phoneController.text,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign Up Successful! Please Sign In.'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        Navigator.pushReplacementNamed(context, '/signIn');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign Up Failed. Email may be in use or an error occurred.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    } catch (e,s) {
      _logger.e("SignUp Error", error: e, stackTrace: s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().substring(0, min(e.toString().length, 100))}'), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Join RemsAlert', style: textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text('Enter details below', style: textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 30),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person_outline)), textInputAction: TextInputAction.next, validator: (v) => v==null||v.isEmpty ? 'Required':null, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocus))),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(controller: _lastNameController, focusNode: _lastNameFocus, decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person_outline)), textInputAction: TextInputAction.next, validator: (v) => v==null||v.isEmpty ? 'Required':null, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus))),
                    ]),
                    const SizedBox(height: 15),
                    TextFormField(controller: _emailController, focusNode: _emailFocus, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: (v) { if (v==null||v.isEmpty) return 'Required'; if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Invalid email'; return null; }, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus)),
                    const SizedBox(height: 15),
                    TextFormField(controller: _phoneController, focusNode: _phoneFocus, decoration: const InputDecoration(labelText: 'Phone (Optional)', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus)),
                    const SizedBox(height: 15),
                    TextFormField(controller: _passwordController, focusNode: _passwordFocus, decoration: InputDecoration(labelText: 'Password', helperText: 'Min 8 chars, upper, lower, digit', helperMaxLines: 2, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible))), obscureText: !_isPasswordVisible, textInputAction: TextInputAction.next, validator: _validatePassword, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocus)),
                    const SizedBox(height: 15),
                    TextFormField(controller: _confirmPasswordController, focusNode: _confirmPasswordFocus, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible))), obscureText: !_isConfirmPasswordVisible, textInputAction: TextInputAction.done, validator: (v) { if (v==null||v.isEmpty) return 'Required'; if (v != _passwordController.text) return 'Passwords do not match'; return null; }, onFieldSubmitted: (_) { if (!_isLoading) _submitSignUp(); }),
                    const SizedBox(height: 30),
                    ElevatedButton(onPressed: _isLoading ? null : _submitSignUp, child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Create Account')),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("Already have an account?", style: textTheme.bodyMedium), TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Sign In'))]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Sign In Screen Widget ---
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}
class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController, _passwordController;
  bool _isPasswordVisible = false, _isLoading = false, _rememberMe = false;
  late FocusNode _passwordFocusNode;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(); _passwordController = TextEditingController();
    _passwordFocusNode = FocusNode();
    _loadRememberedCredentials();
  }
  Future<void> _loadRememberedCredentials() async {
    try {
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final rememberedEmail = await authService.getRememberedEmail();
      final shouldRemember = (await authService._preferencesService.getBool(PREF_REMEMBER_ME_KEY)) ?? false; // Direct access for init state
      if (mounted) setState(() { _rememberMe = shouldRemember; if (rememberedEmail != null) _emailController.text = rememberedEmail; });
    } catch (e) { _logger.e("SignInScreen: Error loading remembered credentials", error: e); }
  }
  @override
  void dispose() { _emailController.dispose(); _passwordController.dispose(); _passwordFocusNode.dispose(); super.dispose(); }

  Future<void> _submitSignIn() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final success = await authService.signIn(email: _emailController.text, password: _passwordController.text, rememberMe: _rememberMe);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign In Successful!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        Navigator.pushNamedAndRemoveUntil(context, '/home', (Route<dynamic> route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign In Failed. Incorrect email or password.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    } catch (e,s) {
      _logger.e("SignIn Error", error: e, stackTrace: s);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().substring(0, min(e.toString().length, 100))}'), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _navigateToSignUp() => Navigator.pushReplacementNamed(context, '/signUp');
  void _handleForgotPassword() {
    _logger.i("Forgot Password. Not implemented.");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forgot Password not implemented.'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Account Sign In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(child: FlutterLogo(size: 60, textColor: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 20),
                    Text('Sign In to RemsAlert', style: textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 25),
                    TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: (v) { if (v==null||v.isEmpty) return 'Required'; if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Invalid email'; return null; }, onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode)),
                    const SizedBox(height: 15),
                    TextFormField(controller: _passwordController, focusNode: _passwordFocusNode, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible))), obscureText: !_isPasswordVisible, textInputAction: TextInputAction.done, validator: (v) => v==null||v.isEmpty ? 'Required' : null, onFieldSubmitted: (_) { if (!_isLoading) _submitSignIn(); }),
                    const SizedBox(height: 5),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded(child: CheckboxListTile(title: const Text("Remember Me"), value: _rememberMe, onChanged: (bool? value) => setState(() => _rememberMe = value ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, dense: true)), TextButton(onPressed: _isLoading ? null : _handleForgotPassword, child: const Text('Forgot?'))]),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _isLoading ? null : _submitSignIn, child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Sign In')),
                    const SizedBox(height: 30),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("Don't have an account?", style: textTheme.bodyMedium), TextButton(onPressed: _isLoading ? null : _navigateToSignUp, child: const Text('Sign Up Here'))]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  String? _userRole;

  @override
  void initState() { super.initState(); _loadUserProfile(); }
  Future<void> _loadUserProfile() async {
    try {
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final firstName = await authService.getUserFirstName();
      final role = await authService.getUserRole();
      if (mounted) setState(() { _userName = firstName ?? "User"; _userRole = role ?? "user"; });
      _logger.i("HomeScreen: User: $_userName, Role: $_userRole");
    } catch (e) {
      _logger.e("HomeScreen: UserProfile Error", error: e);
      if (mounted) setState(() { _userName = "User"; _userRole = "user"; });
    }
  }
  Future<void> _showSignOutConfirmation(BuildContext context) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirm Sign Out'), content: const Text('Are you sure you want to sign out?'), actions: [ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop(false)), TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text('Sign Out'), onPressed: () => Navigator.of(ctx).pop(true))]));
    if (confirm == true) _signOut(context);
  }
  Future<void> _signOut(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } catch (e) {
      _logger.e("HomeScreen: SignOut Error", error: e);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: ${e.toString().substring(0, min(e.toString().length,100))}'), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
    }
  }
  Widget _buildDashboardItem({required IconData icon, required String label, required String routeName, Object? arguments, required BuildContext context}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card( elevation: 2.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(borderRadius: BorderRadius.circular(10), onTap: () => Navigator.pushNamed(context, routeName, arguments: arguments),
            child: Padding(padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[ Icon(icon, size: 40.0, color: colorScheme.primary), const SizedBox(height: 10.0), Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))]))));
  }
  Widget _buildAnalyticsItem(BuildContext context, IconData icon, String value, String label) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [ Icon(icon, color: colorScheme.primary, size: 28), const SizedBox(height: 4), Text(value, style: textTheme.titleLarge?.copyWith(color: colorScheme.primary)), Text(label, style: textTheme.bodySmall)]);
  }

  Widget _buildFeaturedEstateCard(BuildContext context, Estate featuredEstate) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
        elevation: 4.0,
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.stars, color: Colors.amber.shade700, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text("Featured Partner: ${featuredEstate.name}",
                            style: textTheme.titleLarge?.copyWith(color: colorScheme.primary))),
                  ]),
                  if (featuredEstate.companyProfile != null && featuredEstate.companyProfile!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(featuredEstate.companyProfile!, style: textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 12),
                  Text('Property Types Offered:', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (featuredEstate.propertyTypesOffered.isEmpty)
                    Text("No specific property types listed.", style: textTheme.bodyMedium)
                  else
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: featuredEstate.propertyTypesOffered.map((type) {
                        return Chip(
                          avatar: Icon(Icons.home_work_outlined, size: 18, color: colorScheme.onPrimaryContainer),
                          label: Text(
                            "${type.name} (${type.beds}B/${type.baths}Ba)",
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: colorScheme.primaryContainer.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 10),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          label: const Text("View Details"),
                          onPressed: () => Navigator.pushNamed(context, '/addEditEstate', arguments: featuredEstate))),
                ])));
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final estateProvider = context.watch<EstateProvider>();
    final propertyCount = context.watch<PropertyProvider>().propertyCount;
    final featuredEstates = estateProvider.featuredEstates;

    return Scaffold(
        appBar: AppBar(
          title: Text(_userName != null && _userName!.isNotEmpty ? 'Hi, $_userName!' : 'RemsAlert Home'),
          actions: [
            IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Settings', onPressed: () => Navigator.pushNamed(context, '/settings')),
            IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign Out', onPressed: () => _showSignOutConfirmation(context)),
          ],
        ),
        body: RefreshIndicator(
            onRefresh: () async {
              await Provider.of<EstateProvider>(context, listen: false).fetchEstates();
              await Provider.of<PropertyProvider>(context, listen: false).fetchProperties(); // Fetch all
              await _loadUserProfile();
            },
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Dashboard Overview', style: textTheme.headlineSmall?.copyWith(fontSize: 22)),
                        if (_userRole == 'admin') Chip(avatar: Icon(Icons.admin_panel_settings, color: colorScheme.onSecondaryContainer), label: Text('Admin', style: TextStyle(color: colorScheme.onSecondaryContainer)), backgroundColor: colorScheme.secondaryContainer.withOpacity(0.7), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2))
                      ]),
                      const SizedBox(height: 20),
                      Card( color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _buildAnalyticsItem(context, Icons.business_outlined, estateProvider.estateCount.toString(), "Estates"),
                            _buildAnalyticsItem(context, Icons.home_work_outlined, propertyCount.toString(), "Properties"),
                            _buildAnalyticsItem(context, Icons.groups_outlined, "0", "Staff"), // Placeholder
                          ]))),
                      if (featuredEstates.isNotEmpty) _buildFeaturedEstateCard(context, featuredEstates.first),
                      const SizedBox(height: 30),
                      Text('Management Sections', style: textTheme.titleLarge),
                      const SizedBox(height: 15),
                      GridView.count(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2,
                          crossAxisSpacing: 16.0, mainAxisSpacing: 16.0, childAspectRatio: 1.1,
                          children: <Widget>[
                            _buildDashboardItem(icon: Icons.location_city_outlined, label: 'Manage Estates\n& Locations', routeName: '/manageEstates', context: context),
                            _buildDashboardItem(icon: Icons.villa_outlined, label: 'Manage All\nProperties', routeName: '/manageProperties', context: context),
                            if (_userRole == 'admin') ...[ // Admin specific dashboards
                              _buildDashboardItem(icon: Icons.badge_outlined, label: 'Manage\nStaff', routeName: '/manageStaff', context: context),
                              _buildDashboardItem(icon: Icons.assignment_ind_outlined, label: 'Assign Tasks\n& Roles', routeName: '/assignTasks', context: context),
                              _buildDashboardItem(icon: Icons.analytics_outlined, label: 'View\nAnalytics', routeName: '/viewAnalytics', context: context),
                              _buildDashboardItem(icon: Icons.people_alt_outlined, label: 'Manage\nOwners', routeName: '/manageOwners', context: context),
                            ]
                          ]),
                      const SizedBox(height: 20),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text("Note: This application uses local storage for demonstration...", style: textTheme.bodySmall?.copyWith(color: textTheme.bodySmall?.color?.withOpacity(0.7), fontStyle: FontStyle.italic), textAlign: TextAlign.center)),
                    ]))));
  }
}

// --- Reusable Widgets ---
class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ const CircularProgressIndicator(), if (message != null) ...[ const SizedBox(height: 20), Text(message!, style: Theme.of(context).textTheme.bodyLarge)]]));
  }
}
class EmptyContent extends StatelessWidget {
  final String title; final String message; final IconData icon;
  const EmptyContent({super.key, required this.title, required this.message, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(child: Padding(padding: const EdgeInsets.all(32.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 80, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(title, style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(message, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.5)), textAlign: TextAlign.center),
        ])));
  }
}

// --- Admin Section Screens ---
// ManageEstatesScreen
class ManageEstatesScreen extends StatelessWidget {
  const ManageEstatesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final estateProvider = Provider.of<EstateProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Estates')),
      body: estateProvider.isLoading ? const LoadingIndicator(message: 'Loading estates...')
          : estateProvider.estates.isEmpty ? const EmptyContent(title: 'No Estates Found', message: 'Tap the + button to add your first estate.')
          : ListView.builder(
          itemCount: estateProvider.estates.length,
          itemBuilder: (ctx, i) {
            final estate = estateProvider.estates[i];
            return Card( margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.business, color: Theme.of(context).colorScheme.onPrimaryContainer), backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)),
                  title: Text(estate.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(estate.address ?? 'No address provided'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.villa_outlined, color: Theme.of(context).colorScheme.secondary), tooltip: 'View Properties', onPressed: () => Navigator.pushNamed(context, '/manageProperties', arguments: estate.id)),
                    IconButton(icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary), tooltip: 'Edit Estate', onPressed: () => Navigator.pushNamed(context, '/addEditEstate', arguments: estate)),
                    IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), tooltip: 'Delete Estate', onPressed: () async {
                      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirm Delete'), content: Text('Are you sure you want to delete "${estate.name}" and all its associated properties & visitors? This cannot be undone.'), actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'))]));
                      if (confirm == true) {
                        try {
                          await estateProvider.deleteEstate(estate.id);
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estate "${estate.name}" deleted.'), backgroundColor: Colors.green));
                        } catch (e) {
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting estate: $e'), backgroundColor: Colors.red));
                        }
                      }
                    }),
                  ]),
                  onTap: () => Navigator.pushNamed(context, '/addEditEstate', arguments: estate),
                ));
          }),
      floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add_business_outlined), label: const Text('Add Estate'), onPressed: () => Navigator.pushNamed(context, '/addEditEstate')),
    );
  }
}

// AddEditEstateScreen
class AddEditEstateScreen extends StatefulWidget {
  const AddEditEstateScreen({super.key});
  @override
  State<AddEditEstateScreen> createState() => _AddEditEstateScreenState();
}
class _AddEditEstateScreenState extends State<AddEditEstateScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _addressController, _descriptionController, _companyProfileController;
  Estate? _editingEstate; bool _isLoading = false; bool _isInitialized = false; bool _isFeatured = false;
  List<FeaturedPropertyType> _propertyTypesOffered = [];


  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(); _addressController = TextEditingController();
    _descriptionController = TextEditingController(); _companyProfileController = TextEditingController();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final estateArg = ModalRoute.of(context)?.settings.arguments as Estate?;
      if (estateArg != null) {
        _editingEstate = estateArg; _nameController.text = _editingEstate!.name;
        _addressController.text = _editingEstate!.address ?? '';
        _descriptionController.text = _editingEstate!.description ?? '';
        _isFeatured = _editingEstate!.isFeatured;
        _companyProfileController.text = _editingEstate!.companyProfile ?? '';
        _propertyTypesOffered = List.from(_editingEstate!.propertyTypesOffered); // Make a mutable copy
      }
      _isInitialized = true;
      // Specific handling for Diamond City to prefill if empty
      if (_editingEstate?.name == "DIAMOND CITY GROUP LTD" && _companyProfileController.text.isEmpty) {
        _companyProfileController.text = _editingEstate?.companyProfile ?? "DIAMOND CITY GROUP LTD is a property development company based in Abuja, Nigeria, specializing in the design, construction, and management of modern residential and commercial properties. Our mission is to create sustainable communities with high-quality infrastructure and a focus on customer satisfaction.";
      }
      if (_editingEstate?.name == "DIAMOND CITY GROUP LTD" && _propertyTypesOffered.isEmpty && _editingEstate!.propertyTypesOffered.isNotEmpty) {
        _propertyTypesOffered = List.from(_editingEstate!.propertyTypesOffered);
      } else if (_editingEstate?.name == "DIAMOND CITY GROUP LTD" && _propertyTypesOffered.isEmpty) {
        _propertyTypesOffered = [
          FeaturedPropertyType(name: "THREE BEDROOM TERRACE DUPLEX WITH BQ", beds: 4, baths: 4, sqm: 250),
          FeaturedPropertyType(name: "FOUR BEDROOM SEMI-DETACHED DUPLEX WITH BQ", beds: 5, baths: 5, sqm: 300),
          FeaturedPropertyType(name: "FIVE BEDROOM FULLY DETACHED DUPLEX WITH BQ", beds: 6, baths: 6, sqm: 380),
        ];
      }
    }
  }
  @override
  void dispose() { _nameController.dispose(); _addressController.dispose(); _descriptionController.dispose(); _companyProfileController.dispose(); super.dispose(); }

  Future<void> _saveEstate() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);
    final estateProvider = Provider.of<EstateProvider>(context, listen: false);

    final estateData = Estate(
      id: _editingEstate?.id, name: _nameController.text.trim(), address: _addressController.text.trim(),
      description: _descriptionController.text.trim(),
      dateAdded: _editingEstate?.dateAdded ?? DateTime.now(), isFeatured: _isFeatured,
      companyProfile: _isFeatured ? _companyProfileController.text.trim() : null,
      propertyTypesOffered: _isFeatured ? _propertyTypesOffered : [],
    );
    try {
      if (_editingEstate == null) await estateProvider.addEstate(estateData);
      else await estateProvider.updateEstate(estateData);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estate ${_editingEstate == null ? "added" : "updated"} successfully!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
    } catch (e) {
      _logger.e("AddEditEstateScreen: Error saving estate", error: e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save estate: ${e.toString().substring(0, min(e.toString().length, 100))}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addPropertyType() {
    // Show a dialog to add property type details
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController bedsCtrl = TextEditingController();
    TextEditingController bathsCtrl = TextEditingController();
    TextEditingController sqmCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Add Property Type"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Type Name")),
        TextField(controller: bedsCtrl, decoration: InputDecoration(labelText: "Beds"), keyboardType: TextInputType.number),
        TextField(controller: bathsCtrl, decoration: InputDecoration(labelText: "Baths"), keyboardType: TextInputType.number),
        TextField(controller: sqmCtrl, decoration: InputDecoration(labelText: "SQM"), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
        ElevatedButton(onPressed: (){
          if(nameCtrl.text.isNotEmpty && bedsCtrl.text.isNotEmpty && bathsCtrl.text.isNotEmpty && sqmCtrl.text.isNotEmpty) {
            setState(() {
              _propertyTypesOffered.add(FeaturedPropertyType(
                name: nameCtrl.text,
                beds: int.tryParse(bedsCtrl.text) ?? 0,
                baths: int.tryParse(bathsCtrl.text) ?? 0,
                sqm: int.tryParse(sqmCtrl.text) ?? 0,
              ));
            });
            Navigator.pop(ctx);
          }
        }, child: Text("Add")),
      ],
    ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(_editingEstate == null ? 'Add New Estate' : 'Edit Estate'),
            actions: [
              if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
              if (!_isLoading) IconButton(icon: const Icon(Icons.save_alt_outlined), onPressed: _saveEstate, tooltip: 'Save Estate'),
            ]),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Estate Name', prefixIcon: Icon(Icons.business_outlined)), validator: (value) => value==null||value.isEmpty ? 'Please enter estate name' : null, textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)), textInputAction: TextInputAction.next, maxLines: 2),
              const SizedBox(height: 16),
              TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'General Description', prefixIcon: Icon(Icons.description_outlined)), maxLines: 3, textInputAction: TextInputAction.newline),
              const SizedBox(height: 16),
              SwitchListTile(title: const Text("Mark as Featured Partner"), value: _isFeatured, onChanged: (bool value) => setState(() => _isFeatured = value), secondary: Icon(_isFeatured ? Icons.star : Icons.star_border_outlined, color: _isFeatured ? Colors.amber.shade700 : null,)),

              if(_isFeatured) ...[
                const SizedBox(height: 16),
                TextFormField(controller: _companyProfileController, decoration: const InputDecoration(labelText: 'Company Profile (for Featured)', prefixIcon: Icon(Icons.info_outline)), maxLines: 4, textInputAction: TextInputAction.newline),
                const SizedBox(height: 16),
                Text("Property Types Offered (for Featured)", style: Theme.of(context).textTheme.titleMedium),
                if (_propertyTypesOffered.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _propertyTypesOffered.length,
                    itemBuilder: (ctx, index) {
                      final type = _propertyTypesOffered[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(type.name),
                          subtitle: Text("${type.beds} Beds, ${type.baths} Baths, ${type.sqm} SQM"),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => setState(() => _propertyTypesOffered.removeAt(index)),
                          ),
                        ),
                      );
                    },
                  ),
                TextButton.icon(icon: Icon(Icons.add_circle_outline), label: Text("Add Property Type"), onPressed: _addPropertyType),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(icon: const Icon(Icons.save_outlined), label: Text(_isLoading ? 'Saving...' : 'Save Estate'), onPressed: _isLoading ? null : _saveEstate),
            ]))));
  }
}

// ManagePropertiesScreen
class ManagePropertiesScreen extends StatefulWidget {
  const ManagePropertiesScreen({super.key});
  @override
  State<ManagePropertiesScreen> createState() => _ManagePropertiesScreenState();
}
class _ManagePropertiesScreenState extends State<ManagePropertiesScreen> {
  String? _estateIdArg; String _appBarTitle = 'Manage Properties'; bool _isInitialLoad = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      final estateIdFromRoute = ModalRoute.of(context)?.settings.arguments as String?;
      _estateIdArg = estateIdFromRoute;
      _logger.i("ManagePropertiesScreen: Estate ID from route: $_estateIdArg");
      final propertyProvider = Provider.of<PropertyProvider>(context, listen: false);
      // Fetch properties specific to this estateId if provided, or all if null (though typically called with estateId)
      propertyProvider.fetchProperties(_estateIdArg);

      if (_estateIdArg != null) {
        final estateProvider = Provider.of<EstateProvider>(context, listen: false);
        estateProvider.getEstateById(_estateIdArg!).then((estate) {
          if (mounted && estate != null) setState(() => _appBarTitle = 'Properties in ${estate.name}');
          else if (mounted) setState(() => _appBarTitle = 'Properties for Selected Estate');
        });
      } else { if (mounted) setState(() => _appBarTitle = 'All Properties'); }
      _isInitialLoad = false;
    }
  }
  @override
  Widget build(BuildContext context) {
    final propertyProvider = Provider.of<PropertyProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: propertyProvider.isLoading ? const LoadingIndicator(message: 'Loading properties...')
          : propertyProvider.properties.isEmpty ? EmptyContent(title: 'No Properties Found', message: _estateIdArg != null ? 'Tap + to add properties to this estate.' : 'Tap + to add your first property.')
          : ListView.builder(
          itemCount: propertyProvider.properties.length,
          itemBuilder: (ctx, i) {
            final property = propertyProvider.properties[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.home_work, color: Theme.of(context).colorScheme.onSecondaryContainer), backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5)),
                  title: Text(property.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(property.type ?? 'Type not specified'), if (property.address != null && property.address!.isNotEmpty) Text(property.address!), Text('Status: ${property.status ?? 'N/A'}')]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.people_outline, color: Theme.of(context).colorScheme.tertiary), tooltip: 'Manage Visitors',
                        onPressed: () => Navigator.pushNamed(context, '/propertyVisitors', arguments: property)),
                    IconButton(icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary), tooltip: 'Edit Property', onPressed: () => Navigator.pushNamed(context, '/addEditProperty', arguments: {'property': property, 'estateId': property.estateId})), // Pass estateId for context
                    IconButton(icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), tooltip: 'Delete Property', onPressed: () async {
                      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirm Delete'), content: Text('Are you sure you want to delete property "${property.name}" and all its visitors?'), actions: [ TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'))]));
                      if (confirm == true) {
                        try {
                          await propertyProvider.deleteProperty(property.id);
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Property "${property.name}" deleted.'), backgroundColor: Colors.green));
                        } catch (e) {
                          if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting property: $e'), backgroundColor: Colors.red));
                        }
                      }
                    }),
                  ]),
                  onTap: () => Navigator.pushNamed(context, '/addEditProperty', arguments: {'property': property, 'estateId': property.estateId}),
                ));
          }),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_home_work_outlined), label: const Text('Add Property'),
          onPressed: () {
            if (_estateIdArg == null && context.read<EstateProvider>().estates.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add an Estate first before adding properties.'), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating)); return;
            }
            Navigator.pushNamed(context, '/addEditProperty', arguments: {'estateId': _estateIdArg}); // Pass current estateId if available
          }),
    );
  }
}

// AddEditPropertyScreen
class AddEditPropertyScreen extends StatefulWidget {
  const AddEditPropertyScreen({super.key});
  @override
  State<AddEditPropertyScreen> createState() => _AddEditPropertyScreenState();
}
class _AddEditPropertyScreenState extends State<AddEditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _typeController, _addressController, _statusController;
  Property? _editingProperty; String? _selectedEstateId; bool _isLoading = false;
  List<Estate> _availableEstates = []; bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(); _typeController = TextEditingController();
    _addressController = TextEditingController(); _statusController = TextEditingController();
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); if (!_isInitialized) { _loadInitialData(); _isInitialized = true; } }
  Future<void> _loadInitialData() async {
    final estateProvider = Provider.of<EstateProvider>(context, listen: false);
    // Ensure estates are loaded if not already
    if (estateProvider.estates.isEmpty && !estateProvider.isLoading) await estateProvider.fetchEstates();
    if (!mounted) return;

    _availableEstates = estateProvider.estates;
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    String? initialEstateIdForDropdown;

    if (args != null) {
      final propertyArg = args['property'] as Property?;
      final estateIdArgFromRoute = args['estateId'] as String?;

      if (propertyArg != null) {
        _editingProperty = propertyArg; _nameController.text = _editingProperty!.name;
        _typeController.text = _editingProperty!.type ?? ''; _addressController.text = _editingProperty!.address ?? '';
        _statusController.text = _editingProperty!.status ?? '';
        initialEstateIdForDropdown = _editingProperty!.estateId;
      } else if (estateIdArgFromRoute != null) {
        initialEstateIdForDropdown = estateIdArgFromRoute;
      }
    }

    if (_availableEstates.isNotEmpty) {
      if (initialEstateIdForDropdown != null && _availableEstates.any((e) => e.id == initialEstateIdForDropdown)) {
        _selectedEstateId = initialEstateIdForDropdown;
      } else if (_availableEstates.length == 1 && _editingProperty == null) { // Auto-select if only one estate and adding new
        _selectedEstateId = _availableEstates.first.id;
      }
    }
    if (mounted) setState(() {});
  }
  @override
  void dispose() { _nameController.dispose(); _typeController.dispose(); _addressController.dispose(); _statusController.dispose(); super.dispose(); }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    if (_selectedEstateId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an estate.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating)); return; }
    setState(() => _isLoading = true);
    final propertyProvider = Provider.of<PropertyProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserEmail = await authService.getCurrentUserEmail(); // For ownerId

    final propertyData = Property(
      id: _editingProperty?.id, estateId: _selectedEstateId!, name: _nameController.text.trim(),
      type: _typeController.text.trim(), address: _addressController.text.trim(), status: _statusController.text.trim(),
      ownerId: _editingProperty?.ownerId ?? currentUserEmail, // Preserve existing or set new
    );
    try {
      if (_editingProperty == null) await propertyProvider.addProperty(propertyData);
      else await propertyProvider.updateProperty(propertyData);
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Property ${_editingProperty == null ? "added" : "updated"} successfully!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
    } catch (e) {
      _logger.e("AddEditPropertyScreen: Error saving property", error: e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save property: ${e.toString().substring(0, min(e.toString().length, 100))}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(_editingProperty == null ? 'Add New Property' : 'Edit Property'),
            actions: [
              if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
              if (!_isLoading) IconButton(icon: const Icon(Icons.save_alt_outlined), onPressed: _saveProperty, tooltip: 'Save Property'),
            ]),
        body: (_availableEstates.isEmpty && _editingProperty == null && _selectedEstateId == null && !Provider.of<EstateProvider>(context, listen: false).isLoading)
            ? const EmptyContent(title: 'No Estates Available', message: 'Please create an estate first before adding properties.', icon: Icons.business_sharp)
            : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              if (_availableEstates.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedEstateId, decoration: const InputDecoration(labelText: 'Belongs to Estate', prefixIcon: Icon(Icons.business_outlined)),
                  items: _availableEstates.map((estate) => DropdownMenuItem<String>(value: estate.id, child: Text(estate.name))).toList(),
                  onChanged: (value) => setState(() => _selectedEstateId = value),
                  validator: (value) => value == null ? 'Please select an estate' : null,
                )
              else if (_editingProperty?.estateId != null) // Editing an existing property without estates loaded (edge case)
                ListTile(leading: const Icon(Icons.business_outlined), title: Text("Estate: Linked to Estate ID ${_editingProperty!.estateId}"), subtitle: const Text("Ensure parent estate exists."))
              else if (Provider.of<EstateProvider>(context, listen: false).isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Loading estates...", style: TextStyle(fontStyle: FontStyle.italic))))
                else // No estates and not loading
                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("No estates found. Please add an estate first.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.redAccent)))),

              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Property Name/Unit ID', prefixIcon: Icon(Icons.tag_outlined)), validator: (value) => value==null||value.isEmpty ? 'Property name is required' : null, textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              TextFormField(controller: _typeController, decoration: const InputDecoration(labelText: 'Property Type (e.g., Apartment, Villa)', prefixIcon: Icon(Icons.category_outlined)), textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Specific Address (if different from estate)', prefixIcon: Icon(Icons.location_on_outlined)), textInputAction: TextInputAction.next, maxLines: 2),
              const SizedBox(height: 16),
              TextFormField(controller: _statusController, decoration: const InputDecoration(labelText: 'Status (e.g., Vacant, Occupied)', prefixIcon: Icon(Icons.check_circle_outline_outlined)), textInputAction: TextInputAction.done, onFieldSubmitted: (_) {if (!_isLoading) _saveProperty();}),
              const SizedBox(height: 24),
              ElevatedButton.icon(icon: const Icon(Icons.save_outlined), label: Text(_isLoading ? 'Saving...' : 'Save Property'), onPressed: _isLoading || _availableEstates.isEmpty && _editingProperty == null ? null : _saveProperty),
            ]))));
  }
}


// --- Visitor Management Screens ---
class PropertyVisitorsScreen extends StatefulWidget {
  const PropertyVisitorsScreen({super.key});

  @override
  State<PropertyVisitorsScreen> createState() => _PropertyVisitorsScreenState();
}

class _PropertyVisitorsScreenState extends State<PropertyVisitorsScreen> {
  Property? _property;
  bool _isInitialLoad = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      final propertyArg = ModalRoute.of(context)?.settings.arguments as Property?;
      if (propertyArg == null) {
        _logger.e("PropertyVisitorsScreen: Property argument is null!");
        // Optionally navigate back or show error
        if(mounted) Navigator.pop(context);
        return;
      }
      _property = propertyArg;
      _logger.i("PropertyVisitorsScreen: Managing visitors for Property ID: ${_property!.id}, Name: ${_property!.name}");
      Provider.of<VisitorProvider>(context, listen: false).fetchVisitors(_property!.id);
      _isInitialLoad = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_property == null) {
      // This case should ideally be handled by navigating back if _property isn't set in didChangeDependencies
      return Scaffold(appBar: AppBar(title: const Text("Error")), body: const Center(child: Text("Property data not found.")));
    }

    final visitorProvider = Provider.of<VisitorProvider>(context);
    final DateFormat dateFormat = DateFormat('EEE, MMM d, yyyy');
    final DateFormat timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text("Visitors for ${_property!.name}"),
      ),
      body: visitorProvider.isLoading
          ? const LoadingIndicator(message: "Loading visitors...")
          : visitorProvider.visitors.isEmpty
          ? EmptyContent(
        title: "No Visitors Registered",
        message: "Tap the + button to add an expected visitor for this property.",
        icon: Icons.person_add_disabled_outlined,
      )
          : ListView.builder(
        itemCount: visitorProvider.visitors.length,
        itemBuilder: (ctx, index) {
          final visitor = visitorProvider.visitors[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: visitor.status == "Expected" ? Colors.orange.shade100 : (visitor.status == "Arrived" ? Colors.green.shade100 : Colors.grey.shade300),
                child: Icon(
                  visitor.status == "Expected" ? Icons.watch_later_outlined : (visitor.status == "Arrived" ? Icons.check_circle_outline : Icons.person_off_outlined),
                  color: visitor.status == "Expected" ? Colors.orange.shade800 : (visitor.status == "Arrived" ? Colors.green.shade800 : Colors.grey.shade700),
                  size: 24,
                ),
              ),
              title: Text(visitor.visitorName, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Phone: ${visitor.visitorPhone}"),
                  Text("Expected: ${dateFormat.format(visitor.expectedDate)} at ${timeFormat.format(DateTime(visitor.expectedDate.year, visitor.expectedDate.month, visitor.expectedDate.day, visitor.expectedTime.hour, visitor.expectedTime.minute))}"),
                  if(visitor.gatePassCode != null)
                    Text("Gate Pass: ${visitor.gatePassCode}", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  Text("Status: ${visitor.status}"),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    Navigator.pushNamed(
                      context,
                      '/addEditVisitor',
                      arguments: {
                        'visitor': visitor,
                        'propertyId': _property!.id,
                        'propertyAddress': _property!.address ?? _property!.name, // Pass address
                      },
                    );
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (bCtx) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: Text('Are you sure you want to delete visitor "${visitor.visitorName}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(bCtx).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(bCtx).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await visitorProvider.deleteVisitor(visitor.id, _property!.id);
                        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visitor "${visitor.visitorName}" deleted.'), backgroundColor: Colors.green));
                      } catch (e) {
                        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting visitor: $e'), backgroundColor: Colors.red));
                      }
                    }
                  }
                  // TODO: Add options to change status (Arrived, Departed)
                },
                itemBuilder: (BuildContext bCtx) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                  const PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                  // Add more actions like 'Mark Arrived', 'Mark Departed' later
                ],
              ),
              onTap: () { // For quick edit
                Navigator.pushNamed(
                  context,
                  '/addEditVisitor',
                  arguments: {
                    'visitor': visitor,
                    'propertyId': _property!.id,
                    'propertyAddress': _property!.address ?? _property!.name,
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add Visitor'),
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/addEditVisitor',
            arguments: {
              'propertyId': _property!.id,
              'propertyAddress': _property!.address ?? _property!.name, // Pre-fill address
            },
          );
        },
      ),
    );
  }
}

// (Keep all other code as is)

// ... (previous classes) ...

class AddEditVisitorScreen extends StatefulWidget {
  const AddEditVisitorScreen({super.key});

  @override
  State<AddEditVisitorScreen> createState() => _AddEditVisitorScreenState();
}

class _AddEditVisitorScreenState extends State<AddEditVisitorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _phoneController, _addressController;
  Visitor? _editingVisitor;
  String? _propertyId;
  String? _propertyAddress; // To prefill the 'address visiting' field

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) {
        _logger.e("AddEditVisitorScreen: Arguments are null!");
        if(mounted) Navigator.pop(context); // Navigate back if critical args missing
        return;
      }

      _editingVisitor = args['visitor'] as Visitor?;
      _propertyId = args['propertyId'] as String?;
      _propertyAddress = args['propertyAddress'] as String?;

      if (_editingVisitor != null) {
        _nameController.text = _editingVisitor!.visitorName;
        _phoneController.text = _editingVisitor!.visitorPhone;
        _addressController.text = _editingVisitor!.addressVisiting;
        _selectedDate = _editingVisitor!.expectedDate;
        _selectedTime = _editingVisitor!.expectedTime;
        _propertyId = _editingVisitor!.propertyId; // Ensure propertyId is set from visitor if editing
      } else {
        // If adding new, prefill addressVisiting if propertyAddress is available
        if(_propertyAddress != null) _addressController.text = _propertyAddress!;
      }

      if (_propertyId == null) {
        _logger.e("AddEditVisitorScreen: propertyId is null, cannot save visitor!");
        // Potentially show an error and prevent saving
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Yesterday onwards
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveVisitor() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    if (_propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Property association is missing.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _isLoading = true);
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final ownerEmail = await authService.getCurrentUserEmail();

    final visitorData = Visitor(
      id: _editingVisitor?.id,
      propertyId: _propertyId!,
      ownerId: _editingVisitor?.ownerId ?? ownerEmail, // Preserve existing or set new
      visitorName: _nameController.text.trim(),
      visitorPhone: _phoneController.text.trim(),
      addressVisiting: _addressController.text.trim(),
      expectedDate: _selectedDate,
      expectedTime: _selectedTime,
      status: _editingVisitor?.status ?? "Expected", // Preserve status if editing
      gatePassCode: _editingVisitor?.gatePassCode, // Preserve code if editing (new code generated on add only by provider)
      dateAdded: _editingVisitor?.dateAdded ?? DateTime.now(),
    );

    try {
      if (_editingVisitor == null) {
        await visitorProvider.addVisitor(visitorData);
      } else {
        await visitorProvider.updateVisitor(visitorData);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Visitor ${_editingVisitor == null ? "added" : "updated"} successfully!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      _logger.e("AddEditVisitorScreen: Error saving visitor", error: e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save visitor: ${e.toString().substring(0, min(e.toString().length, 100))}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('EEE, MMM d, yyyy');
    // final TimeOfDayFormat timeFormat = TimeOfDayFormat.jm; // <-- THIS LINE WAS REMOVED

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingVisitor == null ? 'Add Expected Visitor' : 'Edit Visitor Details'),
        actions: [
          if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
          if (!_isLoading) IconButton(icon: const Icon(Icons.save_alt_outlined), onPressed: _saveVisitor, tooltip: 'Save Visitor'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Visitor\'s Full Name', prefixIcon: Icon(Icons.person_outline)),
                validator: (value) => value == null || value.isEmpty ? 'Please enter visitor name' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Visitor\'s Telephone', prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty ? 'Please enter visitor phone' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address/Unit Visitor is Coming To', prefixIcon: Icon(Icons.location_city_outlined)),
                validator: (value) => value == null || value.isEmpty ? 'Please enter address visitor is coming to' : null,
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Text("Expected Arrival:", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(dateFormat.format(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time_outlined),
                        ),
                        child: Text(_selectedTime.format(context)), // Uses localization
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: Text(_isLoading ? 'Saving...' : 'Save Visitor'),
                onPressed: _isLoading ? null : _saveVisitor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageStaffScreen extends StatelessWidget {
  const ManageStaffScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Manage Staff')), body: const Center(child: EmptyContent(title: "Coming Soon", message: "Staff management features will be available here.", icon: Icons.people_rounded)));
}
class AssignTasksScreen extends StatelessWidget {
  const AssignTasksScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Assign Tasks/Roles')), body: const Center(child: EmptyContent(title: "Coming Soon", message: "Task assignment features will be available here.", icon: Icons.assignment_turned_in_outlined)));
}
class ViewAnalyticsScreen extends StatelessWidget {
  const ViewAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('View Analytics')), body: const Center(child: EmptyContent(title: "Coming Soon", message: "Detailed analytics will be shown here.", icon: Icons.bar_chart_rounded)));
}
class ManageOwnersScreen extends StatelessWidget {
  const ManageOwnersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Manage Owners')), body: const Center(child: EmptyContent(title: "Coming Soon", message: "Property owner management features will be available here.", icon: Icons.real_estate_agent_outlined)));
}

// --- Settings Screen ---
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(padding: const EdgeInsets.all(16.0), children: <Widget>[
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(child: Column(children: [
            RadioListTile<ThemeMode>(title: const Text('Light Mode'), value: ThemeMode.light, groupValue: themeProvider.themeMode, onChanged: (ThemeMode? value) { if (value != null) themeProvider.setThemeMode(value); }, secondary: const Icon(Icons.wb_sunny_outlined)),
            RadioListTile<ThemeMode>(title: const Text('Dark Mode'), value: ThemeMode.dark, groupValue: themeProvider.themeMode, onChanged: (ThemeMode? value) { if (value != null) themeProvider.setThemeMode(value); }, secondary: const Icon(Icons.nightlight_round_outlined)),
            RadioListTile<ThemeMode>(title: const Text('System Default'), value: ThemeMode.system, groupValue: themeProvider.themeMode, onChanged: (ThemeMode? value) { if (value != null) themeProvider.setThemeMode(value); }, secondary: const Icon(Icons.settings_system_daydream_outlined)),
          ])),
          const SizedBox(height: 24),
          // Add more settings sections if needed
          // Example: Data Management
          // Text('Data Management', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.primary)),
          // Card(child: ListTile(
          //   leading: Icon(Icons.delete_forever_outlined, color: colorScheme.error),
          //   title: Text('Clear All App Data', style: TextStyle(color: colorScheme.error)),
          //   subtitle: Text('Resets the app to its initial state. Use with caution!'),
          //   onTap: () async {
          //     // Show confirmation dialog
          //   },
          // )),
        ]));
  }
}
