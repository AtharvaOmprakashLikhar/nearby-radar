import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  BlobColumn get avatarBytes => blob().nullable()();
  TextColumn get bio => text().withDefault(const Constant(''))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get publicKey => text()();
  TextColumn get safetyCode => text().withDefault(const Constant(''))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSeenAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get recipientId => text()();
  TextColumn get content => text()();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  TextColumn get fileUrl => text().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  TextColumn get deliveryStatus => text().withDefault(const Constant('queued'))();
  TextColumn get replyToId => text().nullable()();
  TextColumn get reactions => text().withDefault(const Constant('{}'))();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class TransferRecords extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text()();
  TextColumn get filePath => text()();
  IntColumn get totalBytes => integer()();
  IntColumn get transferredBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get transferType => text().withDefault(const Constant('ble'))();
  TextColumn get checksumSha256 => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Contacts, Messages, TransferRecords, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'nearby_radar_encrypted',
    );
  }
}
