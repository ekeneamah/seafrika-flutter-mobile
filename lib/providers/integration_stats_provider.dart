import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';

class IntegrationStats {
  final List<Integration> integrations;
  final int totalIntegrations;
  final Map<String, int> platformCounts;

  const IntegrationStats({
    required this.integrations,
    required this.totalIntegrations,
    required this.platformCounts,
  });
}

final integrationStatsProvider = FutureProvider<IntegrationStats>((ref) async {
  final integrationService = ref.watch(integrationServiceProvider);

  if (integrationService == null) {
    return const IntegrationStats(
      integrations: [],
      totalIntegrations: 0,
      platformCounts: {},
    );
  }

  try {
    final integrations = await integrationService.fetchIntegrations();

    // Count integrations by platform
    final platformCounts = <String, int>{};
    for (final integration in integrations) {
      platformCounts[integration.platformName] =
          (platformCounts[integration.platformName] ?? 0) + 1;
    }

    return IntegrationStats(
      integrations: integrations,
      totalIntegrations: integrations.length,
      platformCounts: platformCounts,
    );
  } catch (e) {
    throw Exception('Failed to load integrations: $e');
  }
});
