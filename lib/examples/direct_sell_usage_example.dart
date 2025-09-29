import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../widgets/media/media_action_menu.dart';

/// Example usage of the direct sell and direct store add functionality
/// This shows how to integrate the media action menu into an existing media gallery
class MediaGalleryExample extends ConsumerStatefulWidget {
  const MediaGalleryExample({Key? key}) : super(key: key);

  @override
  ConsumerState<MediaGalleryExample> createState() =>
      _MediaGalleryExampleState();
}

class _MediaGalleryExampleState extends ConsumerState<MediaGalleryExample> {
  List<AssetEntity> _mediaAssets = [];
  bool _isLoading = true;

  // Example store data - in real app, this would come from your store provider
  final List<StoreInfo> _availableStores = [
    StoreInfo(id: 'store_1', name: 'Main Store'),
    StoreInfo(id: 'store_2', name: 'Online Store'),
    StoreInfo(id: 'store_3', name: 'Retail Outlet'),
  ];

  @override
  void initState() {
    super.initState();
    _loadMediaAssets();
  }

  Future<void> _loadMediaAssets() async {
    // Request permission to access photos
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() => _isLoading = false);
      return;
    }

    // Get photo albums
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isNotEmpty) {
      // Get assets from the first album (usually "All Photos")
      final assets = await albums.first.getAssetListRange(
        start: 0,
        end: 20, // Load first 20 photos
      );

      setState(() {
        _mediaAssets = assets;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<Widget> _buildAssetThumbnail(AssetEntity asset) async {
    final bytes =
        await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Container(
      color: Colors.grey[300],
      child: Icon(
        asset.type == AssetType.video ? Icons.videocam : Icons.photo,
        size: 50,
        color: Colors.grey[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Gallery with Direct Actions'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaAssets.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No media found'),
                      SizedBox(height: 8),
                      Text(
                        'Make sure you have granted photo access permission',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _mediaAssets.length,
                  itemBuilder: (context, index) {
                    return _buildMediaItem(_mediaAssets[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMediaAssets,
        tooltip: 'Refresh Media',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildMediaItem(AssetEntity asset) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _showMediaActions(asset),
        child: Stack(
          children: [
            // Media thumbnail
            Positioned.fill(
              child: FutureBuilder<Widget>(
                future: _buildAssetThumbnail(asset),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: snapshot.data!,
                    );
                  }
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),

            // Overlay with action buttons
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _quickSellMedia(asset),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('Sell',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _quickAddMedia(asset),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: const Size(0, 32),
                          ),
                          child:
                              const Text('Add', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showMediaActions(asset),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('More Options',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),

            // Media type indicator
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      asset.type == AssetType.video
                          ? Icons.videocam
                          : Icons.photo,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      asset.type == AssetType.video ? 'VIDEO' : 'PHOTO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaActions(AssetEntity asset) {
    showMediaActionMenu(
      context,
      media: asset,
      availableStores: _availableStores,
    );
  }

  void _quickSellMedia(AssetEntity asset) {
    // Quick sell using first available store
    if (_availableStores.isNotEmpty) {
      // This would trigger the quick sell functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quick selling via ${_availableStores.first.name}...'),
          backgroundColor: Colors.green,
        ),
      );
      _showMediaActions(asset); // Open full menu for demo
    }
  }

  void _quickAddMedia(AssetEntity asset) {
    // Quick add to first available store
    if (_availableStores.isNotEmpty) {
      // This would trigger the quick add functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Quick adding to ${_availableStores.first.name} inventory...'),
          backgroundColor: Colors.blue,
        ),
      );
      _showMediaActions(asset); // Open full menu for demo
    }
  }
}

/// Usage instructions widget
class DirectSellUsageInstructions extends StatelessWidget {
  const DirectSellUsageInstructions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Sell & Store Add Features'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.point_of_sale, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Direct Sell from Media',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This feature allows users to sell products directly from their media gallery without manually creating products or managing inventory. The system automatically:',
                    ),
                    const SizedBox(height: 8),
                    const Text('• Creates a product from the selected media'),
                    const Text('• Adds it to business inventory'),
                    const Text('• Allocates stock to the chosen store'),
                    const Text('• Creates a completed sale order'),
                    const Text('• Handles all background processing'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_business, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Direct Add to Store Inventory',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This feature allows users to add media items directly to store inventory for future sales. The system automatically:',
                    ),
                    const SizedBox(height: 8),
                    const Text('• Creates a product from the selected media'),
                    const Text('• Adds it to business inventory'),
                    const Text('• Allocates stock to the chosen store'),
                    const Text('• Makes it available for future sales'),
                    const Text('• Maintains three-tier inventory consistency'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.integration_instructions,
                            color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Integration Examples',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Usage patterns:'),
                    const SizedBox(height: 8),
                    const Text('• Media gallery with context menu'),
                    const Text('• Quick action buttons on media items'),
                    const Text('• Bulk operations on multiple items'),
                    const Text('• Integration with existing workflows'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MediaGalleryExample(),
                  ),
                ),
                icon: const Icon(Icons.launch),
                label: const Text('Try Live Example'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
