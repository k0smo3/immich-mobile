import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/models/auth/auxilary_endpoint.model.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/services/auth.service.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openapi/api.dart';

import '../domain/service.mock.dart';
import '../repository.mocks.dart';
import '../service.mocks.dart';
import '../test_utils.dart';

void main() {
  late AuthService sut;
  late MockAuthApiRepository authApiRepository;
  late MockAuthRepository authRepository;
  late MockApiService apiService;
  late MockBackgroundSyncManager backgroundSyncManager;
  late MockAppSettingService appSettingsService;
  late Isar db;

  setUp(() async {
    authApiRepository = MockAuthApiRepository();
    authRepository = MockAuthRepository();
    apiService = MockApiService();
    backgroundSyncManager = MockBackgroundSyncManager();
    appSettingsService = MockAppSettingService();

    sut = AuthService(
      authApiRepository,
      authRepository,
      apiService,
      backgroundSyncManager,
      appSettingsService,
    );

    // Skip real TCP socket checks in unit tests — hostnames are fake
    AuthService.skipTcpCheck = true;

    registerFallbackValue(Uri());
  });

  tearDown(() {
    AuthService.skipTcpCheck = false;
  });

  setUpAll(() async {
    db = await TestUtils.initIsar();
    db.writeTxnSync(() => db.clearSync());
    await StoreService.init(storeRepository: IsarStoreRepository(db));
  });

  group('validateServerUrl', () {
    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      final db = await TestUtils.initIsar();
      db.writeTxnSync(() => db.clearSync());
      await StoreService.init(storeRepository: IsarStoreRepository(db));
    });

    test('Should resolve HTTP endpoint', () async {
      const testUrl = 'http://ip:2283';
      const resolvedUrl = 'http://ip:2283/api';

      when(() => apiService.resolveAndSetEndpoint(testUrl)).thenAnswer((_) async => resolvedUrl);
      when(() => apiService.setDeviceInfoHeader()).thenAnswer((_) async => {});

      final result = await sut.validateServerUrl(testUrl);

      expect(result, resolvedUrl);

      verify(() => apiService.resolveAndSetEndpoint(testUrl)).called(1);
      verify(() => apiService.setDeviceInfoHeader()).called(1);
    });

    test('Should resolve HTTPS endpoint', () async {
      const testUrl = 'https://immich.domain.com';
      const resolvedUrl = 'https://immich.domain.com/api';

      when(() => apiService.resolveAndSetEndpoint(testUrl)).thenAnswer((_) async => resolvedUrl);
      when(() => apiService.setDeviceInfoHeader()).thenAnswer((_) async => {});

      final result = await sut.validateServerUrl(testUrl);

      expect(result, resolvedUrl);

      verify(() => apiService.resolveAndSetEndpoint(testUrl)).called(1);
      verify(() => apiService.setDeviceInfoHeader()).called(1);
    });

    test('Should throw error on invalid URL', () async {
      const testUrl = 'invalid-url';

      when(() => apiService.resolveAndSetEndpoint(testUrl)).thenThrow(Exception('Invalid URL'));

      expect(() async => await sut.validateServerUrl(testUrl), throwsA(isA<Exception>()));

      verify(() => apiService.resolveAndSetEndpoint(testUrl)).called(1);
      verifyNever(() => apiService.setDeviceInfoHeader());
    });

    test('Should throw error on unreachable server', () async {
      const testUrl = 'https://unreachable.server';

      when(() => apiService.resolveAndSetEndpoint(testUrl)).thenThrow(Exception('Server is not reachable'));

      expect(() async => await sut.validateServerUrl(testUrl), throwsA(isA<Exception>()));

      verify(() => apiService.resolveAndSetEndpoint(testUrl)).called(1);
      verifyNever(() => apiService.setDeviceInfoHeader());
    });
  });

  group('logout', () {
    test('Should logout user', () async {
      when(() => authApiRepository.logout()).thenAnswer((_) async => {});
      when(() => backgroundSyncManager.cancel()).thenAnswer((_) async => {});
      when(() => authRepository.clearLocalData()).thenAnswer((_) => Future.value(null));
      when(
        () => appSettingsService.setSetting(AppSettingsEnum.enableBackup, false),
      ).thenAnswer((_) => Future.value(null));
      await sut.logout();

      verify(() => authApiRepository.logout()).called(1);
      verify(() => backgroundSyncManager.cancel()).called(1);
      verify(() => authRepository.clearLocalData()).called(1);
    });

    test('Should clear local data even on server error', () async {
      when(() => authApiRepository.logout()).thenThrow(Exception('Server error'));
      when(() => backgroundSyncManager.cancel()).thenAnswer((_) async => {});
      when(() => authRepository.clearLocalData()).thenAnswer((_) => Future.value(null));
      when(
        () => appSettingsService.setSetting(AppSettingsEnum.enableBackup, false),
      ).thenAnswer((_) => Future.value(null));
      await sut.logout();

      verify(() => authApiRepository.logout()).called(1);
      verify(() => backgroundSyncManager.cancel()).called(1);
      verify(() => authRepository.clearLocalData()).called(1);
    });
  });

  group('setOpenApiServiceEndpoint', () {
    test('Should use local endpoint when mode is local', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('local');
      when(() => authRepository.getLocalEndpoint()).thenReturn('http://local.endpoint');
      when(
        () => apiService.resolveAndSetEndpoint('http://local.endpoint'),
      ).thenAnswer((_) async => 'http://local.endpoint');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'http://local.endpoint');
      verify(() => authRepository.getEndpointMode()).called(1);
      verify(() => authRepository.getLocalEndpoint()).called(1);
      verify(() => apiService.resolveAndSetEndpoint('http://local.endpoint')).called(1);
    });

    test('Should fall back to external if local endpoint is unavailable', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('local');
      when(() => authRepository.getLocalEndpoint()).thenReturn('http://local.endpoint');
      when(
        () => apiService.resolveAndSetEndpoint('http://local.endpoint'),
      ).thenThrow(Exception('Local endpoint error'));
      when(
        () => authRepository.getExternalEndpointList(),
      ).thenReturn([const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid)]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenAnswer((_) async => 'https://external.endpoint/api');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'https://external.endpoint/api');
    });

    test('Should use external endpoint when mode is external', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('external');
      when(
        () => authRepository.getExternalEndpointList(),
      ).thenReturn([const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid)]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenAnswer((_) async => 'https://external.endpoint/api');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'https://external.endpoint/api');
      verify(() => authRepository.getEndpointMode()).called(1);
      verify(() => authRepository.getExternalEndpointList()).called(1);
      verify(() => apiService.resolveAndSetEndpoint('https://external.endpoint')).called(1);
    });

    test('Should set second external endpoint if the first throws any error', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('external');
      when(() => authRepository.getExternalEndpointList()).thenReturn([
        const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid),
        const AuxilaryEndpoint(url: 'https://external.endpoint2', status: AuxCheckStatus.valid),
      ]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenThrow(Exception('Invalid endpoint'));
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint2'),
      ).thenAnswer((_) async => 'https://external.endpoint2/api');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'https://external.endpoint2/api');
    });

    test('Should set second external endpoint if the first throws ApiException', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('external');
      when(() => authRepository.getExternalEndpointList()).thenReturn([
        const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid),
        const AuxilaryEndpoint(url: 'https://external.endpoint2', status: AuxCheckStatus.valid),
      ]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenThrow(ApiException(503, 'Invalid endpoint'));
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint2'),
      ).thenAnswer((_) async => 'https://external.endpoint2/api');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'https://external.endpoint2/api');
    });

    test('Should fall back to external when no local endpoint is configured', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('local');
      when(() => authRepository.getLocalEndpoint()).thenReturn(null);
      when(
        () => authRepository.getExternalEndpointList(),
      ).thenReturn([const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid)]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenAnswer((_) async => 'https://external.endpoint/api');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'https://external.endpoint/api');
      verifyNever(() => apiService.resolveAndSetEndpoint(any(that: contains('local'))));
    });

    test('Should fall back to local if all external endpoints are unavailable', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('external');
      when(
        () => authRepository.getExternalEndpointList(),
      ).thenReturn([const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid)]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenThrow(Exception('External endpoint error'));
      when(() => authRepository.getLocalEndpoint()).thenReturn('http://local.endpoint');
      when(
        () => apiService.resolveAndSetEndpoint('http://local.endpoint'),
      ).thenAnswer((_) async => 'http://local.endpoint');

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, 'http://local.endpoint');
      verify(() => authRepository.getExternalEndpointList()).called(1);
      verify(() => authRepository.getLocalEndpoint()).called(1);
    });

    test('Should return null if no endpoints are reachable', () async {
      when(() => authRepository.getEndpointMode()).thenReturn('external');
      when(
        () => authRepository.getExternalEndpointList(),
      ).thenReturn([const AuxilaryEndpoint(url: 'https://external.endpoint', status: AuxCheckStatus.valid)]);
      when(
        () => apiService.resolveAndSetEndpoint('https://external.endpoint'),
      ).thenThrow(Exception('External endpoint error'));
      when(() => authRepository.getLocalEndpoint()).thenReturn(null);

      final result = await sut.setOpenApiServiceEndpoint();

      expect(result, isNull);
    });
  });

  group('saveEndpointMode', () {
    test('Should delegate to auth repository', () async {
      when(() => authRepository.saveEndpointMode('external')).thenAnswer((_) async {});

      await sut.saveEndpointMode('external');

      verify(() => authRepository.saveEndpointMode('external')).called(1);
    });

    test('Should delegate local mode to auth repository', () async {
      when(() => authRepository.saveEndpointMode('local')).thenAnswer((_) async {});

      await sut.saveEndpointMode('local');

      verify(() => authRepository.saveEndpointMode('local')).called(1);
    });
  });
}
