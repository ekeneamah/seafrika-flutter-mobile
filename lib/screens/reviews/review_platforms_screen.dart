import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/review.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/review_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart' as loading;

class ReviewPlatformsScreen extends StatefulWidget {
  const ReviewPlatformsScreen({super.key});

  @override
  State<ReviewPlatformsScreen> createState() => _ReviewPlatformsScreenState();
}

class _ReviewPlatformsScreenState extends State<ReviewPlatformsScreen> {
  bool _isLoading = true;
  String? _error;
  List<ReviewPlatform> _platforms = [];

  @override
  void initState() {
    super.initState();
    _loadPlatforms();
  }

  Future<void> _loadPlatforms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reviewService = context.read<ReviewService>();
      final platforms = await reviewService.fetchPlatforms();
      setState(() {
        _platforms = platforms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load review platforms';
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectPlatform(ReviewPlatform platform) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Platform'),
        content: Text('Are you sure you want to disconnect ${platform.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final reviewService = context.read<ReviewService>();
        await reviewService.disconnectPlatform(platform.id);
        await _loadPlatforms();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to disconnect platform')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Platforms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlatforms,
          ),
        ],
      ),
      body: _isLoading
          ? const loading.LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadPlatforms,
                )
              : _platforms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star_border,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Review Platforms',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Connect your review platforms to start managing reviews',
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              NavigationService.navigateToAddPlatform();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Platform'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _platforms.length,
                      itemBuilder: (context, index) {
                        final platform = _platforms[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              IconData(
                                int.parse(platform.icon),
                                fontFamily: 'MaterialIcons',
                              ),
                              size: 32,
                            ),
                            title: Text(platform.name),
                            subtitle: Text(
                              'Connected on ${platform.connectedAt.toString().split('.')[0]}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _disconnectPlatform(platform),
                            ),
                            onTap: () {
                              NavigationService.navigateToPlatformSettings(
                                platform.id,
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NavigationService.navigateToAddPlatform();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
