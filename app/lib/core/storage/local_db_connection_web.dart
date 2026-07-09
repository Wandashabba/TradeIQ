import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openDbConnection() {
  return WebDatabase.withStorage(DriftWebStorage.volatile());
}
