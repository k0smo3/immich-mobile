import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionRepositoryProvider = Provider((_) {
  return const PermissionRepository();
});

class PermissionRepository implements IPermissionRepository {
  const PermissionRepository();

  @override
  Future<bool> openSettings() {
    return openAppSettings();
  }
}

abstract interface class IPermissionRepository {
  Future<bool> openSettings();
}
