import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 3-tier attachment caching service
/// Level 1: Memory cache (Map) - fastest
/// Level 2: Disk cache (File system) - persistent
/// Level 3: Network download - slowest
class AttachmentCacheService {
  static final AttachmentCacheService _instance =
      AttachmentCacheService._internal();
  factory AttachmentCacheService() => _instance;
  AttachmentCacheService._internal();

  // Memory cache (Level 1)
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _accessTimes = {};

  // Cache configuration
  static const int maxMemoryCacheSize = 50 * 1024 * 1024; // 50MB in memory
  static const int maxDiskCacheSize = 100 * 1024 * 1024; // 100MB on disk
  static const int maxMemoryCacheItems = 50; // Max items in memory

  int _currentMemorySize = 0;

  /// Get attachment from cache or download
  /// Returns file path to the cached attachment
  Future<String?> getAttachment(String url, {bool preload = false}) async {
    try {
      final cacheKey = _generateCacheKey(url);

      // Level 1: Check memory cache
      if (_memoryCache.containsKey(cacheKey)) {
        debugPrint('📦 Cache HIT (Memory): $url');
        _accessTimes[cacheKey] = DateTime.now();

        // Save to disk if not already there
        final diskPath = await _getDiskCachePath(cacheKey);
        if (!await File(diskPath).exists()) {
          await _saveToDisk(cacheKey, _memoryCache[cacheKey]!);
        }

        return diskPath;
      }

      // Level 2: Check disk cache
      final diskPath = await _getDiskCachePath(cacheKey);
      if (await File(diskPath).exists()) {
        debugPrint('📦 Cache HIT (Disk): $url');
        _accessTimes[cacheKey] = DateTime.now();

        // Load into memory cache
        final bytes = await File(diskPath).readAsBytes();
        await _addToMemoryCache(cacheKey, bytes);

        return diskPath;
      }

      // Level 3: Download from network
      debugPrint('🌐 Cache MISS - Downloading: $url');
      final bytes = await _downloadAttachment(url);

      if (bytes != null) {
        // Save to both memory and disk
        await _addToMemoryCache(cacheKey, bytes);
        await _saveToDisk(cacheKey, bytes);

        debugPrint('✅ Downloaded and cached: $url (${bytes.length} bytes)');
        return diskPath;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Cache error for $url: $e');
      return null;
    }
  }

  /// Download attachment from network
  Future<Uint8List?> _downloadAttachment(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      return null;
    }
  }

  /// Add data to memory cache with size management
  Future<void> _addToMemoryCache(String cacheKey, Uint8List bytes) async {
    final size = bytes.length;

    // Check if we need to evict items
    while (_currentMemorySize + size > maxMemoryCacheSize ||
        _memoryCache.length >= maxMemoryCacheItems) {
      await _evictLeastRecentlyUsed();
    }

    _memoryCache[cacheKey] = bytes;
    _accessTimes[cacheKey] = DateTime.now();
    _currentMemorySize += size;
  }

  /// Evict least recently used item from memory cache
  Future<void> _evictLeastRecentlyUsed() async {
    if (_memoryCache.isEmpty) return;

    // Find least recently used item
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _accessTimes.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      final size = _memoryCache[oldestKey]?.length ?? 0;
      _memoryCache.remove(oldestKey);
      _accessTimes.remove(oldestKey);
      _currentMemorySize -= size;
      debugPrint('🗑️ Evicted from memory cache: $oldestKey');
    }
  }

  /// Save data to disk cache
  Future<void> _saveToDisk(String cacheKey, Uint8List bytes) async {
    try {
      final path = await _getDiskCachePath(cacheKey);
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      // Check disk cache size and evict if needed
      await _evictDiskCacheIfNeeded();
    } catch (e) {
      debugPrint('❌ Failed to save to disk: $e');
    }
  }

  /// Get disk cache file path
  Future<String> _getDiskCachePath(String cacheKey) async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/attachment_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return '${cacheDir.path}/$cacheKey';
  }

  /// Evict disk cache items if over size limit (LRU policy)
  Future<void> _evictDiskCacheIfNeeded() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/attachment_cache');

      if (!await cacheDir.exists()) return;

      // Get all cache files with their stats
      final files = <File, FileStat>{};
      int totalSize = 0;

      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files[entity] = stat;
          totalSize += stat.size;
        }
      }

      // If over limit, delete oldest files first
      if (totalSize > maxDiskCacheSize) {
        // Sort by access time (oldest first)
        final sortedFiles = files.entries.toList()
          ..sort((a, b) => a.value.accessed.compareTo(b.value.accessed));

        for (final entry in sortedFiles) {
          if (totalSize <= maxDiskCacheSize * 0.8) break; // Leave 20% buffer

          try {
            final size = entry.value.size;
            await entry.key.delete();
            totalSize -= size;
            debugPrint('🗑️ Evicted from disk cache: ${entry.key.path}');
          } catch (e) {
            debugPrint('❌ Failed to delete cache file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Disk cache eviction error: $e');
    }
  }

  /// Generate cache key from URL
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  /// Clear all cache (memory and disk)
  Future<void> clearCache() async {
    try {
      // Clear memory cache
      _memoryCache.clear();
      _accessTimes.clear();
      _currentMemorySize = 0;

      // Clear disk cache
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/attachment_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      debugPrint('✅ All cache cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
    }
  }

  /// Get current cache size (memory + disk)
  Future<Map<String, int>> getCacheSize() async {
    int memorySize = _currentMemorySize;
    int diskSize = 0;

    try {
      final dir = await getTemporaryDirectory();
      final cacheDir = Directory('${dir.path}/attachment_cache');

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            diskSize += stat.size;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to calculate disk cache size: $e');
    }

    return {
      'memory': memorySize,
      'disk': diskSize,
      'total': memorySize + diskSize,
    };
  }

  /// Preload attachment into cache (for proactive caching)
  Future<void> preloadAttachment(String url) async {
    await getAttachment(url, preload: true);
  }

  /// Preload multiple attachments
  Future<void> preloadAttachments(List<String> urls) async {
    await Future.wait(
      urls.map((url) => preloadAttachment(url)),
    );
  }

  /// Check if attachment is cached
  Future<bool> isCached(String url) async {
    final cacheKey = _generateCacheKey(url);

    // Check memory
    if (_memoryCache.containsKey(cacheKey)) {
      return true;
    }

    // Check disk
    final diskPath = await _getDiskCachePath(cacheKey);
    return await File(diskPath).exists();
  }

  /// Remove specific attachment from cache
  Future<void> removeFromCache(String url) async {
    try {
      final cacheKey = _generateCacheKey(url);

      // Remove from memory
      final size = _memoryCache[cacheKey]?.length ?? 0;
      _memoryCache.remove(cacheKey);
      _accessTimes.remove(cacheKey);
      _currentMemorySize -= size;

      // Remove from disk
      final diskPath = await _getDiskCachePath(cacheKey);
      final file = File(diskPath);
      if (await file.exists()) {
        await file.delete();
      }

      debugPrint('✅ Removed from cache: $url');
    } catch (e) {
      debugPrint('❌ Failed to remove from cache: $e');
    }
  }
}
