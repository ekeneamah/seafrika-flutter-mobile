import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/message_provider.dart';

/// Widget that displays cached attachment images
/// Uses AttachmentCacheService for 3-tier caching
class CachedAttachmentImage extends ConsumerStatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedAttachmentImage({
    Key? key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  ConsumerState<CachedAttachmentImage> createState() =>
      _CachedAttachmentImageState();
}

class _CachedAttachmentImageState extends ConsumerState<CachedAttachmentImage> {
  String? _cachedPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final cacheService = ref.read(attachmentCacheServiceProvider);
      final path = await cacheService.getAttachment(widget.url);

      if (mounted) {
        setState(() {
          _cachedPath = path;
          _isLoading = false;
          _hasError = path == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
    }

    if (_hasError || _cachedPath == null) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Icon(
              Icons.broken_image,
              size: 48,
              color: Colors.grey,
            ),
          );
    }

    return Image.file(
      File(_cachedPath!),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[200],
              child: const Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.grey,
              ),
            );
      },
    );
  }
}
