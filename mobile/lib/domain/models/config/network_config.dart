import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:immich_mobile/utils/option.dart';

part 'network_config.freezed.dart';

@Freezed(copyWith: false)
abstract class NetworkConfig with _$NetworkConfig {
  const NetworkConfig._();

  const factory NetworkConfig({
    @Default('local') String endpointMode,
    String? localEndpoint,
    @Default([]) List<String> externalEndpointList,
    @Default({}) Map<String, String> customHeaders,
  }) = _NetworkConfig;

  // We patch `localEndpoint`, which prevents us from using Freezed `copyWith`
  NetworkConfig copyWith({
    String? endpointMode,
    Option<String>? localEndpoint,
    List<String>? externalEndpointList,
    Map<String, String>? customHeaders,
  }) => NetworkConfig(
    endpointMode: endpointMode ?? this.endpointMode,
    localEndpoint: localEndpoint.patch(this.localEndpoint),
    externalEndpointList: externalEndpointList ?? this.externalEndpointList,
    customHeaders: customHeaders ?? this.customHeaders,
  );
}
