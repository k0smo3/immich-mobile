import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/data/db/main/database.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/repositories/auth.repository.dart';

void main() {
  late AuthRepository sut;
  late Drift driftDb;
  late SettingsRepository settings;

  setUpAll(() async {
    driftDb = Drift(drift.DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    settings = await SettingsRepository.ensureInitialized(driftDb);
  });

  setUp(() async {
    await driftDb.delete(driftDb.settingsEntity).go();
    await settings.refresh();
    sut = AuthRepository(driftDb, settings);
  });

  tearDownAll(() async {
    await SettingsRepository.reset();
    await driftDb.close();
  });

  group('getEndpointMode', () {
    test('returns local by default when no value is stored', () {
      final mode = sut.getEndpointMode();
      expect(mode, 'local');
    });

    test('returns stored value after saveEndpointMode', () async {
      await sut.saveEndpointMode('external');
      final mode = sut.getEndpointMode();
      expect(mode, 'external');
    });

    test('returns updated value when mode is changed back to local', () async {
      await sut.saveEndpointMode('external');
      await sut.saveEndpointMode('local');
      final mode = sut.getEndpointMode();
      expect(mode, 'local');
    });
  });

  group('saveEndpointMode', () {
    test('persists local mode', () async {
      await sut.saveEndpointMode('local');
      expect(settings.appConfig.network.endpointMode, 'local');
    });

    test('persists external mode', () async {
      await sut.saveEndpointMode('external');
      expect(settings.appConfig.network.endpointMode, 'external');
    });

    test('overwrites previous value', () async {
      await sut.saveEndpointMode('local');
      await sut.saveEndpointMode('external');
      expect(settings.appConfig.network.endpointMode, 'external');
    });
  });
}
