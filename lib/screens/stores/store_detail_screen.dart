import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/services/inventory_service.dart';
import 'package:vendor_app/models/inventory.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/store_inventory_service.dart';
import '../../providers/vendor_id_provider.dart';
import '../../models/store_inventory.dart';

class StoreDetailScreen extends StatelessWidget {
  final Store store;
  const StoreDetailScreen({Key? key, required this.store}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((store.coverImageUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(store.coverImageUrl ?? '',
                  height: 160, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (store.imageUrl ?? '').isNotEmpty
                    ? Image.network(store.imageUrl ?? '', width: 64, height: 64)
                    : Container(
                        width: 64,
                        height: 64,
                        color: AppTheme.secondary.withOpacity(0.1)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(store.name ?? '',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(store.description ?? '',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(store.address ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(store.phone ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(store.email ?? ''),
          ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Top Products',
            onViewMore: () {
              Navigator.pushNamed(context, '/store-products',
                  arguments: {'storeId': store.id});
            },
          ),
          _TopProductsSection(storeId: store.id),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Store Inventory',
            onViewMore: () {
              Navigator.pushNamed(context, '/store-inventory',
                  arguments: {'storeId': store.id});
            },
          ),
          StoreInventoryList(storeId: store.id),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewMore;
  const _SectionHeader(
      {required this.title, required this.onViewMore, Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: onViewMore,
          child: const Text('View More'),
        ),
      ],
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  final String storeId;
  const _TopProductsSection({required this.storeId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<ProductService>().fetchProducts(),
      builder: (context, snapshot) {
        final products = context
            .read<ProductService>()
            .products
            .where((p) => p.vendorId == storeId)
            .take(20)
            .toList();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (products.isEmpty) {
          return const Text('No products found for this store.');
        }
        return Column(
          children: products
              .map((product) => ListTile(
                    leading: product.images.isNotEmpty
                        ? Image.network(product.images[0],
                            width: 40, height: 40, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(product.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('NGN ${product.price.toStringAsFixed(2)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, '/products/detail',
                          arguments: {'productId': product.id});
                    },
                  ))
              .toList(),
        );
      },
    );
  }
}

class StoreInventoryList extends ConsumerWidget {
  final String storeId;

  const StoreInventoryList({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorId = ref.watch(vendorIdProvider);

    return ref
        .watch(storeInventoryStreamProvider(
            (vendorId: vendorId, storeId: storeId)))
        .when(
          data: (inventory) {
            if (inventory.isEmpty) {
              return const Text('No inventory items found for this store.');
            }

            return Column(
              children: inventory
                  .map((item) => ListTile(
                        leading: const Icon(Icons.inventory_2),
                        title: Text(item.productName),
                        subtitle: Text('Quantity: ${item.quantity}'),
                        trailing:
                            Text('NGN ${item.unitPrice.toStringAsFixed(2)}'),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error: $error'),
        );
  }
}
