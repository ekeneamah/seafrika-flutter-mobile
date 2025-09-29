import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/widgets/empty_view.dart';
import 'dart:typed_data';

class MediaTab extends StatefulWidget {
  const MediaTab({super.key});

  @override
  State<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<MediaTab> {
  List<AssetEntity> _media = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  bool _hasMoreToLoad = true;
  final int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final permitted = await PhotoManager.requestPermissionExtend();
    if (permitted.isAuth) {
      _loadMedia();
    } else {
      // Show dialog to open app settings
      await PhotoManager.openSetting();
      setState(() {
        _error =
            'Permission to access media was denied. Please enable it in settings.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMedia() async {
    if (!_hasMoreToLoad) return;

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
      );

      if (albums.isEmpty) {
        setState(() {
          _error = 'No media found';
          _isLoading = false;
        });
        return;
      }

      final List<AssetEntity> media = await albums.first.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      setState(() {
        _media.addAll(media);
        _currentPage++;
        _hasMoreToLoad = media.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load media';
        _isLoading = false;
      });
    }
  }

  void _onMediaTap(AssetEntity media) {
    Navigator.pushNamed(
      context,
      AppRoutes.mediaDetail,
      arguments: {'media': media},
    );
  }

  /// Build individual media item with proper aspect ratio and styling
  Widget _buildMediaItem(AssetEntity media, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Main image/video thumbnail with proper aspect ratio
            AspectRatio(
              aspectRatio: 1.0, // Square aspect ratio for grid consistency
              child: FutureBuilder<Uint8List?>(
                future: media.thumbnailDataWithSize(
                  const ThumbnailSize(200, 200), // High quality thumbnail
                  quality: 85,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: AppTheme.earthLight.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data == null) {
                    return Container(
                      color: AppTheme.earthLight.withOpacity(0.3),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.earth,
                          size: 32,
                        ),
                      ),
                    );
                  }

                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit
                        .cover, // Ensures proper scaling without distortion
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.earthLight.withOpacity(0.3),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppTheme.earth,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Video indicator overlay
            if (media.type == AssetType.video)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatDuration(media.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Selection overlay for tap feedback
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _onMediaTap(media),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Date/time info at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  _formatTime(media.createDateTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Loading indicator for pagination
            if (_hasMoreToLoad && index == _media.length - 10)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Format video duration in MM:SS format
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Format time in 12-hour format
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Build header with media count and stats
  Widget _buildMediaHeader() {
    final imageCount = _media.where((m) => m.type == AssetType.image).length;
    final videoCount = _media.where((m) => m.type == AssetType.video).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Media Gallery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${_media.length} items total',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.earth,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasMoreToLoad)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Loading...',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.photo_outlined,
                          color: AppTheme.accent,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$imageCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Photos',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: AppTheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$videoCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Videos',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.earth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Media',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: () {
              setState(() {
                _currentPage = 0;
                _hasMoreToLoad = true;
                _media.clear();
                _isLoading = true;
                _error = null;
              });
              _loadMedia();
            },
            tooltip: 'Refresh Media',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _requestPermission,
                )
              : _media.isEmpty
                  ? const EmptyView(
                      icon: Icons.photo_library_outlined,
                      title: 'No Media Found',
                      message: 'Your device has no photos or videos',
                    )
                  : CustomScrollView(
                      slivers: [
                        // Header with stats
                        SliverToBoxAdapter(
                          child: _buildMediaHeader(),
                        ),

                        // Media grid with infinite scroll
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio:
                                  1.0, // Perfect squares prevent skewing
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final media = _media[index];

                                // Trigger loading more items when near the end
                                if (_hasMoreToLoad &&
                                    index == _media.length - 10) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _loadMedia();
                                  });
                                }

                                return _buildMediaItem(media, index);
                              },
                              childCount: _media.length,
                              addAutomaticKeepAlives: false, // Optimize memory
                            ),
                          ),
                        ),

                        // Loading indicator at bottom
                        if (_hasMoreToLoad)
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppTheme.primary,
                                      strokeWidth: 2,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Loading more media...',
                                      style: TextStyle(
                                        color: AppTheme.earth,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Bottom padding
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 32),
                        ),
                      ],
                    ),
    );
  }
}
