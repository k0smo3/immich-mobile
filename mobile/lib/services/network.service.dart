import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/repositories/permission.repository.dart';

final networkServiceProvider = Provider((ref) {
  return NetworkService(ref.watch(permissionRepositoryProvider));
});

class NetworkService {
  final IPermissionRepository _permissionRepository;

  const NetworkService(this._permissionRepository);

  Future<bool> openSettings() {
    return _permissionRepository.openSettings();
  }
}
