import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/repositories/auth.repository.dart';

import '../test_utils.dart';

void main() {
  late AuthRepository sut;
  late Drift driftDb;

  setUpAll(() async {
    driftDb = Drift(drift.DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    await StoreService.init(storeRepository: DriftStoreRepository(driftDb));
  });

  setUp(() async {
    final isarDb = await TestUtils.initIsar();
    sut = AuthRepository(isarDb, driftDb);
    // Reset endpointMode between tests
    await Store.delete(StoreKey.endpointMode);
  });

  tearDownAll(() async {
    await Store.clear();
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
      expect(Store.tryGet(StoreKey.endpointMode), 'local');
    });

    test('persists external mode', () async {
      await sut.saveEndpointMode('external');
      expect(Store.tryGet(StoreKey.endpointMode), 'external');
    });

    test('overwrites previous value', () async {
      await sut.saveEndpointMode('local');
      await sut.saveEndpointMode('external');
      expect(Store.tryGet(StoreKey.endpointMode), 'external');
    });
  });
}
