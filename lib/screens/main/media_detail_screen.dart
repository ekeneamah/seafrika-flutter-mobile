import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart'
    show VideoPlayerController, VideoPlayer;
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/widgets/loading_view.dart';

class MediaDetailScreen extends StatefulWidget {
  final AssetEntity media;

  const MediaDetailScreen({
    super.key,
    required this.media,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _imageData;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    try {
      final bytes = await widget.media.originBytes;
      if (bytes != null) {
        setState(() {
          _imageData = bytes;
          _isLoading = false;
        });
        if (widget.media.type == AssetType.video) {
          final file = await widget.media.file;
          if (file != null) {
            _videoController = VideoPlayerController.file(file);
            await _videoController!.initialize();
          }
        }
      } else {
        setState(() {
          _error = 'Failed to load media';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load media';
        _isLoading = false;
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  void _onSellPressed() {
    Navigator.pushNamed(
      context,
      AppRoutes.createProduct,
      arguments: {'media': widget.media},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              if (_imageData != null) {
                await Share.shareXFiles(
                  [XFile.fromData(_imageData!, name: 'media.jpg')],
                  text: 'Check out this media!',
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMedia,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        child: Center(
                          child: widget.media.type == AssetType.video
                              ? (_videoController != null &&
                                      _videoController!.value.isInitialized
                                  ? AspectRatio(
                                      aspectRatio:
                                          _videoController!.value.aspectRatio,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          VideoPlayer(_videoController!),
                                          if (!_isPlaying)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.play_circle_filled,
                                                  size: 64,
                                                  color: Colors.white),
                                              onPressed: _togglePlayPause,
                                            ),
                                        ],
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator()))
                              : (_imageData != null
                                  ? Image.memory(_imageData!,
                                      fit: BoxFit.contain)
                                  : const Center(
                                      child: CircularProgressIndicator())),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Create a product listing with this media',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _onSellPressed,
                                icon: const Icon(Icons.sell),
                                label: const Text('Sell This Item'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
