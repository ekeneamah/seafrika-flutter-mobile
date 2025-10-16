import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Optimized image widget with smart caching and lazy loading
class OptimizedMessageImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool enableLazyLoad;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedMessageImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.enableLazyLoad = true,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  State<OptimizedMessageImage> createState() => _OptimizedMessageImageState();
}

class _OptimizedMessageImageState extends State<OptimizedMessageImage>
    with AutomaticKeepAliveClientMixin {
  bool _isInView = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!widget.enableLazyLoad) {
      _isInView = true;
    } else {
      // Delay loading slightly to check if in viewport
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _isInView = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isInView) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: widget.placeholder ??
            const Center(child: CircularProgressIndicator()),
      );
    }

    return RepaintBoundary(
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: widget.width?.toInt(),
        memCacheHeight: widget.height?.toInt(),
        maxWidthDiskCache: 1000,
        maxHeightDiskCache: 1000,
        placeholder: (context, url) =>
            widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[300],
              child: const Icon(Icons.error_outline, color: Colors.red),
            ),
      ),
    );
  }
}

/// Optimized avatar widget with caching
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;

  const OptimizedAvatar({
    Key? key,
    this.imageUrl,
    required this.fallbackText,
    this.radius = 16,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
        backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImageProvider(
                imageUrl!,
                maxWidth: (radius * 2).toInt(),
                maxHeight: (radius * 2).toInt(),
              )
            : null,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Text(
                fallbackText.isNotEmpty
                    ? fallbackText[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.75,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

/// Lazy loading controller for viewport-based rendering
class LazyLoadController {
  final ScrollController scrollController;
  final double preloadOffset;

  LazyLoadController({
    required this.scrollController,
    this.preloadOffset = 200.0,
  });

  /// Check if an item at given index should be loaded
  bool shouldLoad(int index, int totalItems, double itemHeight) {
    if (!scrollController.hasClients) return false;

    final scrollOffset = scrollController.offset;
    final viewportHeight = scrollController.position.viewportDimension;
    final itemPosition = index * itemHeight;

    // Load if within viewport + preload offset
    return itemPosition >= scrollOffset - preloadOffset &&
        itemPosition <= scrollOffset + viewportHeight + preloadOffset;
  }

  /// Get range of items that should be loaded
  Map<String, int> getLoadRange(int totalItems, double itemHeight) {
    if (!scrollController.hasClients) {
      return {'start': 0, 'end': 0};
    }

    final scrollOffset = scrollController.offset;
    final viewportHeight = scrollController.position.viewportDimension;

    final startIndex = ((scrollOffset - preloadOffset) / itemHeight)
        .floor()
        .clamp(0, totalItems - 1);
    final endIndex =
        ((scrollOffset + viewportHeight + preloadOffset) / itemHeight)
            .ceil()
            .clamp(0, totalItems - 1);

    return {
      'start': startIndex,
      'end': endIndex,
    };
  }
}

/// Widget that only renders when in viewport
class ViewportAware extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;
  final double preloadOffset;
  final Widget? placeholder;

  const ViewportAware({
    Key? key,
    required this.child,
    this.scrollController,
    this.preloadOffset = 200.0,
    this.placeholder,
  }) : super(key: key);

  @override
  State<ViewportAware> createState() => _ViewportAwareState();
}

class _ViewportAwareState extends State<ViewportAware> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
    widget.scrollController?.addListener(_checkVisibility);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_checkVisibility);
    super.dispose();
  }

  void _checkVisibility() {
    if (!mounted) return;

    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) {
      return;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    if (viewport == null) {
      setState(() => _isVisible = true);
      return;
    }

    final offsetToReveal = viewport.getOffsetToReveal(renderObject, 0.0);
    final isVisible = offsetToReveal.offset.abs() < widget.preloadOffset;

    if (_isVisible != isVisible) {
      setState(() => _isVisible = isVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return widget.child;
  }
}

/// Batch image preloader for smooth scrolling
class ImagePreloader {
  static final Set<String> _preloadedUrls = {};
  static final Map<String, Future<void>> _preloadingFutures = {};

  /// Preload an image
  static Future<void> preload(BuildContext context, String imageUrl) async {
    if (_preloadedUrls.contains(imageUrl)) return;
    if (_preloadingFutures.containsKey(imageUrl)) {
      return _preloadingFutures[imageUrl];
    }

    final future = precacheImage(
      CachedNetworkImageProvider(imageUrl),
      context,
    ).then((_) {
      _preloadedUrls.add(imageUrl);
      _preloadingFutures.remove(imageUrl);
    }).catchError((error) {
      _preloadingFutures.remove(imageUrl);
      debugPrint('Failed to preload image: $imageUrl - $error');
    });

    _preloadingFutures[imageUrl] = future;
    return future;
  }

  /// Preload multiple images
  static Future<void> preloadBatch(
    BuildContext context,
    List<String> imageUrls, {
    int batchSize = 5,
  }) async {
    for (var i = 0; i < imageUrls.length; i += batchSize) {
      final batch = imageUrls.skip(i).take(batchSize);
      await Future.wait(
        batch.map((url) => preload(context, url)),
      );
    }
  }

  /// Clear preload cache
  static void clearCache() {
    _preloadedUrls.clear();
    _preloadingFutures.clear();
  }

  /// Check if image is preloaded
  static bool isPreloaded(String imageUrl) {
    return _preloadedUrls.contains(imageUrl);
  }

  /// Get cache stats
  static Map<String, int> getStats() {
    return {
      'preloaded': _preloadedUrls.length,
      'preloading': _preloadingFutures.length,
    };
  }
}

/// Text caching for expensive text rendering
class TextCache {
  static final Map<String, TextPainter> _cache = {};
  static const int maxCacheSize = 100;

  /// Get or create a cached TextPainter
  static TextPainter getPainter(
    String text,
    TextStyle style, {
    TextAlign textAlign = TextAlign.left,
    TextDirection textDirection = TextDirection.ltr,
    int? maxLines,
  }) {
    final key = '$text|${style.hashCode}|$textAlign|$maxLines';

    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
    );

    painter.layout();

    // Evict oldest if cache is full
    if (_cache.length >= maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = painter;
    return painter;
  }

  /// Clear the cache
  static void clear() {
    _cache.clear();
  }

  /// Get cache size
  static int get size => _cache.length;
}
