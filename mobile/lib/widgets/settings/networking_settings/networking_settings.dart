import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/models/auth/auxilary_endpoint.model.dart';
import 'package:immich_mobile/providers/auth.provider.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:immich_mobile/widgets/settings/networking_settings/external_network_preference.dart';
import 'package:immich_mobile/widgets/settings/networking_settings/local_network_preference.dart';
import 'package:immich_mobile/widgets/settings/setting_group_title.dart';

class NetworkingSettings extends HookConsumerWidget {
  const NetworkingSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEndpoint = getServerUrl();
    final endpointMode = useState(Store.tryGet(StoreKey.endpointMode) ?? 'local');

    Future<void> switchEndpoint(String mode) async {
      endpointMode.value = mode;
      await ref.read(authProvider.notifier).saveEndpointMode(mode);
      await ref.read(authProvider.notifier).setOpenApiServiceEndpoint();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: <Widget>[
        const SizedBox(height: 8),
        SettingGroupTitle(
          title: "current_server_address".t(context: context),
          icon: (currentEndpoint?.startsWith('https') ?? false) ? Icons.https_outlined : Icons.http_outlined,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              side: BorderSide(color: context.colorScheme.surfaceContainerHighest, width: 1),
            ),
            child: ListTile(
              leading: currentEndpoint != null
                  ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                  : const Icon(Icons.circle_outlined),
              title: Text(
                currentEndpoint ?? "--",
                style: TextStyle(fontSize: 14, fontFamily: 'GoogleSansCode', color: context.primaryColor),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Divider(color: context.colorScheme.surfaceContainerHighest),
        ),
        ListTile(
          title: Text("endpoint_preference_title".t(context: context)),
          subtitle: Text("endpoint_preference_subtitle".t(context: context)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'local',
                label: Text("prefer_local_network".t(context: context)),
                icon: const Icon(Icons.home_outlined),
              ),
              ButtonSegment(
                value: 'external',
                label: Text("prefer_external_network".t(context: context)),
                icon: const Icon(Icons.dns_outlined),
              ),
            ],
            selected: {endpointMode.value},
            onSelectionChanged: (modes) => switchEndpoint(modes.first),
          ),
        ),
        const SizedBox(height: 8),
        SettingGroupTitle(
          title: "local_network".t(context: context),
          icon: Icons.home_outlined,
        ),
        const LocalNetworkPreference(),
        const SizedBox(height: 16),
        SettingGroupTitle(
          title: "external_network".t(context: context),
          icon: Icons.dns_outlined,
        ),
        const ExternalNetworkPreference(enabled: true),
      ],
    );
  }
}

class NetworkStatusIcon extends StatelessWidget {
  const NetworkStatusIcon({super.key, required this.status, this.enabled = true}) : super();

  final AuxCheckStatus status;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: buildIcon(context));
  }

  Widget buildIcon(BuildContext context) => switch (status) {
    AuxCheckStatus.loading => Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(color: context.primaryColor, strokeWidth: 2, key: const ValueKey('loading')),
      ),
    ),
    AuxCheckStatus.valid =>
      enabled
          ? const Icon(Icons.check_circle_rounded, color: Colors.green, key: ValueKey('success'))
          : Icon(
              Icons.check_circle_rounded,
              color: context.colorScheme.onSurface.withAlpha(100),
              key: const ValueKey('success'),
            ),
    AuxCheckStatus.error =>
      enabled
          ? const Icon(Icons.error_rounded, color: Colors.red, key: ValueKey('error'))
          : const Icon(Icons.error_rounded, color: Colors.grey, key: ValueKey('error')),
    _ => const Icon(Icons.circle_outlined, key: ValueKey('unknown')),
  };
}
