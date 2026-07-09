// The legacy drift web API is enough for the volatile dev-only web database;
// migrating to package:drift/wasm.dart needs bundled sqlite3.wasm/worker
// assets and is tracked separately.
// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openDbConnection() {
  return WebDatabase.withStorage(DriftWebStorage.volatile());
}
