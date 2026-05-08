import 'package:drift/drift.dart';

class Repositories extends Table {
  TextColumn get id => text().withLength(min: 32, max: 32)();
  TextColumn get path => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get color => text().nullable()();
  DateTimeColumn get lastOpenedUtc => dateTime()();
  IntColumn get tabOrder => integer()();
  DateTimeColumn get createdUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
