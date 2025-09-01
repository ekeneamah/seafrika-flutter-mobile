import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../providers/service_providers.dart';
import '../../providers/business_context_provider.dart';
import 'direct_store_add_dialog.dart';

/// Media action menu for direct sell and direct store add functionality
class MediaActionMenu extends ConsumerWidget {
  final AssetEntity media;
  final List<StoreInfo> availableStores;

  const MediaActionMenu({
    Key? key,
    required this.media,
    required this.availableStores,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Text(
                'Media Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Direct Sell Options
          Text(
            'Direct Sell',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sell this item immediately and create an order',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Store options for selling
          ...availableStores.map((store) => _buildActionTile(
                context: context,
                icon: Icons.point_of_sale,
                title: 'Sell via ${store.name}',
                subtitle: 'Quick sell through this store',
                color: Colors.green,
                onTap: () => _quickSellViaStore(context, ref, store),
              )),

          const SizedBox(height: 16),

          // Add to Store Options
          Text(
            'Add to Store Inventory',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add this item to store inventory for future sales',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Store options for adding to inventory
          ...availableStores.map((store) => _buildActionTile(
                context: context,
                icon: Icons.add_business,
                title: 'Add to ${store.name}',
                subtitle: 'Add to store inventory',
                color: Colors.blue,
                onTap: () => _addToStore(context, store),
              )),

          const SizedBox(height: 16),

          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: availableStores.isEmpty 
                      ? null 
                      : () => _quickSellAnyStore(context, ref),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Quick Sell'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: availableStores.isEmpty 
                      ? null 
                      : () => _quickAddAnyStore(context, ref),
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Quick Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      dense: true,
    );
  }

  Future<void> _quickSellViaStore(
    BuildContext context, 
    WidgetRef ref, 
    StoreInfo store
  ) async {
    try {
      final directSellService = ref.read(directSellServiceProvider);
      final businessId = ref.read(selectedBusinessIdProvider);
      final businessName = ref.read(selectedBusinessNameProvider);
      final vendorId = ref.read(vendorIdSyncProvider);

      if (businessId == null || businessName == null || vendorId.isEmpty) {
        throw Exception('Business context not properly initialized');
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing quick sell...'),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await directSellService.quickSellFromMedia(
        media: media,
        businessId: businessId,
        businessName: businessName,
        vendorId: vendorId,
        storeId: store.id,
        storeName: store.name,
        price: 15.0, // Default quick sell price
        customerName: 'Walk-in Customer',
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Close action menu
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully sold via ${store.name} for \$${result.totalAmount}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to process sale'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToStore(BuildContext context, StoreInfo store) async {
    Navigator.of(context).pop(); // Close action menu
    
    await showDirectStoreAddDialog(
      context,
      media: media,
    );
    
    // Result handling is done in the dialog
  }

  Future<void> _quickSellAnyStore(BuildContext context, WidgetRef ref) async {
    if (availableStores.isEmpty) return;
    
    // Use first available store for quick sell
    await _quickSellViaStore(context, ref, availableStores.first);
  }

  Future<void> _quickAddAnyStore(BuildContext context, WidgetRef ref) async {
    if (availableStores.isEmpty) return;

    try {
      final directSellService = ref.read(directSellServiceProvider);
      final businessId = ref.read(selectedBusinessIdProvider);
      final businessName = ref.read(selectedBusinessNameProvider);
      final vendorId = ref.read(vendorIdSyncProvider);
      final store = availableStores.first;

      if (businessId == null || businessName == null || vendorId.isEmpty) {
        throw Exception('Business context not properly initialized');
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Adding to store inventory...'),
                ],
              ),
            ),
          ),
        ),
      );

      final result = await directSellService.quickAddMediaToStore(
        media: media,
        businessId: businessId,
        businessName: businessName,
        vendorId: vendorId,
        storeId: store.id,
        storeName: store.name,
        price: 12.0, // Default price for quick add
        quantity: 1,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Close action menu
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quick added to ${store.name} inventory'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to add to inventory'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Helper function to show the media action menu
Future<void> showMediaActionMenu(
  BuildContext context, {
  required AssetEntity media,
  required List<StoreInfo> availableStores,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: MediaActionMenu(
          media: media,
          availableStores: availableStores,
        ),
      ),
    ),
  );
}

/// Store information class
class StoreInfo {
  final String id;
  final String name;

  StoreInfo({
    required this.id,
    required this.name,
  });
}
